import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/app/app_scope.dart';
import 'package:knotes/core/database/database_service.dart';
import 'package:knotes/core/services/credential_store.dart';
import 'package:knotes/core/services/device_files.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/features/bodega/models/account.dart';
import 'package:knotes/features/bodega/models/transaction_record.dart';
import 'package:knotes/features/bodega/presentation/movements_screen.dart';
import 'package:knotes/features/bodega/view_models/movements_view_model.dart';
import 'package:knotes/features/journal/models/journal_models.dart';
import 'package:knotes/features/journal/presentation/goals_section.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late DatabaseService service;
  setUpAll(() => initializeDateFormatting('es'));
  setUp(() async {
    service = DatabaseService.atPath(
      inMemoryDatabasePath,
      factory: databaseFactoryFfiNoIsolate,
      credentials: MemoryCredentialStore(),
    );
    await service.database;
  });
  tearDown(() => service.closeAndReset());

  Future<void> settleDatabase(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> mount(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AppScope(
        dependencies: AppDependencies(
          finance: service,
          journal: service,
          settings: service,
          files: NativeDeviceFiles(),
        ),
        child: MaterialApp(theme: KnotesTheme.expressiveTheme, home: child),
      ),
    );
    await settleDatabase(tester);
  }

  Future<TransactionRecord> seedMovement(WidgetTester tester) async {
    final now = DateTime.now();
    final tx = TransactionRecord(
      id: 'old-expense',
      accountId: 'bank',
      categoryId: 'cat_food',
      amount: 25,
      type: 'expense',
      note: 'Compra histórica',
      date: DateTime(2020),
      createdAt: now,
    );
    await tester.runAsync(() async {
      await service.createAccount(
        Account(
          id: 'bank',
          name: 'Banco',
          type: 'bank',
          balance: 100,
          currency: 'USD',
          createdAt: now,
        ),
      );
      await service.addTransactions([tx]);
    });
    return tx;
  }

  testWidgets(
    'Historical movement cancel preserves money; confirm refreshes totals and archive',
    (tester) async {
      await seedMovement(tester);
      await mount(tester, const MovementsScreen(currency: 'USD'));
      await tester.tap(find.text('Compra histórica'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anular movimiento').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(() => service.getTransactions()),
        hasLength(1),
      );
      expect(
        (await tester.runAsync(() => service.getAccounts()))!.single.balance,
        75,
      );
      await tester.tap(find.text('Anular movimiento').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anular'));
      await settleDatabase(tester);
      expect(await tester.runAsync(() => service.getTransactions()), isEmpty);
      expect(
        (await tester.runAsync(() => service.getAccounts()))!.single.balance,
        100,
      );
      expect(find.text('0 movimientos'), findsOneWidget);
      expect(find.text('Compra histórica'), findsNothing);
      await tester.tap(find.byType(SwitchListTile));
      await settleDatabase(tester);
      expect(find.text('1 movimientos'), findsOneWidget);
      await tester.tap(find.text('Compra histórica'));
      await tester.pumpAndSettle();
      expect(find.text('Anular movimiento'), findsNothing);
      expect(find.text('Cuenta: Banco'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Historical void failure remains visible and preserves the transaction',
    (tester) async {
      await seedMovement(tester);
      await tester.runAsync(() async {
        final db = await service.database;
        await db.execute(
          "CREATE TRIGGER reject_void BEFORE INSERT ON transaction_archive BEGIN SELECT RAISE(FAIL, 'blocked'); END",
        );
      });
      await mount(tester, const MovementsScreen(currency: 'USD'));
      await tester.tap(find.text('Compra histórica'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anular movimiento').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anular'));
      await settleDatabase(tester);
      expect(
        find.text('No se pudo anular el movimiento. Reintenta.'),
        findsWidgets,
      );
      expect(
        await tester.runAsync(() => service.getTransactions()),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Void rejects duplicate and archived actions without changing money twice',
    (tester) async {
      final tx = await seedMovement(tester);
      final model = MovementsViewModel(service);
      addTearDown(model.dispose);
      await tester.runAsync(() => model.load());
      await tester.runAsync(() async {
        final first = model.voidMovement(tx);
        expect(await model.voidMovement(tx), isFalse);
        expect(await first, isTrue);
        expect(await model.voidMovement(tx), isFalse);
        expect(model.count, 0);
        expect(model.expense, 0);
        expect(model.accounts.single.balance, 100);
        model.showArchived(true);
        await model.load();
        expect(model.records, hasLength(1));
        expect(await model.voidMovement(model.records.single), isFalse);
        expect((await service.getAccounts()).single.balance, 100);
      });
    },
  );

  testWidgets('Empty movement history keeps its empty state', (tester) async {
    await mount(tester, const MovementsScreen(currency: 'USD'));
    expect(find.text('No hay movimientos con estos filtros.'), findsOneWidget);
    expect(find.text('Anular movimiento'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  Goal pastGoal(String id, {int progress = 0}) {
    final now = DateTime.now();
    return Goal(
      id: id,
      title: id,
      kind: 'manual',
      target: 3,
      progress: progress,
      startDay: now.subtract(const Duration(days: 10)),
      endDay: now.subtract(const Duration(days: 2)),
      createdAt: now,
    );
  }

  testWidgets(
    'Expired goals expand, distinguish success, and remain editable and deletable',
    (tester) async {
      await tester.runAsync(() async {
        await service.saveGoal(pastGoal('Leer más'));
        await service.saveGoal(pastGoal('Meta lograda', progress: 3));
      });
      final goals = (await tester.runAsync(() => service.getGoals()))!;
      await mount(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: GoalsSection(
              goals: goals,
              habits: const [],
              onMark: (_) async => true,
            ),
          ),
        ),
      );
      final history = find.byType(ExpansionTile);
      expect(history, findsOneWidget);
      await tester.tap(history);
      await tester.pumpAndSettle();
      expect(find.textContaining('Lo marco yo · Vencida'), findsOneWidget);
      expect(find.textContaining('¡Lograda!'), findsOneWidget);
      expect(find.byTooltip('Marcar uno más'), findsNothing);
      await tester.tap(find.text('Leer más'));
      await tester.pumpAndSettle();
      expect(find.text('Editar meta'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Leer más'),
        'Lectura renovada',
      );
      await tester.tap(find.text('Guardar meta'));
      await settleDatabase(tester);
      expect(
        (await tester.runAsync(() => service.getGoals()))!
            .any((g) => g.title == 'Lectura renovada'),
        isTrue,
      );
      await tester.tap(find.text('Meta lograda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await settleDatabase(tester);
      expect(
        (await tester.runAsync(() => service.getGoals()))!.map((g) => g.id),
        isNot(contains('Meta lograda')),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Empty goals have no inaccessible historical controls', (
    tester,
  ) async {
    await mount(
      tester,
      Scaffold(
        body: GoalsSection(
          goals: const [],
          habits: const [],
          onMark: (_) async => true,
        ),
      ),
    );
    expect(find.byTooltip('Nueva meta'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
