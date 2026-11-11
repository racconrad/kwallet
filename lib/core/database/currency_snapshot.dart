import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:knotes/core/models/currency_conversion.dart';

class CurrencySnapshot {
  final String base;
  final Map<String, double> rates;
  CurrencySnapshot(this.base, this.rates);
  static Future<CurrencySnapshot> read(DatabaseExecutor db) async {
    final settings = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['currency'],
    );
    final rates = await db.query('global_currency_rates');
    return CurrencySnapshot(
      settings.isEmpty ? '\$' : settings.first['value'] as String,
      {
        for (final row in rates)
          row['currency'] as String: (row['rate'] as num).toDouble(),
      },
    );
  }

  static Future<double> sum(
    DatabaseExecutor db,
    String where,
    List<Object?> args,
  ) async {
    final snapshot = await read(db);
    final rows = await db.rawQuery(
      "SELECT COALESCE(currency,(SELECT currency FROM accounts WHERE accounts.id = transactions.account_id),'\$') AS unit, SUM(amount) AS total FROM transactions WHERE $where GROUP BY unit",
      args,
    );
    return rows.fold<double>(
      0,
      (sum, row) =>
          sum +
          snapshot.convert(
            (row['total'] as num).toDouble(),
            row['unit'] as String,
          ),
    );
  }

  double convert(double amount, String from, [String? to]) =>
      CurrencyConversion.convert(
        amount,
        from: from,
        to: to ?? base,
        rates: rates,
        dominantCurrency: base,
      );
}
