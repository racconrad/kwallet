import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knotes/core/database/database_backup.dart';
import 'package:knotes/core/database/database_service.dart';
import 'package:knotes/core/widgets/pet_loading_screen.dart';
import 'package:knotes/features/bodega/models/account.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('DatabaseService Defensive PRAGMA and Integrity Tests', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('knotes_db_test_');
      dbPath = '${tempDir.path}/test_knotes.db';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'initializes database with defensive pragmas and passes integrity check',
      () async {
        final service = DatabaseService.atPath(
          dbPath,
          factory: databaseFactoryFfi,
        );
        final db = await service.database;
        expect(db.isOpen, isTrue);

        final integrity = await service.checkDatabaseIntegrity();
        expect(integrity, 'ok');

        await service.closeAndReset();
      },
    );

    test('repairOrResetDatabase moves damaged database to .corrupted and creates clean DB', () async {
      final service = DatabaseService.atPath(
        dbPath,
        factory: databaseFactoryFfi,
      );
      final db = await service.database;
      await db.execute(
        "INSERT INTO app_settings (key, value) VALUES ('test_key', 'test_value')",
      );

      final savedValue = await service.getSettings();
      expect(savedValue['test_key'], 'test_value');

      await service.repairOrResetDatabase();

      // Corrupted file should exist in directory
      final files = await tempDir.list().toList();
      final hasCorrupted = files.any((f) => f.path.contains('.corrupted-'));
      expect(hasCorrupted, isTrue);

      // New database should be fresh and empty of test_key
      final newSettings = await service.getSettings();
      expect(newSettings['test_key'], isNull);

      await service.closeAndReset();
    });

    test('hasRecoveryCopies detects pre-migration backup and restoreLatestRecoveryCopy restores it', () async {
      final service = DatabaseService.atPath(
        dbPath,
        factory: databaseFactoryFfi,
      );
      await service.database;

      // Seed an account
      await service.createAccount(
        Account(
          id: 'acc-1',
          name: 'Billetera Principal',
          type: 'cash',
          balance: 150.0,
          currency: 'USD',
          createdAt: DateTime.now(),
        ),
      );

      // Encode backup and write recovery snapshot
      final backup = await service.exportFullDataAsJson();
      await DatabaseBackup.writeRecovery(dbPath, backup, 'before-v5');

      expect(await service.hasRecoveryCopies(), isTrue);

      // Now wipe the current DB
      await service.repairOrResetDatabase();
      final wipedAccounts = await service.getAccounts();
      expect(wipedAccounts.isEmpty, isTrue);

      // Restore from recovery snapshot
      final restored = await service.restoreLatestRecoveryCopy();
      expect(restored, isTrue);

      final restoredAccounts = await service.getAccounts();
      expect(restoredAccounts.length, 1);
      expect(restoredAccounts.first.name, 'Billetera Principal');

      await service.closeAndReset();
    });
  });

  group('DatabaseService Version Incompatibility Tests', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('knotes_db_ver_test_');
      dbPath = '${tempDir.path}/incompatible.db';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('detects higher db_version in app_settings and throws clear incompatibility error', () async {
      final db = await databaseFactoryFfi.openDatabase(dbPath);
      await db.execute(
        'CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
      await db.insert('app_settings', {'key': 'db_version', 'value': '99'});
      await db.setVersion(DatabaseBackup.version);
      await db.close();

      final service = DatabaseService.atPath(
        dbPath,
        factory: databaseFactoryFfi,
      );
      expect(
        () => service.database,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('no es compatible con tu versión actual de knotes'),
          ),
        ),
      );
    });
  });

  group('PetLoadingScreen Failure & Diagnostic UI Tests', () {
    testWidgets(
      'renders sad pet, warning, and options to create vault or import backup',
      (tester) async {
        var restoreCalled = false;
        var newVaultCalled = false;
        var importCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: PetLoadingScreen(
              failed: true,
              hasRecovery: true,
              diagnosticInfo: 'DatabaseException: Incompatible schema version',
              onRestoreRecovery: () => restoreCalled = true,
              onRepairDatabase: () => newVaultCalled = true,
              onImportBackup: () => importCalled = true,
            ),
          ),
        );

        expect(find.text('Versión no compatible'), findsOneWidget);
        expect(
          find.textContaining('requiere una versión más reciente de knotes'),
          findsOneWidget,
        );
        expect(
          find.byIcon(Icons.sentiment_dissatisfied_rounded),
          findsOneWidget,
        );
        expect(find.text('Reintentar conexión'), findsNothing);
        expect(find.text('Crear nueva bóveda'), findsOneWidget);
        expect(find.text('Importar otra copia'), findsOneWidget);
        expect(find.text('Restaurar copia local previa'), findsOneWidget);
        expect(find.text('Ver detalle técnico'), findsOneWidget);

        // Tap Importar otra copia
        await tester.tap(find.text('Importar otra copia'));
        expect(importCalled, isTrue);

        // Tap Ver detalle técnico
        await tester.tap(find.text('Ver detalle técnico'));
        await tester.pumpAndSettle();
        expect(find.text('Detalle técnico del error'), findsOneWidget);
        expect(
          find.textContaining('Incompatible schema version'),
          findsOneWidget,
        );

        await tester.tap(find.text('Cerrar'));
        await tester.pumpAndSettle();

        // Tap Restaurar copia local previa -> opens confirmation dialog
        await tester.tap(find.text('Restaurar copia local previa'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Se creará un respaldo del archivo actual'),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Restaurar'));
        await tester.pumpAndSettle();
        expect(restoreCalled, isTrue);

        // Tap Crear nueva bóveda -> opens confirmation dialog
        await tester.tap(find.text('Crear nueva bóveda'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            'Se guardará tu archivo actual como copia segura',
          ),
          findsOneWidget,
        );
        await tester.tap(
          find.widgetWithText(FilledButton, 'Crear nueva bóveda').last,
        );
        await tester.pumpAndSettle();
        expect(newVaultCalled, isTrue);
      },
    );
  });
}
