import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:knotes/core/database/database_backup.dart';
import 'package:knotes/core/database/database_service.dart';
import 'package:knotes/core/services/credential_store.dart';
import 'package:knotes/core/services/device_files.dart';
import 'package:knotes/features/welcome/view_models/launch_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

String backup({Map<String, Object?> data = const {}, int version = 3}) =>
    jsonEncode({
      'app': 'knotes',
      'version': version,
      'data': {
        'accounts': [],
        'categories': [],
        'transactions': [],
        'app_settings': [
          {'key': 'restored', 'value': 'yes'},
        ],
        ...data,
      },
    });

class BackupFiles implements DeviceFiles {
  BackupFiles(this.content);
  final String content;
  @override
  Future<String?> pickBackup() async => content;
  @override
  Future<String?> pickPetImage() async => null;
  @override
  Future<bool> saveBackup(String content, String name) async => false;
}

class FailingReopenService extends DatabaseService {
  FailingReopenService(super.path)
    : super.atPath(
        factory: databaseFactoryFfi,
        credentials: MemoryCredentialStore(),
      );

  bool failOpen = false;
  Completer<void>? recoveryStarted;
  Completer<void>? allowRecovery;
  int activeRecoveries = 0;
  int maximumRecoveries = 0;

  @override
  Future<void> runDatabaseRecovery(
    Future<void> Function(Future<void> Function()) operation,
  ) => super.runDatabaseRecovery((reopen) async {
    activeRecoveries++;
    if (activeRecoveries > maximumRecoveries) {
      maximumRecoveries = activeRecoveries;
    }
    recoveryStarted?.complete();
    recoveryStarted = null;
    try {
      await allowRecovery?.future;
      await operation(() async {
        if (failOpen) throw StateError('Injected replacement open failure');
        await reopen();
      });
    } finally {
      activeRecoveries--;
    }
  });
}

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  late FailingReopenService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'knotes_recovery_safety_',
    );
    path = '${directory.path}/vault.db';
    service = FailingReopenService(path);
  });

  tearDown(() async {
    service.failOpen = false;
    await service.closeAndReset();
    await directory.delete(recursive: true);
  });

  final invalidBackups = {
    'malformed JSON': '{not-json',
    'future version': backup(version: 99),
    'unsupported schema': backup(
      data: {
        'app_settings': [
          {'key': 'restored', 'value': 'yes', 'unknown_column': 'bad'},
        ],
      },
    ),
    'invalid references': backup(
      data: {
        'transactions': [
          {
            'id': 'orphan',
            'account_id': 'missing',
            'amount': 1,
            'type': 'expense',
          },
        ],
      },
    ),
    'SQL constraint failure': backup(
      data: {
        'accounts': [
          {
            'id': 'account',
            'name': 'Account',
            'type': 'cash',
            'balance': 0,
            'currency': 'USD',
            'icon_key': 'wallet',
            'color_value': 0,
            'created_at': '2026-11-09',
            'is_deleted': 2,
          },
        ],
      },
    ),
  };

  for (final entry in invalidBackups.entries) {
    for (final corrupt in [false, true]) {
      test(
        'launch rejects ${entry.key} without replacing ${corrupt ? 'corrupt' : 'healthy'} vault',
        () async {
          if (corrupt) {
            await File(path).writeAsString('unopenable original database');
            for (final suffix in ['-wal', '-shm', '-journal']) {
              await File('$path$suffix').writeAsString('original $suffix');
            }
          } else {
            await service.saveSettings({'original': 'keep'});
            await service.closeAndReset();
          }
          final original = await File(path).readAsBytes();
          final vm = LaunchViewModel(service, files: BackupFiles(entry.value));
          addTearDown(vm.dispose);

          expect(await vm.importBackup(), isFalse);
          expect(await File(path).readAsBytes(), original);
          expect(
            (await directory.list().toList()).where(
              (file) => file.path.contains('.corrupted-'),
            ),
            isEmpty,
          );
          if (corrupt) {
            for (final suffix in ['-wal', '-shm', '-journal']) {
              expect(
                await File('$path$suffix').readAsString(),
                'original $suffix',
              );
            }
          } else {
            expect((await service.getSettings())['original'], 'keep');
          }
        },
      );
    }
  }

  for (final corrupt in [false, true]) {
    test(
      'valid launch import replaces ${corrupt ? 'corrupt' : 'healthy'} vault and retains original file',
      () async {
        if (corrupt) {
          await File(path).writeAsString('unopenable original database');
        } else {
          await service.credentials.write('local-secret');
          await service.saveSettings({
            'original': 'keep',
            'github_owner': 'local-owner',
          });
          await service.closeAndReset();
        }
        final original = await File(path).readAsBytes();
        final vm = LaunchViewModel(service, files: BackupFiles(backup()));
        addTearDown(vm.dispose);

        expect(await vm.importBackup(), isTrue);
        expect((await service.getSettings())['restored'], 'yes');
        expect((await service.getSettings())['original'], isNull);
        if (!corrupt) {
          expect((await service.getSettings())['github_owner'], 'local-owner');
          expect(await service.credentials.read(), 'local-secret');
        }
        final retained = await directory
            .list(recursive: true)
            .where((file) => file is File && file.path != path)
            .cast<File>()
            .toList();
        expect(
          await Future.wait(retained.map((file) => file.readAsBytes())),
          anyElement(orderedEquals(original)),
        );
      },
    );
  }

  for (final corrupt in [false, true]) {
    test(
      'replacement reopen failure restores ${corrupt ? 'corrupt database and sidecars' : 'healthy database'}',
      () async {
        if (corrupt) {
          await File(path).writeAsString('unopenable original database');
          for (final suffix in ['-wal', '-shm', '-journal']) {
            await File('$path$suffix').writeAsString('original $suffix');
          }
        } else {
          await service.saveSettings({'original': 'keep'});
          await service.closeAndReset();
        }
        final original = await File(path).readAsBytes();
        service.failOpen = true;
        final vm = LaunchViewModel(service, files: BackupFiles(backup()));
        addTearDown(vm.dispose);

        expect(await vm.importBackup(), isFalse);
        expect(await File(path).readAsBytes(), original);
        if (corrupt) {
          for (final suffix in ['-wal', '-shm', '-journal']) {
            expect(
              await File('$path$suffix').readAsString(),
              'original $suffix',
            );
          }
        } else {
          service.failOpen = false;
          expect((await service.getSettings())['original'], 'keep');
        }
      },
    );
  }

  for (final corrupt in [false, true]) {
    test(
      'latest invalid recovery leaves ${corrupt ? 'corrupt' : 'healthy'} database untouched',
      () async {
        if (corrupt) {
          await File(path).writeAsString('unopenable original database');
        } else {
          await service.saveSettings({'original': 'keep'});
          await service.closeAndReset();
        }
        final original = await File(path).readAsBytes();
        await DatabaseBackup.writeRecovery(
          path,
          invalidBackups['unsupported schema']!,
          'before-daily',
        );

        await expectLater(
          service.restoreLatestRecoveryCopy(),
          throwsA(isA<FormatException>()),
        );
        expect(await File(path).readAsBytes(), original);
      },
    );
  }

  test(
    'database access waits for recovery and reads the installed database',
    () async {
      await service.saveSettings({'original': 'keep'});
      service.recoveryStarted = Completer<void>();
      service.allowRecovery = Completer<void>();
      final started = service.recoveryStarted!.future;
      final importing = service.importRecoveryBackup(backup());
      await started;
      var readCompleted = false;
      final reading = service.getSettings().then((value) {
        readCompleted = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      expect(readCompleted, isFalse);

      service.allowRecovery!.complete();
      await importing;
      expect((await reading)['restored'], 'yes');
      expect((await reading)['original'], isNull);
    },
  );

  test('simultaneous recoveries are serialized', () async {
    await service.saveSettings({'original': 'keep'});
    service.recoveryStarted = Completer<void>();
    service.allowRecovery = Completer<void>();
    final started = service.recoveryStarted!.future;
    final first = service.importRecoveryBackup(backup());
    await started;
    final second = service.importRecoveryBackup(
      backup(
        data: {
          'app_settings': [
            {'key': 'second', 'value': 'yes'},
          ],
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(service.maximumRecoveries, 1);

    service.allowRecovery!.complete();
    await Future.wait([first, second]);
    expect(service.maximumRecoveries, 1);
    expect((await service.getSettings())['second'], 'yes');
  });

  test('current-version exported backup restores a corrupt database', () async {
    final source = DatabaseService.atPath(
      '${directory.path}/source.db',
      factory: databaseFactoryFfi,
      credentials: MemoryCredentialStore(),
    );
    late String content;
    try {
      await source.saveSettings({'modern_backup': 'preserved'});
      content = await source.exportFullDataAsJson();
    } finally {
      await source.closeAndReset();
    }
    await File(path).writeAsString('unopenable original database');

    await service.importRecoveryBackup(content);

    expect((await service.getSettings())['modern_backup'], 'preserved');
  });

  test('latest valid recovery replaces corrupt database', () async {
    await File(path).writeAsString('unopenable original database');
    await DatabaseBackup.writeRecovery(path, backup(), 'before-daily');

    expect(await service.restoreLatestRecoveryCopy(), isTrue);
    expect((await service.getSettings())['restored'], 'yes');
  });
}
