import 'dart:io';

import 'package:flutter/material.dart' show DateUtils;

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:knotes/core/models/recovery_copy.dart';
import 'package:knotes/core/database/database_backup.dart';
import 'package:knotes/core/database/database_schema.dart';
import 'package:knotes/core/database/database_context.dart';
import 'package:knotes/core/database/recovery_import.dart';

mixin BackupRepository on DatabaseContext {
  Future<List<File>> getRecoveryFiles() => findRecoveryFiles();

  Future<List<File>> findRecoveryFiles() async {
    final dbPath = await resolveDatabasePath();
    if (dbPath == inMemoryDatabasePath) return [];
    final directory = Directory(p.dirname(dbPath));
    if (!await directory.exists()) return [];
    final files = await directory
        .list()
        .where(
          (file) =>
              file is File &&
              file.path.startsWith('$dbPath.before-') &&
              file.path.endsWith('.json'),
        )
        .cast<File>()
        .toList();
    // Names start with the reason, so sort by the embedded timestamp instead.
    files.sort((a, b) => _stamp(b).compareTo(_stamp(a)));
    return files;
  }

  static int _stamp(File file) =>
      int.tryParse(file.path.split('-').last.split('.').first) ?? 0;

  static const _dailyKeep = 7;

  /// Writes at most one automatic copy per day and keeps the last week, so a
  /// later corruption can be rolled back without a manual export.
  Future<bool> ensureDailySnapshot({DateTime? now}) async {
    final db = await database;
    if (db.path == inMemoryDatabasePath) return false;
    final today = now ?? DateTime.now();
    final daily = (await findRecoveryFiles())
        .where((f) => f.path.contains('.before-daily-'))
        .toList();
    final latest = daily.isEmpty
        ? null
        : DateTime.fromMicrosecondsSinceEpoch(_stamp(daily.first));
    if (latest != null && DateUtils.isSameDay(latest, today)) return false;
    final check = await db.rawQuery('PRAGMA quick_check');
    // Never rotate good copies out with a snapshot of a damaged database.
    if (check.firstOrNull?.values.firstOrNull != 'ok') return false;
    final content = await db.transaction(
      (txn) => DatabaseBackup.encode(txn, DatabaseBackup.version),
    );
    await DatabaseBackup.writeRecovery(db.path, content, 'before-daily');
    for (final old in daily.skip(_dailyKeep - 1)) {
      try {
        await old.delete();
      } catch (_) {}
    }
    return true;
  }

  Future<bool> hasRecoveryCopies() async {
    final files = await findRecoveryFiles();
    return files.isNotEmpty;
  }

  Future<List<RecoveryCopy>> getRecoveryCopies() async => [
    for (final file in await getRecoveryFiles())
      RecoveryCopy(
        id: file.path,
        createdAt: DateTime.fromMicrosecondsSinceEpoch(_stamp(file)).toLocal(),
        beforeUpdate: file.path.contains('before-v'),
        automatic: file.path.contains('before-daily-'),
      ),
  ];

  Future<String> readRecoveryCopy(String id) async {
    final files = await getRecoveryFiles();
    final file = files.where((file) => file.path == id).firstOrNull;
    if (file == null) throw StateError('La copia ya no está disponible');
    return file.readAsString();
  }

  String? lastRecoveryPath;

  Future<String> exportFullDataAsJson() async {
    final db = await database;
    return db.transaction(
      (txn) => DatabaseBackup.encode(txn, DatabaseBackup.version),
    );
  }

  Future<Map<String, int>> inspectBackup(String content) async {
    final data = DatabaseBackup.decode(content);
    final db = await database;
    await DatabaseBackup.validateColumns(db, data);
    return data.map((key, rows) => MapEntry(key, rows.length));
  }

  Future<void> importFullDataFromJson(String jsonContent) async {
    final data = DatabaseBackup.decode(jsonContent);
    final db = await database;
    await _importBackupData(db, data);
    notifyChanged();
  }

  Future<void> _importBackupData(
    Database db,
    Map<String, List<Map<String, Object?>>> data, {
    bool saveRecovery = true,
  }) async {
    await db.transaction((txn) async {
      await DatabaseBackup.validateColumns(txn, data);
      if (saveRecovery && db.path != inMemoryDatabasePath) {
        final recovery = await DatabaseBackup.encode(
          txn,
          DatabaseBackup.version,
        );
        lastRecoveryPath = await DatabaseBackup.writeRecovery(
          db.path,
          recovery,
          'before-restore',
        );
      }
      final localConnection = await txn.query(
        'app_settings',
        where: "key LIKE 'github_%' AND key != 'github_token'",
      );
      for (final table in DatabaseBackup.deleteOrder) {
        await txn.delete(table);
      }
      for (final table in DatabaseBackup.tables) {
        for (final row in data[table]!) {
          await txn.insert(table, row);
        }
      }
      for (final row in localConnection) {
        await txn.insert('app_settings', row);
      }
      await txn.insert('app_settings', {
        'key': 'db_version',
        'value': '${DatabaseBackup.version}',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      for (final row in data['accounts']!.where(
        (row) => !row.containsKey('opening_balance'),
      )) {
        await DatabaseSchema.backfillOpeningBalances(
          txn,
          accountId: row['id'] as String,
        );
      }
      if ((await txn.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
        throw const FormatException(
          'El respaldo contiene referencias incompletas.',
        );
      }
    });
  }

  Future<void> importRecoveryBackup(String content) async {
    final data = DatabaseBackup.decode(content);
    final path = await resolveDatabasePath();
    if (path == inMemoryDatabasePath) {
      await _importBackupData(await database, data);
    } else {
      await runDatabaseRecovery(
        (reopen) => RecoveryImport.replace(
          path: path,
          factory: this.databaseFactory,
          populate: (db) => _importBackupData(db, data, saveRecovery: false),
          close: closeAndReset,
          reopen: reopen,
        ),
      );
    }
    notifyChanged();
  }

  Future<void> repairOrResetDatabase() async {
    await closeAndReset();
    final dbPath = await resolveDatabasePath();
    if (dbPath != inMemoryDatabasePath) {
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        final corrupted =
            '$dbPath.corrupted-${DateTime.now().millisecondsSinceEpoch}';
        try {
          await dbFile.rename(corrupted);
        } catch (_) {
          await dbFile.copy(corrupted);
          await dbFile.delete();
        }
        for (final suffix in ['-wal', '-shm', '-journal']) {
          final extra = File('$dbPath$suffix');
          if (await extra.exists()) {
            try {
              await extra.delete();
            } catch (_) {}
          }
        }
      }
    }
    await database;
    notifyChanged();
  }

  Future<bool> restoreLatestRecoveryCopy() async {
    final files = await findRecoveryFiles();
    if (files.isEmpty) return false;
    final content = await files.first.readAsString();
    await importRecoveryBackup(content);
    return true;
  }

  Future<String> checkDatabaseIntegrity() async {
    try {
      final db = await database;
      final result = await db.rawQuery('PRAGMA integrity_check');
      return result.firstOrNull?.values.firstOrNull?.toString() ?? 'ok';
    } catch (e) {
      return 'Error: $e';
    }
  }
}
