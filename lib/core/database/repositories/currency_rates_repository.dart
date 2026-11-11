import 'package:knotes/core/models/currency_conversion.dart';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class CurrencyRatesRepository {
  final Database db;
  static const _uuid = Uuid();

  CurrencyRatesRepository(this.db);

  Future<Map<String, double>> getRates() async {
    final rows = await db.query('global_currency_rates');
    final result = <String, double>{};
    for (final row in rows) {
      final cur = row['currency'] as String;
      final rate = (row['rate'] as num?)?.toDouble() ?? 1.0;
      result[cur] = rate;
    }
    return result;
  }

  Future<void> setRate({
    required String currency,
    required double rate,
    String notes = '',
  }) async {
    final trimmed = CurrencyConversion.code(currency);
    if (trimmed.isEmpty || !rate.isFinite || rate <= 0) {
      throw ArgumentError('Tasa inválida');
    }
    await db.transaction((txn) async {
      final existing = await txn.query(
        'global_currency_rates',
        where: 'currency = ?',
        whereArgs: [trimmed],
      );

      double? prevRate;
      if (existing.isNotEmpty) {
        prevRate = (existing.first['rate'] as num?)?.toDouble();
      }

      final baseRows = await txn.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['currency'],
      );
      final baseCurrency = baseRows.firstOrNull?['value'] as String? ?? '\$';
      final now = DateTime.now().toIso8601String();

      await txn.insert('global_currency_rates', {
        'currency': trimmed,
        'rate': rate,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final defined = await txn.query('user_currencies');
      if (!defined.any(
        (row) => CurrencyConversion.code(row['code'] as String) == trimmed,
      )) {
        await txn.insert('user_currencies', {
          'code': currency.trim(),
          'name': '',
          'created_at': now,
        });
      }

      await txn.insert('global_currency_history', {
        'id': _uuid.v4(),
        'currency': trimmed,
        'previous_rate': prevRate,
        'new_rate': rate,
        'base_currency': baseCurrency,
        'notes': notes,
        'created_at': now,
      });
    });
  }

  Future<void> removeRate(String currency) async {
    final trimmed = CurrencyConversion.code(currency);
    final accounts = await db.query('accounts');
    if (accounts.any(
      (a) => CurrencyConversion.code(a['currency'] as String) == trimmed,
    )) {
      throw StateError('La moneda está en uso por una cuenta');
    }
    await db.delete(
      'global_currency_rates',
      where: 'currency = ?',
      whereArgs: [trimmed],
    );
  }

  Future<List<Map<String, dynamic>>> getHistory({String? currency}) async {
    if (currency != null && currency.isNotEmpty) {
      return db.query(
        'global_currency_history',
        where: 'currency = ?',
        whereArgs: [CurrencyConversion.code(currency)],
        orderBy: 'created_at DESC',
        limit: 50,
      );
    }
    return db.query(
      'global_currency_history',
      orderBy: 'created_at DESC',
      limit: 50,
    );
  }

  static double convert(
    double amount, {
    required String from,
    required String to,
    required Map<String, double> rates,
    required String dominantCurrency,
  }) {
    return CurrencyConversion.convert(
      amount,
      from: from,
      to: to,
      rates: rates,
      dominantCurrency: dominantCurrency,
    );
  }
}
