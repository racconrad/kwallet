import 'package:knotes/features/bodega/models/planned_expense.dart';
import 'package:knotes/features/bodega/view_models/planning_view_model.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/app/app_scope.dart';
import 'package:knotes/core/database/database_backup.dart';
import 'package:knotes/core/database/database_service.dart';
import 'package:knotes/core/models/currency_conversion.dart';
import 'package:knotes/core/services/device_files.dart';
import 'package:knotes/core/services/widget_pet_renderer.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/features/bodega/models/account.dart';
import 'package:knotes/features/bodega/models/transaction_filter.dart';
import 'package:knotes/features/bodega/models/transaction_record.dart';
import 'package:knotes/features/bodega/presentation/add_account_dialog.dart';
import 'package:knotes/features/bodega/presentation/finances_screen.dart';
import 'package:knotes/features/bodega/presentation/statistics_screen.dart';
import 'package:knotes/features/bodega/view_models/account_editor_view_model.dart';
import 'package:knotes/features/bodega/view_models/home_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Account account(
  String id, {
  double balance = 100,
  String type = 'cash',
  String currency = 'USD',
  double target = 0,
}) => Account(
  id: id,
  name: id,
  type: type,
  balance: balance,
  currency: currency,
  savingsTarget: target,
  createdAt: DateTime(2026),
);
TransactionRecord movement(
  String id, {
  String from = 'cash',
  String? to,
  String type = 'expense',
  double amount = 10,
  DateTime? date,
}) => TransactionRecord(
  id: id,
  accountId: from,
  toAccountId: to,
  type: type,
  amount: amount,
  categoryId: 'cat_food',
  date: date ?? DateTime(2026, 10, 15),
  createdAt: DateTime(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late DatabaseService service;
  setUp(() {
    service = DatabaseService.atPath(
      inMemoryDatabasePath,
      factory: databaseFactoryFfiNoIsolate,
    );
  });
  tearDown(() => service.closeAndReset());

  test(
    'Account icon, color and savings target persist on create and edit',
    () async {
      final editor = AccountEditorViewModel(service, service);
      addTearDown(editor.dispose);
      expect(
        await editor.save(
          name: 'Viaje',
          balanceText: '30',
          minimumText: '0',
          type: 'vault',
          currency: 'USD',
          color: 0xFF336B87,
          iconKey: 'travel',
          targetText: '500',
        ),
        isTrue,
      );
      final created = (await service.getAccounts()).single;
      expect(created.iconKey, 'travel');
      expect(created.colorValue, 0xFF336B87);
      expect(created.savingsTarget, 500);
      expect(
        await editor.save(
          original: created,
          name: 'Casa',
          balanceText: '999',
          minimumText: '0',
          type: 'vault',
          currency: 'USD',
          color: 0xFFA24768,
          iconKey: 'home',
          targetText: '900',
        ),
        isTrue,
      );
      final updated = (await service.getAccounts()).single;
      expect(updated.balance, 30);
      expect(updated.openingBalance, 30);
      expect(updated.iconKey, 'home');
      expect(updated.colorValue, 0xFFA24768);
      expect(updated.savingsTarget, 900);
    },
  );

  test(
    'Deactivation excludes account from new movements and can be reversed',
    () async {
      await service.createAccount(account('cash'));
      await service.setAccountArchived('cash', true);
      expect(await service.getAccounts(), isEmpty);
      expect(
        (await service.getAccounts(includeArchived: true)).single.isArchived,
        isTrue,
      );
      await expectLater(
        service.addTransactions([movement('blocked')]),
        throwsStateError,
      );
      await expectLater(
        service.adjustAccountBalance(
          'cash',
          20,
          expectedBalance: 100,
          reason: 'Recuento',
        ),
        throwsStateError,
      );
      await service.setAccountArchived('cash', false);
      await service.addTransactions([movement('ok')]);
      expect((await service.getAccounts()).single.balance, 90);
    },
  );

  test('Deletion hides accounts while preserving transfers, balance, audit and restore', () async {
    await service.createAccount(account('cash'));
    await service.createAccount(account('target', balance: 0));
    await service.addTransactions([
      movement('transfer', to: 'target', type: 'transfer'),
    ]);
    await service.deleteAccount('target');
    expect((await service.getAccounts()).map((a) => a.id), ['cash']);
    expect(
      (await service.getAccounts(includeArchived: true)).map((a) => a.id),
      ['cash'],
    );
    var history = await service.getAccounts(
      includeArchived: true,
      includeDeleted: true,
    );
    expect(history.firstWhere((a) => a.id == 'target').balance, 10);
    expect(history.firstWhere((a) => a.id == 'target').isDeleted, isTrue);
    await expectLater(
      service.setAccountArchived('target', false),
      throwsStateError,
    );
    await service.verifyDataIntegrity();
    await service.importFullDataFromJson(await service.exportFullDataAsJson());
    expect(
      (await service.getAccounts(includeArchived: true)).map((a) => a.id),
      ['cash'],
    );
    await service.deleteTransaction((await service.getTransactions()).single);
    history = await service.getAccounts(
      includeArchived: true,
      includeDeleted: true,
    );
    expect(history.firstWhere((a) => a.id == 'target').balance, 0);
    expect(history.firstWhere((a) => a.id == 'cash').balance, 100);
    await service.deleteAccount('cash');
    expect(await service.getAccounts(includeArchived: true), isEmpty);
    expect(
      await service.getTransactionPage(const TransactionFilter(archived: true)),
      hasLength(1),
    );
    await service.verifyDataIntegrity();
  });

  test('Upward and downward adjustments survive export restore and void without expense or XP', () async {
    await service.createAccount(account('cash'));
    await service.adjustAccountBalance(
      'cash',
      140,
      expectedBalance: 100,
      reason: 'Recuento inicial',
    );
    await service.adjustAccountBalance(
      'cash',
      95,
      expectedBalance: 140,
      reason: 'Corrección de efectivo',
    );
    final txs = await service.getTransactions();
    expect(
      txs.map((t) => t.type),
      containsAll(['adjustment_in', 'adjustment_out']),
    );
    expect(await service.getExperience(), 0);
    final totals = await service.getTransactionTotals(
      const TransactionFilter(),
    );
    expect(totals, (count: 2, income: 0.0, expense: 0.0));
    expect(
      (await service.getMonthlyHistory(const TransactionFilter()))
          .single
          .expense,
      0,
    );
    expect(
      await service.getTransactionPage(
        const TransactionFilter(type: 'adjustment'),
      ),
      hasLength(2),
    );
    await service.verifyDataIntegrity();
    final backup = await service.exportFullDataAsJson();
    await service.importFullDataFromJson(backup);
    expect((await service.getAccounts()).single.balance, 95);
    await service.deleteTransaction(
      txs.firstWhere((t) => t.type == 'adjustment_out'),
    );
    expect((await service.getAccounts()).single.balance, 140);
    await service.deleteTransaction(
      txs.firstWhere((t) => t.type == 'adjustment_in'),
    );
    expect((await service.getAccounts()).single.balance, 100);
    await service.importFullDataFromJson(await service.exportFullDataAsJson());
    await service.verifyDataIntegrity();
  });

  test(
    'Adjustment rejects stale balance and invalid input atomically',
    () async {
      await service.createAccount(account('cash'));
      await service.addTransactions([movement('expense')]);
      await expectLater(
        service.adjustAccountBalance(
          'cash',
          200,
          expectedBalance: 100,
          reason: 'Stale',
        ),
        throwsStateError,
      );
      await expectLater(
        service.adjustAccountBalance(
          'cash',
          double.nan,
          expectedBalance: 90,
          reason: 'Invalid',
        ),
        throwsArgumentError,
      );
      await expectLater(
        service.adjustAccountBalance(
          'cash',
          200,
          expectedBalance: 90,
          reason: ' ',
        ),
        throwsArgumentError,
      );
      expect((await service.getAccounts()).single.balance, 90);
      expect(await service.getTransactions(), hasLength(1));
    },
  );

  test('Savings contributions preserve total, reduce available and reverse correctly', () async {
    await service.createAccount(account('cash', balance: 1000));
    await service.createAccount(
      account('savings', balance: 0, type: 'vault', target: 500),
    );
    await service.addTransactions([
      movement('save', to: 'savings', type: 'transfer', amount: 250),
    ]);
    final home = HomeViewModel(service, service, service);
    addTearDown(home.dispose);
    await home.load();
    expect(home.balance, 1000);
    expect(home.available, 750);
    expect(home.savings, 250);
    expect(home.error, isNull);
    final backup = await service.exportFullDataAsJson();
    await service.importFullDataFromJson(backup);
    expect(
      (await service.getAccounts())
          .firstWhere((a) => a.id == 'savings')
          .savingsTarget,
      500,
    );
    await service.deleteTransaction((await service.getTransactions()).single);
    await home.load();
    expect(home.available, 1000);
    expect(home.savings, 0);
    await service.verifyDataIntegrity();
  });

  test('Weekly monthly statistics use whole ledger, currency conversion and calendar boundaries', () async {
    await service.saveSettings({'currency': 'USD'});
    await service.setCurrencyRate(currency: 'NIO', rate: 0.025);
    await service.createAccount(account('cash', balance: 1000));
    await service.createAccount(
      account('cordobas', balance: 1000, currency: 'NIO'),
    );
    await service.createAccount(account('savings', balance: 0, type: 'vault'));
    final records = [
      movement('previous', date: DateTime(2026, 2, 22, 23, 59), amount: 4),
      for (var i = 0; i < 8; i++)
        movement('daily$i', date: DateTime(2026, 2, 23, i), amount: 10),
      movement(
        'nio',
        from: 'cordobas',
        date: DateTime(2026, 2, 28),
        amount: 400,
      ),
      movement('last', date: DateTime(2026, 3, 1, 23, 59), amount: 20),
      movement('next', date: DateTime(2026, 3, 2), amount: 30),
      movement(
        'income',
        type: 'income',
        date: DateTime(2026, 2, 25),
        amount: 700,
      ),
      movement(
        'transfer',
        type: 'transfer',
        to: 'savings',
        date: DateTime(2026, 2, 25),
        amount: 250,
      ),
    ];
    await service.addTransactions(records);
    final week = await service.getSpendingSeries(
      monthly: false,
      date: DateTime(2026, 2, 25),
    );
    expect(week, hasLength(7));
    expect(week.first.date, DateTime(2026, 2, 23));
    expect(week.last.date, DateTime(2026, 3, 1));
    expect(week.fold<double>(0, (sum, d) => sum + d.amount), 110);
    final month = await service.getSpendingSeries(
      monthly: true,
      date: DateTime(2026, 2, 1),
    );
    expect(month, hasLength(28));
    expect(month.fold<double>(0, (sum, d) => sum + d.amount), 94);
    final breakdown = await service.getExpenseBreakdown(
      start: DateTime(2026, 2, 23),
      end: DateTime(2026, 3, 2),
    );
    expect(breakdown.single.amount, 110);
    expect(breakdown.single.percentage, 100);
    await service.deleteTransaction(
      records.firstWhere((t) => t.id == 'daily0'),
    );
    final remaining = await service.getSpendingSeries(
      monthly: false,
      date: DateTime(2026, 2, 25),
    );
    expect(remaining.fold<double>(0, (sum, d) => sum + d.amount), 100);
  });

  test('v6 migration preserves money and defaults goal; v6 backups remain restorable', () async {
    final dir = await Directory.systemTemp.createTemp('knotes-v6-goals-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/v6.db';
    final old = DatabaseService.atPath(
      path,
      factory: databaseFactoryFfiNoIsolate,
    );
    await old.createAccount(account('legacy', balance: 123));
    final db = await old.database;
    await db.execute('ALTER TABLE accounts DROP COLUMN savings_target');
    await db.execute('ALTER TABLE accounts DROP COLUMN is_deleted');
    await db.execute('ALTER TABLE accounts DROP COLUMN exclude_from_available');
    await db.setVersion(6);
    await db.insert('app_settings', {
      'key': 'db_version',
      'value': '6',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final backup = await DatabaseBackup.encode(db, 6);
    await old.closeAndReset();
    final migrated = DatabaseService.atPath(
      path,
      factory: databaseFactoryFfiNoIsolate,
    );
    addTearDown(migrated.closeAndReset);
    final opened = await migrated.database;
    expect(await opened.getVersion(), DatabaseBackup.version);
    expect((await migrated.getAccounts()).single.balance, 123);
    expect((await migrated.getAccounts()).single.savingsTarget, 0);
    await migrated.importFullDataFromJson(backup);
    await migrated.adjustAccountBalance(
      'legacy',
      130,
      expectedBalance: 123,
      reason: 'Después de migrar',
    );
    await migrated.verifyDataIntegrity();
    expect((await migrated.getAccounts()).single.balance, 130);
  });

  test(
    'Inactive and deleted accounts retain the currency of pending commitments',
    () async {
      await service.saveSettings({'currency': 'USD'});
      await service.setCurrencyRate(currency: 'NIO', rate: .025);
      await service.createAccount(
        account('cordobas', balance: 1000, currency: 'NIO'),
      );
      await service.addPlannedExpense(
        PlannedExpense(
          id: 'bill',
          title: 'Servicio',
          amount: 400,
          accountId: 'cordobas',
          categoryId: 'cat_home',
          recurrence: 'one_time',
          dueDate: DateTime.now().add(const Duration(days: 1)),
          createdAt: DateTime.now(),
        ),
      );
      final home = HomeViewModel(service, service, service);
      final planning = PlanningViewModel(service, service);
      addTearDown(home.dispose);
      addTearDown(planning.dispose);
      await service.setAccountArchived('cordobas', true);
      await home.load();
      await planning.load();
      expect(home.committed, 10);
      expect(planning.committed, 10);
      expect(home.accounts, isEmpty);
      expect(home.inactiveAccounts, hasLength(1));
      await service.deleteAccount('cordobas');
      await home.load();
      await planning.load();
      expect(home.committed, 10);
      expect(planning.committed, 10);
      expect(home.inactiveAccounts, isEmpty);
      expect(planning.accounts, isEmpty);
    },
  );

  test('Currency displays symbols without changing conversion identities', () {
    expect(KnotesTheme.formatCurrency(12, 'NIO'), 'C\$12.00');
    expect(KnotesTheme.formatCurrency(-12, 'nio'), '-C\$12.00');
    expect(
      CurrencyConversion.label('NIO', {'C\$': 'Córdoba de Nicaragua'}),
      'C\$ Córdoba de Nicaragua',
    );
    expect(CurrencyConversion.label('€', {'EUR': 'Euro'}), '€ Euro');
    expect(CurrencyConversion.label('L', {'L': 'Lempira'}), 'L Lempira');
    expect(CurrencyConversion.code('C\$'), 'NIO');
  });

  testWidgets('Widget sprites match app species, stage and pose', (
    tester,
  ) async {
    Future<ui.Image> decode(String value) async {
      final codec = await ui.instantiateImageCodec(base64Decode(value));
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      return image;
    }

    final pack = await tester.runAsync(
      () => WidgetPetRenderer.render({'pet_style': 'opossum_classic'}, 0),
    );
    expect(pack!.keys, containsAll(['idle', 'sleep', 'celebrate', 'grabbed']));
    final image = await tester.runAsync(() => decode(pack['idle']!));
    expect(image!.width, 256);
    expect(image.height, 256);
    image.dispose();
    final adult = await tester.runAsync(
      () => WidgetPetRenderer.render({'pet_style': 'opossum_classic'}, 250),
    );
    expect(pack['idle'], isNot(adult!['idle']));
    expect(adult['idle'], isNot(adult['sleep']));
    final plant = await tester.runAsync(
      () => WidgetPetRenderer.render({'pet_style': 'plant_classic'}, 250),
    );
    expect(plant!['idle'], isNot(adult['idle']));
  });

  testWidgets(
    'Finance improvements render in compact/wide light/dark layouts',
    (tester) async {
      await tester.runAsync(() async {
        await initializeDateFormatting('es');
        await service.createAccount(account('Banco', balance: 900));
        await service.createAccount(
          account('Viaje', balance: 240, type: 'vault', target: 500),
        );
        await service.createAccount(account('Anterior', balance: 20));
        await service.setAccountArchived('Anterior', true);
        final now = DateTime.now();
        await service.addTransactions([
          for (var i = 0; i < 7; i++)
            movement(
              'expense$i',
              from: 'Banco',
              amount: 10.0 + i * 2,
              date: DateTime(now.year, now.month, now.day - i),
            ),
        ]);
        if (const bool.fromEnvironment('KNOTES_CAPTURE')) {
          final config = File('.dart_tool/package_config.json').absolute;
          final packages =
              (jsonDecode(await config.readAsString()) as Map)['packages']
                  as List;
          final flutter =
              packages.firstWhere((p) => p['name'] == 'flutter') as Map;
          final root = Directory.fromUri(
            config.uri.resolve(flutter['rootUri'] as String),
          ).parent.parent.path;
          for (final entry in {
            'Roboto': 'Roboto-Regular.ttf',
            'MaterialIcons': 'MaterialIcons-Regular.otf',
          }.entries) {
            final loader = FontLoader(entry.key);
            loader.addFont(
              File('$root/bin/cache/artifacts/material_fonts/${entry.value}')
                  .readAsBytes()
                  .then(ByteData.sublistView),
            );
            await loader.load();
          }
        }
      });
      final home = HomeViewModel(service, service, service);
      await tester.runAsync(home.load);
      addTearDown(home.dispose);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final dependencies = AppDependencies(
        finance: service,
        journal: service,
        settings: service,
        files: NativeDeviceFiles(),
      );
      for (final size in [const Size(390, 844), const Size(1024, 900)]) {
        for (final mode in ['light', 'dark']) {
          tester.view.physicalSize = size;
          KnotesTheme.configure({'theme_mode': mode}, Brightness.light);
          for (final page in ['finances', 'statistics', 'account']) {
            await tester.pumpWidget(const SizedBox.shrink());
            final key = GlobalKey();
            final child = switch (page) {
              'statistics' => const StatisticsScreen(currency: 'USD'),
              'account' => AddAccountDialog(
                account: account(
                  'Viaje',
                  balance: 240,
                  type: 'vault',
                  target: 500,
                ),
              ),
              _ => FinancesScreen(
                controller: home,
                onTransaction: (_) {},
                onAddAccount: () {},
                onEditAccount: (_) {},
                onBudget: () {},
                onAgenda: () {},
              ),
            };
            await tester.pumpWidget(
              AppScope(
                dependencies: dependencies,
                child: MaterialApp(
                  theme: KnotesTheme.expressiveTheme,
                  home: RepaintBoundary(
                    key: key,
                    child: Scaffold(body: child),
                  ),
                ),
              ),
            );
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (page == 'statistics') {
              await tester.tap(find.text('Mensual'));
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 50)),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
            if (const bool.fromEnvironment('KNOTES_CAPTURE')) {
              final boundary =
                  key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              await tester.runAsync(() async {
                final image = await boundary.toImage();
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final file = File(
                  '.impeccable/review/$page-${size.width.toInt()}-$mode.png',
                );
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
            if (page == 'account') {
              await tester.scrollUntilVisible(
                find.text('Ajustar saldo'),
                250,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.pumpAndSettle();
              expect(find.text('Desactivar cuenta'), findsOneWidget);
              expect(find.text('Eliminar cuenta'), findsOneWidget);
              expect(tester.takeException(), isNull);
            }
          }
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      KnotesTheme.configure({'theme_mode': 'light'}, Brightness.light);
    },
  );
}
