import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/app/app_scope.dart';
import 'package:knotes/core/database/database_backup.dart';
import 'package:knotes/core/database/database_service.dart';
import 'package:knotes/core/services/device_files.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/features/bodega/models/account.dart';
import 'package:knotes/features/bodega/models/planned_expense.dart';
import 'package:knotes/features/bodega/models/transaction_record.dart';
import 'package:knotes/features/bodega/presentation/add_account_dialog.dart';
import 'package:knotes/features/bodega/view_models/account_editor_view_model.dart';
import 'package:knotes/features/bodega/view_models/home_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Account account(
  String id, {
  double balance = 1000,
  double minimum = 0,
  String type = 'bank',
  String currency = 'USD',
  bool excluded = false,
}) => Account(
  id: id,
  name: id,
  type: type,
  balance: balance,
  minimumBalance: minimum,
  currency: currency,
  excludeFromAvailable: excluded,
  createdAt: DateTime(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late DatabaseService service;
  setUp(() async {
    service = DatabaseService.atPath(
      inMemoryDatabasePath,
      factory: databaseFactoryFfiNoIsolate,
    );
    await service.saveSettings({
      'currency': 'USD',
      'budget_mode': 'available',
      'budget_share': '50',
    });
  });
  tearDown(() => service.closeAndReset());

  test('Exclusion affects free funds and flexible budget, preserving total and savings', () async {
    await service.setCurrencyRate(currency: 'NIO', rate: .025);
    await service.createAccount(account('bank', minimum: 100));
    await service.createAccount(
      account(
        'foreign',
        balance: 4000,
        minimum: 800,
        currency: 'NIO',
        excluded: true,
      ),
    );
    await service.createAccount(
      account('credit', balance: -50, type: 'credit', excluded: true),
    );
    await service.createAccount(
      account('savings', balance: 200, type: 'vault'),
    );
    final home = HomeViewModel(service, service, service);
    addTearDown(home.dispose);
    await home.load();
    expect(home.error, isNull);
    expect(home.balance, 1250);
    expect(home.cashByCurrency['NIO'], 4000);
    expect(home.savings, 200);
    expect(home.available, 900);
    expect(home.limit, 450);

    final foreign = home.accounts.firstWhere((a) => a.id == 'foreign');
    await service.updateAccount(foreign.copyWith(excludeFromAvailable: false));
    await home.load();
    expect(home.balance, 1250);
    expect(home.available, 980);
    expect(home.limit, 490);

    await service.updateAccount(
      home.accounts
          .firstWhere((a) => a.id == 'bank')
          .copyWith(excludeFromAvailable: true),
    );
    await service.updateAccount(foreign);
    await home.load();
    expect(home.available, 0);
    expect(home.limit, 0);
    expect(home.balance, 1250);
  });

  test('Excluded commitments stay in planning; expenses and transfers remain usable and restorable', () async {
    await service.createAccount(account('bank'));
    await service.createAccount(
      account('separate', balance: 500, excluded: true),
    );
    for (final item in [
      (id: 'normal', accountId: 'bank', amount: 100.0),
      (id: 'excluded', accountId: 'separate', amount: 200.0),
      (id: 'unassigned', accountId: null, amount: 50.0),
    ]) {
      await service.addPlannedExpense(
        PlannedExpense(
          id: item.id,
          title: item.id,
          accountId: item.accountId,
          amount: item.amount,
          categoryId: 'cat_home',
          recurrence: 'one_time',
          dueDate: DateTime.now().add(const Duration(days: 1)),
          createdAt: DateTime.now(),
        ),
      );
    }
    final home = HomeViewModel(service, service, service);
    addTearDown(home.dispose);
    await home.load();
    expect(home.committed, 350);
    expect(home.available, 850);
    expect(home.limit, 425);
    final now = DateTime.now();
    await service.addTransactions([
      TransactionRecord(
        id: 'expense',
        accountId: 'separate',
        categoryId: 'cat_food',
        amount: 20,
        type: 'expense',
        date: now,
        createdAt: now,
      ),
      TransactionRecord(
        id: 'transfer',
        accountId: 'bank',
        toAccountId: 'separate',
        categoryId: 'cat_food',
        amount: 100,
        type: 'transfer',
        date: now,
        createdAt: now,
      ),
    ]);
    await home.load();
    expect(home.balance, 1480);
    expect(home.available, 750);
    expect(home.spent, 20);
    expect(home.limit, 395);
    expect(await service.getTransactions(), hasLength(2));
    final backup = await service.exportFullDataAsJson();
    await service.importFullDataFromJson(backup);
    final separate = (await service.getAccounts()).firstWhere(
      (a) => a.id == 'separate',
    );
    expect(separate.excludeFromAvailable, isTrue);
    expect(separate.balance, 580);

    final transfer = (await service.getTransactions()).firstWhere(
      (t) => t.id == 'transfer',
    );
    await service.deleteTransaction(transfer);
    await home.load();
    expect(home.available, 850);
    await service.updateAccount(separate.copyWith(excludeFromAvailable: false));
    await home.load();
    expect(home.available, 1130);
    expect(home.balance, 1480);
    expect(home.committed, 350);
    await service.verifyDataIntegrity();
  });

  test('v7 upgrade and old backup keep existing accounts included without changing money', () async {
    final directory = await Directory.systemTemp.createTemp(
      'knotes-v7-available-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/legacy.db';
    final old = DatabaseService.atPath(
      path,
      factory: databaseFactoryFfiNoIsolate,
    );
    await old.createAccount(account('legacy', balance: 321, minimum: 25));
    final db = await old.database;
    await db.execute('ALTER TABLE accounts DROP COLUMN exclude_from_available');
    await db.setVersion(7);
    await db.update(
      'app_settings',
      {'value': '7'},
      where: 'key = ?',
      whereArgs: ['db_version'],
    );
    final backup = await DatabaseBackup.encode(db, 7);
    await old.closeAndReset();
    final upgraded = DatabaseService.atPath(
      path,
      factory: databaseFactoryFfiNoIsolate,
    );
    addTearDown(upgraded.closeAndReset);
    final opened = await upgraded.database;
    expect(await opened.getVersion(), DatabaseBackup.version);
    final legacy = (await upgraded.getAccounts()).single;
    expect(legacy.excludeFromAvailable, isFalse);
    expect(legacy.balance, 321);
    expect(legacy.minimumBalance, 25);
    expect(legacy.openingBalance, 321);
    await upgraded.updateAccount(legacy.copyWith(excludeFromAvailable: true));
    final currentBackup = await upgraded.exportFullDataAsJson();
    await upgraded.importFullDataFromJson(currentBackup);
    expect((await upgraded.getAccounts()).single.excludeFromAvailable, isTrue);
    await upgraded.importFullDataFromJson(backup);
    expect((await upgraded.getAccounts()).single.excludeFromAvailable, isFalse);
    expect((await upgraded.getAccounts()).single.balance, 321);
    await upgraded.verifyDataIntegrity();
  });

  test('Account editor persists exclusion and preserves it when changing another field', () async {
    final editor = AccountEditorViewModel(service, service);
    addTearDown(editor.dispose);
    Future<bool> save({Account? original, bool? excluded}) => editor.save(
      original: original,
      name: original?.name ?? 'Banco',
      balanceText: '100',
      minimumText: '0',
      type: 'bank',
      currency: 'USD',
      color: 0xFF416543,
      excludeFromAvailable: excluded,
    );
    expect(await save(excluded: true), isTrue);
    final created = (await service.getAccounts()).single;
    expect(created.excludeFromAvailable, isTrue);
    expect(await save(original: created.copyWith(name: 'Otro')), isTrue);
    expect((await service.getAccounts()).single.name, 'Otro');
    expect((await service.getAccounts()).single.excludeFromAvailable, isTrue);
    expect(await save(original: created, excluded: false), isTrue);
    expect((await service.getAccounts()).single.excludeFromAvailable, isFalse);
    expect((await service.getAccounts()).single.balance, 100);
  });

  testWidgets(
    'Account exclusion can be saved and reopened on compact/wide light/dark layouts',
    (tester) async {
      await tester.runAsync(() => service.createAccount(account('Banco')));
      final dependencies = AppDependencies(
        finance: service,
        journal: service,
        settings: service,
        files: NativeDeviceFiles(),
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(
        () => KnotesTheme.configure({'theme_mode': 'light'}, Brightness.light),
      );
      for (final size in [const Size(320, 760), const Size(1024, 900)]) {
        for (final mode in ['light', 'dark']) {
          tester.view.physicalSize = size;
          KnotesTheme.configure({'theme_mode': mode}, Brightness.light);
          final stored = await tester.runAsync(
            () async => (await service.getAccounts()).single,
          );
          final expected = !stored!.excludeFromAvailable;
          await tester.pumpWidget(
            AppScope(
              dependencies: dependencies,
              child: MaterialApp(
                theme: KnotesTheme.expressiveTheme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(size.width == 320 ? 1.3 : 1),
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => AddAccountDialog(account: stored),
                      ),
                      child: const Text('Abrir cuenta'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Abrir cuenta'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byType(SwitchListTile),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(
            tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
            !expected,
          );
          await tester.tap(find.byType(SwitchListTile));
          await tester.pumpAndSettle();
          expect(
            tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
            expected,
          );
          await tester.scrollUntilVisible(
            find.text('Guardar cuenta'),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.runAsync(() async {
            await tester.tap(find.text('Guardar cuenta'));
            await Future<void>.delayed(const Duration(milliseconds: 400));
          });
          await tester.pumpAndSettle();
          expect(find.byType(AddAccountDialog), findsNothing);
          final updated = await tester.runAsync(
            () async => (await service.getAccounts()).single,
          );
          expect(updated!.excludeFromAvailable, expected);
          expect(updated.balance, 1000);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    },
  );
}
