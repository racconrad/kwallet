import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../features/bodega/models/transaction_record.dart';
import 'reward_events.dart';
import 'currency_snapshot.dart';

class TransactionWriter {
  static Future<void> insert(Transaction txn, TransactionRecord tx) async {
    if (!tx.amount.isFinite || tx.amount <= 0) {
      throw ArgumentError('El monto debe ser mayor a cero');
    }
    if (![
      'expense',
      'income',
      'transfer',
      'adjustment_in',
      'adjustment_out',
    ].contains(tx.type)) {
      throw ArgumentError('Tipo de movimiento inválido');
    }
    final source = await txn.query(
      'accounts',
      where: 'id = ? AND is_archived = 0 AND is_deleted = 0',
      whereArgs: [tx.accountId],
    );
    if (source.isEmpty) throw StateError('La cuenta ya no está disponible');
    final sourceCurrency = source.single['currency'] as String;
    String? targetCurrency;
    double? targetAmount;
    double? exchangeRate;
    if (tx.type == 'transfer') {
      final target = await txn.query(
        'accounts',
        where: 'id = ? AND is_archived = 0 AND is_deleted = 0',
        whereArgs: [tx.toAccountId],
      );
      if (tx.accountId == tx.toAccountId || target.isEmpty) {
        throw ArgumentError('Selecciona otra cuenta de destino');
      }
      targetCurrency = target.single['currency'] as String;
      final snapshot = await CurrencySnapshot.read(txn);
      exchangeRate = snapshot.convert(1, sourceCurrency, targetCurrency);
      targetAmount = double.parse(
        (tx.amount * exchangeRate).toStringAsFixed(8),
      );
      if (!targetAmount.isFinite || targetAmount <= 0) {
        throw ArgumentError('Monto de destino inválido');
      }
    }
    await txn.insert('transactions', {
      ...tx.toMap(),
      'currency': sourceCurrency,
      'to_currency': targetCurrency,
      'to_amount': targetAmount,
      'exchange_rate': exchangeRate,
    });
    if (!tx.isAdjustment) {
      await RewardEvents.award(txn, 'transaction:${tx.id}', 5);
    }
    final delta = (tx.isIncome || tx.type == 'adjustment_in')
        ? tx.amount
        : -tx.amount;
    await txn.rawUpdate(
      'UPDATE accounts SET balance = ROUND(balance + ?, 8) WHERE id = ?',
      [delta, tx.accountId],
    );
    if (tx.type == 'transfer') {
      await txn.rawUpdate(
        'UPDATE accounts SET balance = ROUND(balance + ?, 8) WHERE id = ?',
        [targetAmount, tx.toAccountId],
      );
    }
  }
}
