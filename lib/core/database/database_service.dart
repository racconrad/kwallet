import 'dart:async';
import 'dart:io';

import 'package:knotes/core/services/credential_store.dart';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' as mobile;

import 'package:knotes/core/contracts/app_repositories.dart' as contracts;
import 'package:knotes/core/database/database_backup.dart';
import 'package:knotes/core/database/database_context.dart';
import 'package:knotes/core/database/database_schema.dart';
import 'package:knotes/core/database/repositories/preferences_repository.dart';
import 'package:knotes/core/database/repositories/accounts_repository.dart';
import 'package:knotes/core/database/repositories/budget_repository.dart';
import 'package:knotes/core/database/repositories/ledger_repository.dart';
import 'package:knotes/core/database/repositories/planning_repository.dart';
import 'package:knotes/core/database/repositories/insights_repository.dart';
import 'package:knotes/core/database/repositories/journal_repository.dart';
import 'package:knotes/core/database/repositories/backup_repository.dart';

export 'package:knotes/features/bodega/models/spending_summary.dart'
    show DailySpend, CategoryBreakdown;

class DatabaseService extends DatabaseContext
    with
        PreferencesRepository,
        AccountsRepository,
        BudgetRepository,
        LedgerRepository,
        PlanningRepository,
        InsightsRepository,
        JournalRepository,
        BackupRepository
    implements
        contracts.FinanceRepository,
        contracts.JournalRepository,
        contracts.SettingsRepository {
  static DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal()
    : _path = null,
      factory = null,
      credentials = const SecureCredentialStore();
  DatabaseService.atPath(
    this._path, {
    this.factory,
    CredentialStore? credentials,
  }) : credentials = credentials ?? const SecureCredentialStore();
  @override
  final CredentialStore credentials;
  final String? _path;
  final DatabaseFactory? factory;
  Future<Database>? _opening;
  Future<void>? _recovery;

  Database? _database;
  final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  @override
  Listenable get changes => changeNotifier;

  @override
  void notifyChanged() {
    changeNotifier.value++;
  }

  @override
  DatabaseFactory get databaseFactory =>
      factory ??
      (Platform.isLinux || Platform.isWindows || Platform.isMacOS
          ? databaseFactoryFfi
          : mobile.databaseFactorySqflitePlugin);

  @override
  Future<Database> get database async {
    while (_recovery != null) {
      await _recovery;
    }
    return _openDatabase();
  }

  @override
  Future<void> runDatabaseRecovery(
    Future<void> Function(Future<void> Function()) operation,
  ) async {
    while (_recovery != null) {
      await _recovery;
    }
    final completed = Completer<void>();
    _recovery = completed.future;
    try {
      try {
        await _opening;
      } catch (_) {}
      await operation(() async {
        await _openDatabase();
      });
    } finally {
      _recovery = null;
      completed.complete();
    }
  }

  Future<Database> _openDatabase() async {
    if (_database != null) return _database!;
    try {
      _database = await (_opening ??= _initDatabase());
      return _database!;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  @override
  Future<String> resolveDatabasePath() async {
    if (_path != null) return _path;
    final documents = (await getApplicationDocumentsDirectory()).path;
    final current = p.join(documents, 'knotes', 'knotes.db');
    if (await File(current).exists()) return current;
    // Keep existing databases and their adjacent recovery copies together.
    final legacyDirectory = Directory(p.join(documents, 'kwall'));
    if (await legacyDirectory.exists()) {
      return p.join(legacyDirectory.path, 'kwall.db');
    }
    return current;
  }

  @override
  Future<void> closeAndReset() async {
    if (_database != null) {
      try {
        await _database!.close();
      } catch (_) {}
      _database = null;
    }
    _opening = null;
  }

  static Future<void> _safePragma(Database db, String sql) async {
    try {
      await db.rawQuery(sql);
    } catch (_) {
      try {
        await db.execute(sql);
      } catch (e) {
        debugPrint('Safe SQLite PRAGMA skipped ($sql): $e');
      }
    }
  }

  Future<Database> _initDatabase() async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
    }

    final dbPath = await resolveDatabasePath();
    final dir = Directory(p.dirname(dbPath));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final dbFactory = databaseFactory;
    if (dbPath != inMemoryDatabasePath && await File(dbPath).exists()) {
      try {
        final previous = await dbFactory.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(readOnly: true),
        );
        try {
          final version = await previous.getVersion();
          int? appSettingsVersion;
          try {
            final res = await previous.query(
              'app_settings',
              where: 'key = ?',
              whereArgs: ['db_version'],
            );
            if (res.isNotEmpty) {
              appSettingsVersion = int.tryParse(
                res.first['value']?.toString() ?? '',
              );
            }
          } catch (_) {}

          final detectedVersion =
              appSettingsVersion != null && appSettingsVersion > version
              ? appSettingsVersion
              : version;

          if (detectedVersion > DatabaseBackup.version) {
            throw StateError(
              'Esta base de datos (v$detectedVersion) no es compatible con tu versión actual de knotes (v${DatabaseBackup.version}). No se puede restaurar automáticamente.',
            );
          }
          if (version < DatabaseBackup.version) {
            final backup = await previous.transaction(
              (txn) => DatabaseBackup.encode(txn, version),
            );
            await DatabaseBackup.writeRecovery(
              dbPath,
              backup,
              'before-v${DatabaseBackup.version}',
            );
          }
        } finally {
          await previous.close();
        }
      } catch (e) {
        if (e is StateError) rethrow;
        debugPrint('Pre-migration check skipped: $e');
      }
    }
    return dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DatabaseBackup.version,
        onConfigure: (db) async {
          await _safePragma(db, 'PRAGMA foreign_keys = ON');
          await _safePragma(db, 'PRAGMA synchronous = FULL');
          await _safePragma(db, 'PRAGMA secure_delete = ON');
          await _safePragma(db, 'PRAGMA busy_timeout = 5000');
          if (dbPath != inMemoryDatabasePath) {
            await _safePragma(db, 'PRAGMA journal_mode = WAL');
          }
        },
        onCreate: DatabaseSchema.create,
        onUpgrade: DatabaseSchema.upgrade,
      ),
    );
  }
}
