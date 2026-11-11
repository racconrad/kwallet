import 'package:knotes/core/services/credential_store.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

abstract class DatabaseContext {
  Future<Database> get database;
  DatabaseFactory get databaseFactory;
  Future<void> runDatabaseRecovery(
    Future<void> Function(Future<void> Function()) operation,
  );
  void notifyChanged();
  CredentialStore get credentials;
  Future<String> resolveDatabasePath();
  Future<void> closeAndReset();
}
