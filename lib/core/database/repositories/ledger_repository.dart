import 'package:knotes/core/database/currency_snapshot.dart';
import 'package:knotes/features/bodega/models/transaction_record.dart';
import 'package:knotes/features/bodega/models/transaction_filter.dart';
import 'package:knotes/features/bodega/models/monthly_movement_summary.dart';
import 'package:knotes/core/database/transaction_writer.dart';
import 'package:knotes/core/database/database_context.dart';

mixin LedgerRepository on DatabaseContext {
  Future<List<TransactionRecord>> getTransactions({
    String? accountId,
    int limit = 100,
  }) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    if (accountId != null) {
      where = 'account_id = ? OR to_account_id = ?';
      whereArgs = [accountId, accountId];
    }

    final maps = await db.query(
      'transactions',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
      limit: limit,
    );
    return maps.map((m) => TransactionRecord.fromMap(m)).toList();
  }

  Future<List<TransactionRecord>> getTransactionPage(
    TransactionFilter filter, {
    TransactionRecord? before,
    int limit = 40,
  }) async {
    final db = await database;
    final query = filter.sql(before: before);
    return (await db.query(
      filter.archived ? 'transaction_archive' : 'transactions',
      where: query.where,
      whereArgs: query.args,
      orderBy: 'date DESC, id DESC',
      limit: limit.clamp(1, 200),
    )).map(TransactionRecord.fromMap).toList();
  }

  Future<({int count, double income, double expense})> getTransactionTotals(
    TransactionFilter filter,
  ) async {
    final db = await database;
    final query = filter.sql();
    final table = filter.archived ? 'transaction_archive' : 'transactions';
    final rows = await db.rawQuery(
      "SELECT type, COALESCE(currency,(SELECT currency FROM accounts WHERE accounts.id = $table.account_id),'\$') AS unit, COUNT(*) AS count, SUM(amount) AS amount FROM $table WHERE ${query.where} GROUP BY type,unit",
      query.args,
    );
    final snapshot = await CurrencySnapshot.read(db);
    var count = 0;
    double income = 0, expense = 0;
    for (final row in rows) {
      count += row['count'] as int;
      if (!['income', 'expense'].contains(row['type'])) continue;
      final amount = snapshot.convert(
        (row['amount'] as num).toDouble(),
        row['unit'] as String,
      );
      if (row['type'] == 'income') income += amount;
      if (row['type'] == 'expense') expense += amount;
    }
    return (count: count, income: income, expense: expense);
  }

  Future<List<MonthlyMovementSummary>> getMonthlyHistory(
    TransactionFilter filter,
  ) async {
    final db = await database;
    final query = filter.sql();
    final table = filter.archived ? 'transaction_archive' : 'transactions';
    final rows = await db.rawQuery(
      "SELECT substr(date,1,7) AS month, type, COALESCE(currency,(SELECT currency FROM accounts WHERE accounts.id = $table.account_id),'\$') AS unit, SUM(amount) AS amount FROM $table WHERE ${query.where} GROUP BY month,type,unit ORDER BY month DESC",
      query.args,
    );
    final snapshot = await CurrencySnapshot.read(db);
    final months = <String, Map<String, Object?>>{};
    for (final row in rows) {
      final month = row['month'] as String;
      final values = months.putIfAbsent(
        month,
        () => {'month': month, 'income': 0.0, 'expense': 0.0},
      );
      final type = row['type'] as String;
      if (!['income', 'expense'].contains(type)) continue;
      values[type] =
          (values[type] as double) +
          snapshot.convert(
            (row['amount'] as num).toDouble(),
            row['unit'] as String,
          );
    }
    return months.values.map(MonthlyMovementSummary.fromMap).toList();
  }

  Future<void> verifyDataIntegrity() async {
    final db = await database;
    await db.transaction((txn) async {
      final check = await txn.rawQuery('PRAGMA quick_check');
      if (check.length != 1 ||
          check.first.values.first != 'ok' ||
          (await txn.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
        throw StateError('La base de datos necesita revisión');
      }
      final accounts = await txn.query('accounts');
      final movements = await txn.rawQuery(
        "SELECT account_id, type, SUM(amount) AS amount FROM transactions GROUP BY account_id,type",
      );
      final destinations = await txn.rawQuery(
        "SELECT to_account_id AS account_id, SUM(COALESCE(to_amount,amount)) AS amount FROM transactions WHERE type = 'transfer' GROUP BY to_account_id",
      );
      for (final account in accounts) {
        var expected = (account['opening_balance'] as num).toDouble();
        for (final move in movements.where(
          (row) => row['account_id'] == account['id'],
        )) {
          expected +=
              (['income', 'adjustment_in'].contains(move['type']) ? 1 : -1) *
              (move['amount'] as num).toDouble();
        }
        for (final move in destinations.where(
          (row) => row['account_id'] == account['id'],
        )) {
          expected += (move['amount'] as num).toDouble();
        }
        if ((expected - (account['balance'] as num).toDouble()).abs() >
            .00001) {
          throw StateError(
            'El saldo de ${account['name']} no coincide con su historial. Conserva un respaldo para revisar.',
          );
        }
      }
    });
  }

  Future<void> addTransaction(TransactionRecord tx) => addTransactions([tx]);

  Future<void> addTransactions(List<TransactionRecord> transactions) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final tx in transactions) {
        await TransactionWriter.insert(txn, tx);
      }
    });
    notifyChanged();
  }

  Future<void> deleteTransaction(TransactionRecord record) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [record.id],
      );
      if (rows.isEmpty) return;
      final tx = TransactionRecord.fromMap(rows.first);
      await txn.insert('transaction_archive', {
        ...tx.toMap(),
        'voided_at': DateTime.now().toIso8601String(),
      });
      await txn.delete('transactions', where: 'id = ?', whereArgs: [tx.id]);

      if (tx.isNegative) {
        await txn.rawUpdate(
          'UPDATE accounts SET balance = ROUND(balance + ?, 8) WHERE id = ?',
          [tx.amount, tx.accountId],
        );
      } else if (tx.isPositive) {
        await txn.rawUpdate(
          'UPDATE accounts SET balance = ROUND(balance - ?, 8) WHERE id = ?',
          [tx.amount, tx.accountId],
        );
      } else if (tx.type == 'transfer' && tx.toAccountId != null) {
        await txn.rawUpdate(
          'UPDATE accounts SET balance = ROUND(balance + ?, 8) WHERE id = ?',
          [tx.amount, tx.accountId],
        );
        await txn.rawUpdate(
          'UPDATE accounts SET balance = ROUND(balance - ?, 8) WHERE id = ?',
          [tx.toAmount ?? tx.amount, tx.toAccountId],
        );
      }
    });
    notifyChanged();
  }
}
