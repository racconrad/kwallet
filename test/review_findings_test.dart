import 'package:kwall/core/database/database_backup.dart';

import 'dart:io';

import 'package:kwall/features/bodega/models/transaction_filter.dart';
import 'package:kwall/features/journal/models/journal_models.dart';
import 'package:kwall/core/services/credential_store.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kwall/core/database/database_service.dart';
import 'package:kwall/features/bodega/models/account.dart';
import 'package:kwall/features/bodega/models/transaction_record.dart';
import 'package:kwall/features/bodega/models/front_pending_item.dart';
import 'package:kwall/features/bodega/view_models/home_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late DatabaseService service;
  late Database db;
  setUp(() async {
    service = DatabaseService.atPath(
      inMemoryDatabasePath,
      factory: databaseFactoryFfiNoIsolate,
      credentials: MemoryCredentialStore(),
    );
    db = await service.database;
  });
  tearDown(() async => db.close());
  Future<void> account(String id, String currency, double balance) =>
      service.createAccount(
        Account(
          id: id,
          name: id,
          type: 'cash',
          currency: currency,
          balance: balance,
          createdAt: DateTime(2026),
        ),
      );

  test('Backup restores rates and account currency history', () async {
    await account('cash', 'USD', 100);
    await service.setCurrencyRate(currency: 'NIO', rate: 0.025);
    final backup = await service.exportFullDataAsJson();
    final data = (jsonDecode(backup) as Map)['data'] as Map;
    expect(data.containsKey('global_currency_rates'), true);
    expect(await service.getAccountCurrencyHistory('cash'), isNotEmpty);
    await service.setCurrencyRate(currency: 'NIO', rate: 0.05);
    await service.importFullDataFromJson(backup);
    expect((await service.getCurrencyRates())['NIO'], 0.025);
    expect(await service.getAccountCurrencyHistory('cash'), isNotEmpty);
  });
  test('Export excludes credentials', () async {
    await service.saveGitHubToken('REVIEW_FAKE_TOKEN');
    expect(
      await service.exportFullDataAsJson(),
      isNot(contains('REVIEW_FAKE_TOKEN')),
    );
  });
  test('Cross-currency transfer applies configured rate', () async {
    await account('usd', 'USD', 100);
    await account('nio', 'NIO', 0);
    await service.saveSettings({'currency': 'USD'});
    await service.setCurrencyRate(currency: 'NIO', rate: 0.025);
    await service.addTransaction(
      TransactionRecord(
        id: 't',
        accountId: 'usd',
        toAccountId: 'nio',
        categoryId: 'transfer',
        amount: 10,
        type: 'transfer',
        date: DateTime(2026),
        createdAt: DateTime(2026),
      ),
    );
    final accounts = await service.getAccounts();
    expect(accounts.singleWhere((a) => a.id == 'nio').balance, 400);
    // Correct conversion at this synthetic rate would credit 400 NIO.
  });
  test('Dashboard converts currencies before summing', () async {
    await account('usd', 'USD', 100);
    await account('nio', 'NIO', 4000);
    await service.saveSettings({'currency': 'USD'});
    await service.setCurrencyRate(currency: 'NIO', rate: 0.025);
    final vm = HomeViewModel(service, service, service);
    addTearDown(vm.dispose);
    await vm.load();
    expect(vm.error, isNull);
    expect(vm.balance, 200); // Correct converted balance would be 200 USD.
  });
  test('Rate update rolls back when history insertion fails', () async {
    await db.execute(
      "CREATE TRIGGER reject_history BEFORE INSERT ON global_currency_history BEGIN SELECT RAISE(ABORT, 'review injected failure'); END",
    );
    await expectLater(
      service.setCurrencyRate(currency: 'NIO', rate: 0.025),
      throwsA(anything),
    );
    expect(await service.getCurrencyRates(), isEmpty);
    expect(await service.getCurrencyRateHistory(), isEmpty);
  });
  test('Pending sync removes absent entries', () async {
    await service.syncFrontPendingItems([
      FrontPendingItem(
        id: 'task_deleted_0',
        category: 'task',
        title: 'Deleted task',
        sourceId: 'deleted',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ]);
    await service.syncFrontPendingItems([]);
    expect(await service.getFrontPendingItems(), isEmpty);
  });
  test('New schema has account currency history index', () async {
    final indexes = await db.rawQuery(
      'PRAGMA index_list(account_currency_history)',
    );
    expect(indexes.any((r) => r['name'] == 'idx_acc_curr_hist'), true);
  });

  test(
    'Transfer reversal uses saved destination amount after rate changes',
    () async {
      await account('usd', 'USD', 100);
      await account('nio', 'NIO', 0);
      await service.setCurrencyRate(currency: 'NIO', rate: 0.025);
      await service.addTransaction(
        TransactionRecord(
          id: 't',
          accountId: 'usd',
          toAccountId: 'nio',
          categoryId: 'transfer',
          amount: 10,
          type: 'transfer',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      );
      final stored = (await service.getTransactions()).single;
      expect(stored.toAmount, 400);
      expect(stored.exchangeRate, 40);
      await service.setCurrencyRate(currency: 'NIO', rate: 0.05);
      final backup = await service.exportFullDataAsJson();
      await service.importFullDataFromJson(backup);
      await service.verifyDataIntegrity();
      await service.deleteTransaction(stored);
      final accounts = await service.getAccounts();
      expect(accounts.singleWhere((a) => a.id == 'usd').balance, 100);
      expect(accounts.singleWhere((a) => a.id == 'nio').balance, 0);
      await service.verifyDataIntegrity();
    },
  );
  test(
    'Missing rates reject transfers without partial movements or balances',
    () async {
      await account('usd', 'USD', 100);
      await account('nio', 'NIO', 0);
      await expectLater(
        service.addTransaction(
          TransactionRecord(
            id: 't',
            accountId: 'usd',
            toAccountId: 'nio',
            categoryId: 'transfer',
            amount: 10,
            type: 'transfer',
            date: DateTime.now(),
            createdAt: DateTime.now(),
          ),
        ),
        throwsStateError,
      );
      expect(await service.getTransactions(), isEmpty);
      expect((await service.getAccounts()).first.balance, 100);
    },
  );
  test(
    'Spending, history and category analytics convert the same units',
    () async {
      await account('usd', 'USD', 100);
      await account('nio', 'NIO', 4000);
      await service.setCurrencyRate(currency: 'NIO', rate: 0.025);
      final now = DateTime.now();
      for (final entry in {'usd': 10.0, 'nio': 400.0}.entries) {
        await service.addTransaction(
          TransactionRecord(
            id: entry.key,
            accountId: entry.key,
            categoryId: 'cat_food',
            amount: entry.value,
            type: 'expense',
            date: now,
            createdAt: now,
          ),
        );
      }
      expect(
        (await service.getTransactionTotals(TransactionFilter())).expense,
        20,
      );
      expect(await service.getMonthlySpentTotal(now.month, now.year), 20);
      expect(
        (await service.getCategorySpendingBreakdown(
          now.month,
          now.year,
        )).single.amount,
        20,
      );
      expect((await service.getDailySpendingLast7Days()).last.amount, 20);
    },
  );
  test(
    'Rebasing dominant currency converts budgets but preserves account units',
    () async {
      await account('usd', 'USD', 100);
      await service.setCurrencyRate(currency: 'NIO', rate: 0.025);
      await service.saveBudget(monthly: 100);
      await service.saveSettings({'currency': 'NIO'});
      expect((await service.getCurrencyRates())['USD'], 40);
      expect((await service.getCurrentBudget()).monthlyLimit, 4000);
      expect((await service.getAccounts()).single.balance, 100);
    },
  );
  test('Legacy credential migrates securely and never appears in backups or settings', () async {
    await db.insert('app_settings', {
      'key': 'github_token',
      'value': 'FAKE_LEGACY_SECRET',
    });
    expect(
      await service.exportFullDataAsJson(),
      isNot(contains('FAKE_LEGACY_SECRET')),
    );
    final settings = await service.getSettings();
    expect(settings.containsKey('github_token'), false);
    expect(await service.getGitHubToken(), 'FAKE_LEGACY_SECRET');
    expect(
      await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['github_token'],
      ),
      isEmpty,
    );
    final backup = await service.exportFullDataAsJson();
    await service.importFullDataFromJson(backup);
    expect(await service.getGitHubToken(), 'FAKE_LEGACY_SECRET');
    await expectLater(
      service.saveSettings({'github_token': 'unsafe'}),
      throwsArgumentError,
    );
  });
  test(
    'Invalid rates and currency relabeling cannot alter persisted data',
    () async {
      await account('usd', 'USD', 100);
      for (final value in [0.0, -1.0, double.nan, double.infinity]) {
        await expectLater(
          service.setCurrencyRate(currency: 'NIO', rate: value),
          throwsArgumentError,
        );
      }
      final current = (await service.getAccounts()).single;
      await expectLater(
        service.updateAccount(current.copyWith(currency: 'NIO')),
        throwsStateError,
      );
      expect((await service.getAccounts()).single.currency, 'USD');
    },
  );
  test(
    'Pending projection follows source deletions without loading Home',
    () async {
      await service.saveHabit('h', 'Caminar');
      expect((await service.getFrontPendingItems()).single.sourceId, 'h');
      await service.deleteHabit('h');
      expect(await service.getFrontPendingItems(), isEmpty);
      await service.saveNote(
        PersonalNote(
          id: 'n',
          title: 'Lista',
          kind: 'list',
          items: [NoteItem('Tarea', done: false)],
          updatedAt: DateTime.now(),
        ),
      );
      expect((await service.getFrontPendingItems()).single.sourceId, 'n');
      await service.setNoteItem('n', 0, true, expectedText: 'Tarea');
      expect(await service.getFrontPendingItems(), isEmpty);
    },
  );
  test('Version 4 migration preserves legacy credited amounts and creates recovery', () async {
    final dir = await Directory.systemTemp.createTemp('kwall-v4-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/legacy.db';
    final old = DatabaseService.atPath(
      path,
      factory: databaseFactoryFfiNoIsolate,
    );
    final legacy = await old.database;
    await old.createAccount(
      Account(
        id: 'old',
        name: 'Old',
        type: 'cash',
        currency: 'USD',
        balance: 25,
        createdAt: DateTime(2026),
      ),
    );
    for (final table in ['transactions', 'transaction_archive']) {
      for (final op in ['insert', 'update']) {
        await legacy.execute('DROP TRIGGER validate_${table}_$op');
      }
      for (final column in [
        'currency',
        'to_currency',
        'to_amount',
        'exchange_rate',
      ]) {
        await legacy.execute('ALTER TABLE $table DROP COLUMN $column');
      }
    }
    await legacy.execute('DROP INDEX idx_acc_curr_hist');
    await legacy.execute(
      'ALTER TABLE global_currency_history DROP COLUMN base_currency',
    );
    await legacy.setVersion(4);
    await legacy.close();
    final upgraded = DatabaseService.atPath(
      path,
      factory: databaseFactoryFfiNoIsolate,
    );
    final opened = await upgraded.database;
    addTearDown(opened.close);
    expect(await opened.getVersion(), DatabaseBackup.version);
    expect((await upgraded.getAccounts()).single.balance, 25);
    expect(await upgraded.getRecoveryFiles(), hasLength(1));
    for (final table in [
      'transactions',
      'transaction_archive',
      'global_currency_history',
      'account_currency_history',
    ]) {
      expect(
        await opened.rawQuery('PRAGMA table_info($table)'),
        await db.rawQuery('PRAGMA table_info($table)'),
      );
      expect(
        await opened.rawQuery('PRAGMA index_list($table)'),
        await db.rawQuery('PRAGMA index_list($table)'),
      );
    }
    await upgraded.verifyDataIntegrity();
  });

  test('Version 1 schema migrates with data and automatic recovery', () async {
    final dir = await Directory.systemTemp.createTemp('kwall-v1-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/legacy.db';
    final old = await databaseFactoryFfiNoIsolate.openDatabase(path);
    for (final sql in (await File(
      'test/fixtures/schema_v1.sql',
    ).readAsString()).split(';')) {
      if (sql.trim().isNotEmpty) await old.execute(sql);
    }
    await old.insert('accounts', {
      'id': 'cash',
      'name': 'Efectivo',
      'type': 'cash',
      'balance': 123.0,
      'currency': 'USD',
      'icon_key': 'wallet',
      'color_value': 0,
      'created_at': '2026-01-01',
    });
    await old.setVersion(1);
    await old.close();
    final migrated = DatabaseService.atPath(
      path,
      factory: databaseFactoryFfiNoIsolate,
    );
    final opened = await migrated.database;
    addTearDown(opened.close);
    expect(await opened.getVersion(), DatabaseBackup.version);
    expect((await migrated.getAccounts()).single.openingBalance, 123);
    expect(await migrated.getRecoveryFiles(), hasLength(1));
    await migrated.verifyDataIntegrity();
  });
}
