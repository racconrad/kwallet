import 'package:flutter_test/flutter_test.dart';
import 'package:knotes/core/database/database_service.dart';
import 'package:knotes/features/bodega/models/account.dart';
import 'package:knotes/features/bodega/models/category_model.dart';
import 'package:knotes/features/bodega/models/quick_expense.dart';
import 'package:knotes/features/welcome/view_models/launch_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late DatabaseService service;
  final now = DateTime(2026, 10, 20);
  setUp(
    () => service = DatabaseService.atPath(
      inMemoryDatabasePath,
      factory: databaseFactoryFfiNoIsolate,
    ),
  );
  tearDown(() => service.closeAndReset());

  test(
    'Fresh database and skipped setup contain no preloaded user data',
    () async {
      final db = await service.database;
      for (final table in [
        'accounts',
        'categories',
        'quick_expenses',
        'habits',
        'personal_notes',
        'budget_allocations',
        'user_currencies',
        'global_currency_rates',
        'transactions',
      ]) {
        expect(await db.query(table), isEmpty, reason: table);
      }
      expect(await service.getUserCurrencies(), isEmpty);
      expect((await service.getSettings())['currency'], isNull);
      final model = LaunchViewModel(service);
      expect(
        await model.enter(petStyle: 'golem_classic', petName: 'Terra'),
        isTrue,
      );
      expect((await service.getSettings())['welcome_seen'], '1');
      expect(await service.getUserCurrencies(), isEmpty);
      expect(await service.getAccounts(), isEmpty);
      expect(await service.getHabits(), isEmpty);
      expect(await service.getQuickExpenses(), isEmpty);
      expect(await service.getCurrencyRates(), isEmpty);
      model.dispose();
    },
  );

  test('First custom currency creates no fallback exchange rate', () async {
    await service.saveSettings({'currency': 'TOK'});
    await service.saveUserCurrency('TOK', 'Mis fichas');
    expect(await service.getCurrencyRates(), isEmpty);
    expect(await service.getUserCurrencies(), {'TOK': 'Mis fichas'});
  });

  test(
    'Welcome is atomic, can retry and never charges quick expense templates',
    () async {
      final model = LaunchViewModel(service);
      final account = Account(
        id: 'first',
        name: 'Mi cuenta',
        type: 'cash',
        balance: 100,
        currency: 'TOK',
        createdAt: now,
      );
      final category = CategoryModel(
        id: 'pause',
        name: 'Mis pausas',
        type: 'expense',
        iconKey: 'bolt',
        colorValue: 0xFF416543,
        isDefault: false,
      );
      QuickExpense expense(double amount) => QuickExpense(
        id: 'coffee',
        title: 'Mi café',
        amount: amount,
        categoryId: category.id,
        accountId: account.id,
        createdAt: now,
      );
      Future<bool> save(double amount) => model.enter(
        petStyle: 'golem_classic',
        petName: 'Terra',
        currency: 'TOK',
        currencyName: 'Fichas',
        userCurrencies: {'TOK': 'Fichas', 'OTR': 'Otras fichas'},
        account: account,
        categories: [category],
        quickExpenses: [expense(amount)],
        habits: {'read': 'Leer'},
      );
      expect(await save(double.nan), isFalse);
      expect((await service.getSettings())['welcome_seen'], isNull);
      expect((await service.getSettings())['currency'], isNull);
      expect(await service.getAccounts(), isEmpty);
      expect(await service.getUserCurrencies(), isEmpty);
      expect(await service.getCategories(), isEmpty);
      expect(await save(2), isTrue);
      expect((await service.getAccounts()).single.balance, 100);
      expect((await service.getAccounts()).single.openingBalance, 100);
      expect((await service.getQuickExpenses()).single.amount, 2);
      expect((await service.getHabits()).single.title, 'Leer');
      expect(await service.getTransactions(), isEmpty);
      expect(await service.getExperience(), 0);
      expect(await save(2), isTrue);
      expect(await service.getAccounts(), hasLength(1));
      expect(await service.getCategories(), hasLength(1));
      expect(await service.getQuickExpenses(), hasLength(1));
      expect(await service.getHabits(), hasLength(1));
      model.dispose();
    },
  );

  test(
    'Rates retain user currency symbols and deleting an in-use alias fails',
    () async {
      await service.saveSettings({'currency': 'C\$'});
      await service.saveUserCurrency('C\$', 'Mi córdoba');
      await service.saveUserCurrency('€', 'Mi euro');
      await service.setCurrencyRate(currency: '€', rate: 40);
      expect(await service.getUserCurrencies(), {
        'C\$': 'Mi córdoba',
        '€': 'Mi euro',
      });
      await service.createAccount(
        Account(
          id: 'euro',
          name: 'Mi efectivo',
          type: 'cash',
          balance: 10,
          currency: 'EUR',
          createdAt: now,
        ),
      );
      await expectLater(service.deleteUserCurrency('€'), throwsStateError);
      await expectLater(service.deleteUserCurrency('NIO'), throwsStateError);
      expect(await service.getUserCurrencies(), hasLength(2));
      expect((await service.getCurrencyRates())['EUR'], 40);
    },
  );

  test(
    'Changing principal currency preserves account balances and rebases totals',
    () async {
      await service.saveSettings({'currency': 'USD'});
      await service.saveUserCurrency('USD', 'Dólar');
      await service.saveUserCurrency('NIO', 'Córdoba');
      await service.createAccount(
        Account(
          id: 'cash',
          name: 'Efectivo',
          type: 'cash',
          balance: 10,
          currency: 'USD',
          createdAt: now,
        ),
      );
      await service.setMonthlyBudget(100);
      await expectLater(
        service.saveSettings({'currency': 'NIO'}),
        throwsStateError,
      );
      expect((await service.getSettings())['currency'], 'USD');
      await service.setCurrencyRate(currency: 'NIO', rate: 1 / 36);
      await service.saveSettings({'currency': 'NIO'});
      final account = (await service.getAccounts()).single;
      expect(account.currency, 'USD');
      expect(account.balance, 10);
      expect(account.openingBalance, 10);
      expect(
        (await service.getCurrentBudget()).monthlyLimit,
        closeTo(3600, 0.001),
      );
      expect((await service.getCurrencyRates())['USD'], closeTo(36, 0.001));
      expect(await service.getTransactions(), isEmpty);
    },
  );
}
