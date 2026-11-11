import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:knotes/core/database/database_service.dart';
import 'package:knotes/core/services/credential_store.dart';
import 'package:knotes/features/bodega/view_models/home_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SnapshotDatabase extends DatabaseService {
  SnapshotDatabase(super.path)
    : super.atPath(
        factory: databaseFactoryFfiNoIsolate,
        credentials: MemoryCredentialStore(),
      );

  int attempts = 0;
  bool rejectSnapshot = false;
  Completer<bool>? pendingSnapshot;

  @override
  Future<bool> ensureDailySnapshot({DateTime? now}) async {
    attempts++;
    if (rejectSnapshot) throw const FileSystemException('Disk unavailable');
    if (pendingSnapshot case final pending?) return pending.future;
    return super.ensureDailySnapshot(now: now);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late SnapshotDatabase service;

  setUp(() async {
    service = SnapshotDatabase(inMemoryDatabasePath);
    await service.database;
  });
  tearDown(() => service.closeAndReset());

  test('Home retries a failed daily snapshot on the next refresh', () async {
    service.rejectSnapshot = true;
    final home = HomeViewModel(service, service, service);
    addTearDown(home.dispose);
    await home.load();
    await Future<void>.delayed(Duration.zero);
    expect(service.attempts, 1);

    service.rejectSnapshot = false;
    await home.load();
    await Future<void>.delayed(Duration.zero);
    expect(service.attempts, 2);
    expect(home.error, isNull);
  });

  test('Home checks daily copies again after a completed attempt', () async {
    final home = HomeViewModel(service, service, service);
    addTearDown(home.dispose);
    await home.load();
    await Future<void>.delayed(Duration.zero);
    await home.load();
    await Future<void>.delayed(Duration.zero);
    expect(service.attempts, 2);
  });

  test('Home does not start overlapping daily copies', () async {
    service.pendingSnapshot = Completer<bool>();
    final home = HomeViewModel(service, service, service);
    addTearDown(home.dispose);
    await home.load();
    await home.load();
    expect(service.attempts, 1);
    service.pendingSnapshot!.complete(true);
    await Future<void>.delayed(Duration.zero);
    await home.load();
    expect(service.attempts, 2);
  });

  test('Home respects disabled automatic copies', () async {
    await service.saveSettings({'auto_backup': 'false'});
    final home = HomeViewModel(service, service, service);
    addTearDown(home.dispose);
    await home.load();
    expect(service.attempts, 0);
  });
}
