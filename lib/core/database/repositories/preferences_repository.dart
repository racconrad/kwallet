import 'package:knotes/features/bodega/models/account.dart';
import 'package:knotes/features/bodega/models/category_model.dart';
import 'package:knotes/features/bodega/models/quick_expense.dart';

import 'package:uuid/uuid.dart';

import 'package:knotes/features/journal/models/journal_models.dart';

import 'package:knotes/core/database/currency_snapshot.dart';
import 'package:knotes/core/models/currency_conversion.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:knotes/core/database/database_context.dart';
import 'package:knotes/core/database/repositories/currency_rates_repository.dart';

mixin PreferencesRepository on DatabaseContext {
  Future<String?> getGitHubToken() async {
    final db = await database;
    final legacy = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['github_token'],
    );
    if (legacy.isNotEmpty) {
      final token = legacy.first['value'] as String;
      if (token.isNotEmpty) {
        await credentials.write(token);
        if (await credentials.read() != token) {
          throw StateError('No se pudo proteger la credencial');
        }
      }
      await db.transaction((txn) async {
        await txn.delete(
          'app_settings',
          where: 'key = ?',
          whereArgs: ['github_token'],
        );
        await txn.insert('app_settings', {
          'key': 'github_connected',
          'value': token.isNotEmpty ? 'true' : 'false',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
      return token.isEmpty ? null : token;
    }
    return credentials.read();
  }

  Future<void> saveGitHubToken(String? token) async {
    await credentials.write(token);
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['github_token'],
      );
      await txn.insert('app_settings', {
        'key': 'github_connected',
        'value': token != null && token.isNotEmpty ? 'true' : 'false',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    notifyChanged();
  }

  Future<String> getCurrency() async {
    final db = await database;
    final res = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['currency'],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return res.first['value'] as String;
    }
    return '\$';
  }

  Future<void> setCurrency(String newCurrency) async {
    final db = await database;
    await db.insert('app_settings', {
      'key': 'currency',
      'value': newCurrency,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    notifyChanged();
  }

  Future<Map<String, String>> getSettings() async {
    final db = await database;
    final legacy = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['github_token'],
    );
    if (legacy.isNotEmpty) await getGitHubToken();
    final rows = await db.query(
      'app_settings',
      where: 'key != ?',
      whereArgs: ['github_token'],
    );
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  Future<void> saveSettings(Map<String, String> values) async {
    if (values.containsKey('github_token')) {
      throw ArgumentError('Usa almacenamiento seguro');
    }
    final db = await database;
    await db.transaction((txn) => _writeSettings(txn, values));
    notifyChanged();
  }

  Future<void> _writeSettings(
    DatabaseExecutor txn,
    Map<String, String> values,
  ) async {
    if (values.containsKey('currency')) {
      final snapshot = await CurrencySnapshot.read(txn);
      final next = values['currency']!;
      final configuredBase = await txn.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['currency'],
      );
      final hasAccounts = (await txn.query('accounts', limit: 1)).isNotEmpty;
      final hasAmounts = (await txn.rawQuery(
        'SELECT 1 FROM budget_allocations WHERE amount > 0 UNION ALL SELECT 1 FROM planned_expenses WHERE account_id IS NULL AND amount > 0 LIMIT 1',
      )).isNotEmpty;
      if (CurrencyConversion.code(next) !=
              CurrencyConversion.code(snapshot.base) &&
          (configuredBase.isNotEmpty ||
              hasAccounts ||
              hasAmounts ||
              snapshot.rates.isNotEmpty)) {
        final factor = !hasAccounts && !hasAmounts && snapshot.rates.isEmpty
            ? 1.0
            : snapshot.convert(1, snapshot.base, next);
        final rates = {...snapshot.rates, snapshot.base: 1.0};
        await txn.delete('global_currency_rates');
        for (final entry in rates.entries) {
          if (CurrencyConversion.code(entry.key) ==
              CurrencyConversion.code(next)) {
            continue;
          }
          await txn.insert('global_currency_history', {
            'id': const Uuid().v4(),
            'currency': CurrencyConversion.code(entry.key),
            'base_currency': next,
            'previous_rate': entry.value,
            'new_rate': entry.value * factor,
            'notes': 'Cambio de moneda principal',
            'created_at': DateTime.now().toIso8601String(),
          });
          await txn.insert('global_currency_rates', {
            'currency': CurrencyConversion.code(entry.key),
            'rate': entry.value * factor,
            'updated_at': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await txn.rawUpdate(
          'UPDATE budget_allocations SET amount = amount * ?',
          [factor],
        );
        await txn.rawUpdate(
          'UPDATE planned_expenses SET amount = amount * ? WHERE account_id IS NULL',
          [factor],
        );
      }
    }
    for (final entry in values.entries) {
      await txn.insert('app_settings', {
        'key': entry.key,
        'value': entry.value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> finishWelcome({
    required Map<String, String> settings,
    required Map<String, String> currencies,
    Account? account,
    List<CategoryModel> categories = const [],
    List<QuickExpense> quickExpenses = const [],
    Map<String, String> habits = const {},
    String? habitReminderTime,
    List<PersonalNote> notes = const [],
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final completed = await txn.query(
        'app_settings',
        where: "key = 'welcome_seen' AND value = '1'",
      );
      if (completed.isNotEmpty) return;
      await _writeSettings(txn, {...settings}..remove('welcome_seen'));
      final now = DateTime.now().toIso8601String();
      for (final entry in currencies.entries) {
        if (entry.key.trim().isEmpty) throw ArgumentError('Símbolo inválido');
        await txn.insert('user_currencies', {
          'code': entry.key.trim(),
          'name': entry.value.trim(),
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (account != null) {
        if (!account.balance.isFinite ||
            account.name.trim().isEmpty ||
            account.currency.trim().isEmpty) {
          throw ArgumentError('Cuenta inválida');
        }
        await txn.insert('accounts', account.toMap());
        for (final currency in account.currencies) {
          await txn.insert('account_currency_history', {
            'id': const Uuid().v4(),
            'account_id': account.id,
            'base_currency': account.currency,
            'currency': currency,
            'conversion_rate': 1.0,
            'previous_rate': null,
            'change_type': currency == account.currency
                ? 'initial_base'
                : 'initial_secondary',
            'notes': 'Moneda configurada',
            'created_at': now,
          });
        }
      }
      for (final category in categories) {
        await txn.insert('categories', category.toMap());
      }
      for (final expense in quickExpenses) {
        if (!expense.amount.isFinite ||
            expense.amount <= 0 ||
            expense.title.trim().isEmpty) {
          throw ArgumentError('Gasto inválido');
        }
        await txn.insert('quick_expenses', expense.toMap());
      }
      for (final entry in habits.entries) {
        if (entry.value.trim().isEmpty) throw ArgumentError('Hábito inválido');
        await txn.insert('habits', {
          'id': entry.key,
          'title': entry.value.trim(),
          'reminder_time': habitReminderTime,
          'created_at': now,
        });
      }
      for (final note in notes) {
        if (note.title.trim().isEmpty) throw ArgumentError('Nota inválida');
        await txn.insert('personal_notes', note.toMap());
      }
      await txn.insert('app_settings', {
        'key': 'welcome_seen',
        'value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    notifyChanged();
  }

  Future<Map<String, double>> getCurrencyRates() async {
    final db = await database;
    return CurrencyRatesRepository(db).getRates();
  }

  Future<void> setCurrencyRate({
    required String currency,
    required double rate,
    String notes = '',
  }) async {
    final db = await database;
    await CurrencyRatesRepository(db)
        .setRate(currency: currency, rate: rate, notes: notes);
    notifyChanged();
  }

  Future<void> removeCurrencyRate(String currency) async {
    final db = await database;
    await CurrencyRatesRepository(db).removeRate(currency);
    notifyChanged();
  }

  Future<List<Map<String, dynamic>>> getCurrencyRateHistory({
    String? currency,
  }) async {
    final db = await database;
    return CurrencyRatesRepository(db).getHistory(currency: currency);
  }

  Future<Map<String, String>> getUserCurrencies() async {
    final db = await database;
    final rows = await db.query('user_currencies', orderBy: 'created_at ASC');
    return {
      for (final row in rows)
        row['code'] as String: (row['name'] as String?) ?? '',
    };
  }

  Future<void> saveUserCurrency(String code, [String name = '']) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    final db = await database;
    await db.insert('user_currencies', {
      'code': trimmed,
      'name': name.trim(),
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    notifyChanged();
  }

  Future<void> deleteUserCurrency(String code) async {
    final canonical = CurrencyConversion.code(code);
    final db = await database;
    await db.transaction((txn) async {
      final accounts = await txn.query('accounts');
      if (accounts.any(
        (a) => CurrencyConversion.code(a['currency'] as String) == canonical,
      )) {
        throw StateError('La moneda está en uso por una cuenta');
      }
      final main = await txn.query('app_settings', where: "key = 'currency'");
      if (main.isNotEmpty &&
          CurrencyConversion.code(main.first['value'] as String) == canonical) {
        throw StateError('No puedes eliminar la moneda principal');
      }
      final currencies = await txn.query('user_currencies');
      for (final row in currencies.where(
        (r) => CurrencyConversion.code(r['code'] as String) == canonical,
      )) {
        await txn.delete(
          'user_currencies',
          where: 'code = ?',
          whereArgs: [row['code']],
        );
      }
      await txn.delete(
        'global_currency_rates',
        where: 'currency = ?',
        whereArgs: [canonical],
      );
    });
    notifyChanged();
  }
}
