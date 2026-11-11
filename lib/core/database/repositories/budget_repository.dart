import 'package:knotes/core/database/currency_snapshot.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:knotes/features/bodega/models/budget_model.dart';
import 'package:knotes/features/bodega/models/finance_overview.dart';
import 'package:knotes/features/journal/models/journal_models.dart';
import 'package:knotes/core/database/database_context.dart';

mixin BudgetRepository on DatabaseContext {
  Future<void> saveBudget({
    required double monthly,
    double? weekly,
    double? daily,
  }) async {
    final now = DateTime.now();
    await allocateBudget(BudgetPeriod.monthly, now, monthly);
    if (weekly != null) await allocateBudget(BudgetPeriod.weekly, now, weekly);
    if (daily != null) await allocateBudget(BudgetPeriod.daily, now, daily);
  }

  Future<double> getSpentBetween(DateTime start, DateTime end) async {
    final db = await database;
    return CurrencySnapshot.sum(
      db,
      "type = 'expense' AND date >= ? AND date < ?",
      [dayKey(start), dayKey(end)],
    );
  }

  Future<Map<BudgetPeriod, double>> getPeriodSpending(DateTime date) async {
    final result = <BudgetPeriod, double>{};
    for (final period in BudgetPeriod.values) {
      final range = periodRange(period, date);
      result[period] = await getSpentBetween(range.start, range.end);
    }
    return result;
  }

  Future<BudgetModel> getCurrentBudget() async {
    final db = await database;
    final now = DateTime.now();
    final monthlyStart = dayKey(periodRange(BudgetPeriod.monthly, now).start);
    final weeklyStart = dayKey(periodRange(BudgetPeriod.weekly, now).start);
    final dailyStart = dayKey(periodRange(BudgetPeriod.daily, now).start);

    final rows = await db.query(
      'budget_allocations',
      where: 'period_key IN (?, ?, ?)',
      whereArgs: [
        'monthly:$monthlyStart',
        'weekly:$weeklyStart',
        'daily:$dailyStart',
      ],
    );

    double monthly = 0;
    double? weekly;
    double? daily;
    for (final r in rows) {
      final period = r['period'] as String;
      final amt = (r['amount'] as num).toDouble();
      if (period == 'monthly') monthly = amt;
      if (period == 'weekly') weekly = amt;
      if (period == 'daily') daily = amt;
    }

    return BudgetModel(
      id: monthlyStart,
      month: now.month,
      year: now.year,
      monthlyLimit: monthly,
      weeklyLimit: weekly,
      dailyLimit: daily,
      createdAt: now,
    );
  }

  Future<void> setMonthlyBudget(double limit) =>
      allocateBudget(BudgetPeriod.monthly, DateTime.now(), limit);

  Future<double> getMonthlySpentTotal(int month, int year) async {
    final db = await database;
    return CurrencySnapshot.sum(
      db,
      "type = 'expense' AND date >= ? AND date < ?",
      [
        DateTime(year, month).toIso8601String(),
        DateTime(year, month + 1).toIso8601String(),
      ],
    );
  }

  Future<Map<BudgetPeriod, double>> getBudgetAllocations(DateTime date) async {
    final db = await database;
    final keys = {
      for (final period in BudgetPeriod.values)
        '${period.name}:${dayKey(periodRange(period, date).start)}': period,
    };
    final rows = await db.query(
      'budget_allocations',
      where: 'period_key IN (${List.filled(keys.length, '?').join(',')})',
      whereArgs: keys.keys.toList(),
    );
    return {
      for (final row in rows)
        keys[row['period_key']]!: (row['amount'] as num).toDouble(),
    };
  }

  Future<void> allocateBudget(
    BudgetPeriod period,
    DateTime date,
    double? amount, {
    String? mode,
    double? share,
    String notes = '',
  }) async {
    if (amount != null && (!amount.isFinite || amount < 0)) {
      throw ArgumentError('Monto inválido');
    }
    if (mode != null && !['assigned', 'available'].contains(mode)) {
      throw ArgumentError('Modo inválido');
    }
    if (share != null && (!share.isFinite || share < 1 || share > 100)) {
      throw ArgumentError('Porcentaje inválido');
    }
    final db = await database;
    final start = dayKey(periodRange(period, date).start);
    final key = '${period.name}:$start';
    final now = DateTime.now();

    await db.transaction((txn) async {
      final existing = await txn.query(
        'budget_allocations',
        where: 'period_key = ?',
        whereArgs: [key],
      );
      final prevAmount = existing.isNotEmpty
          ? (existing.first['amount'] as num).toDouble()
          : null;

      if (amount == null) {
        await txn.delete(
          'budget_allocations',
          where: 'period_key = ?',
          whereArgs: [key],
        );
        if (prevAmount != null) {
          await txn.insert('budget_allocation_history', {
            'id': const Uuid().v4(),
            'period_key': key,
            'period': period.name,
            'period_start': start,
            'previous_amount': prevAmount,
            'new_amount': 0.0,
            'change_type': 'cleared',
            'notes': notes,
            'created_at': now.toIso8601String(),
          });
        }
      } else {
        await txn.insert('budget_allocations', {
          'period_key': key,
          'period': period.name,
          'period_start': start,
          'amount': amount,
          'updated_at': now.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        final changeType = prevAmount == null ? 'created' : 'updated';
        await txn.insert('budget_allocation_history', {
          'id': const Uuid().v4(),
          'period_key': key,
          'period': period.name,
          'period_start': start,
          'previous_amount': prevAmount,
          'new_amount': amount,
          'change_type': changeType,
          'notes': notes,
          'created_at': now.toIso8601String(),
        });
      }

      final settings = <String, String>{
        'budget_mode': ?mode,
        'budget_share': ?share?.toString(),
      };
      for (final entry in settings.entries) {
        await txn.insert('app_settings', {
          'key': entry.key,
          'value': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    notifyChanged();
  }

  Future<List<Map<String, dynamic>>> getBudgetAllocationHistory({
    String? periodKey,
    BudgetPeriod? period,
  }) async {
    final db = await database;
    String? where;
    List<Object?>? args;
    if (periodKey != null) {
      where = 'period_key = ?';
      args = [periodKey];
    } else if (period != null) {
      where = 'period = ?';
      args = [period.name];
    }
    return db.query(
      'budget_allocation_history',
      where: where,
      whereArgs: args,
      orderBy: 'created_at DESC',
    );
  }
}
