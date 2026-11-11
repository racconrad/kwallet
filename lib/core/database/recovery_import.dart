import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:knotes/core/database/database_backup.dart';
import 'package:knotes/core/database/database_schema.dart';

class RecoveryImport {
  static const _suffixes = ['', '-wal', '-shm', '-journal'];

  static Future<void> replace({
    required String path,
    required DatabaseFactory factory,
    required Future<void> Function(Database) populate,
    required Future<void> Function() close,
    required Future<void> Function() reopen,
  }) async {
    final parent = Directory(p.dirname(path));
    await parent.create(recursive: true);
    final directory = await parent.createTemp(
      '${p.basename(path)}.before-recovery-',
    );
    final stagedPath = p.join(directory.path, 'replacement.db');
    final retained = <String, String>{};
    Database? staged;
    var installed = false;
    try {
      staged = await factory.openDatabase(
        stagedPath,
        options: OpenDatabaseOptions(
          version: DatabaseBackup.version,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: DatabaseSchema.create,
        ),
      );
      await populate(staged);
      await _preserveConnection(factory, path, staged);
      await staged.close();
      staged = null;

      // Keep raw originals: a damaged vault cannot be safely exported through SQLite.
      await close();
      for (final suffix in _suffixes) {
        final original = File('$path$suffix');
        if (!await original.exists()) continue;
        final saved = p.join(directory.path, 'original.db$suffix');
        await original.rename(saved);
        retained[original.path] = saved;
      }
      await File(stagedPath).rename(path);
      installed = true;
      await reopen();
    } catch (_) {
      if (installed) {
        await close();
        for (final suffix in _suffixes) {
          final replacement = File('$path$suffix');
          if (await replacement.exists()) await replacement.delete();
        }
      }
      for (final entry in retained.entries.toList()) {
        await File(entry.value).rename(entry.key);
        retained.remove(entry.key);
      }
      rethrow;
    } finally {
      if (staged != null) await staged.close();
      if (retained.isEmpty) {
        try {
          await directory.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  static Future<void> _preserveConnection(
    DatabaseFactory factory,
    String path,
    Database staged,
  ) async {
    if (!await File(path).exists()) return;
    Database? original;
    List<Map<String, Object?>> rows;
    try {
      original = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      rows = await original.query(
        'app_settings',
        where: "key LIKE 'github_%' AND key != 'github_token'",
      );
    } catch (_) {
      // Unreadable connection metadata must not prevent recovery of a damaged vault.
      return;
    } finally {
      await original?.close();
    }
    for (final row in rows) {
      await staged.insert(
        'app_settings',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
