import 'package:knotes/core/database/currency_snapshot.dart';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:knotes/features/bodega/models/planned_expense.dart';
import 'package:knotes/features/bodega/models/quick_expense.dart';
import 'package:knotes/features/bodega/models/transaction_record.dart';
import 'package:knotes/core/database/transaction_writer.dart';
import 'package:knotes/core/database/database_context.dart';

mixin PlanningRepository on DatabaseContext {
  Future<void> payPlannedExpense(
    String id,
    String accountId, {
    required DateTime expectedDueDate,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'planned_expenses',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) throw StateError('El compromiso ya no existe');
      final plan = PlannedExpense.fromMap(rows.first);
      if (plan.isCompleted) return;
      if (plan.dueDate != expectedDueDate) {
        throw StateError('Este vencimiento ya fue registrado');
      }
      final now = DateTime.now();
      String? txId;
      double paidAmount = plan.amount;
      if (plan.amount > 0) {
        final sourceRows = plan.accountId == null
            ? <Map<String, Object?>>[]
            : await txn.query(
                'accounts',
                where: 'id = ?',
                whereArgs: [plan.accountId],
              );
        final targetRows = await txn.query(
          'accounts',
          where: 'id = ?',
          whereArgs: [accountId],
        );
        if (targetRows.isEmpty) throw StateError('Selecciona una cuenta');
        final snapshot = await CurrencySnapshot.read(txn);
        final sourceCurrency =
            sourceRows.firstOrNull?['currency'] as String? ?? snapshot.base;
        paidAmount = snapshot.convert(
          plan.amount,
          sourceCurrency,
          targetRows.single['currency'] as String,
        );
        txId = const Uuid().v4();
        await TransactionWriter.insert(
          txn,
          TransactionRecord(
            id: txId,
            accountId: accountId,
            categoryId: plan.categoryId,
            amount: paidAmount,
            type: 'expense',
            note: plan.title,
            date: now,
            createdAt: now,
          ),
        );
      }

      await txn.insert('planned_expense_payments', {
        'id': const Uuid().v4(),
        'planned_expense_id': id,
        'transaction_id': txId,
        'due_date': plan.dueDate.toIso8601String(),
        'paid_at': now.toIso8601String(),
        'amount': paidAmount,
        'account_id': accountId,
        'created_at': now.toIso8601String(),
      });

      final next = plan.nextDate(plan.dueDate);
      final updated = plan.copyWith(dueDate: next, isCompleted: next == null);
      await txn.update(
        'planned_expenses',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    notifyChanged();
  }

  Future<List<Map<String, dynamic>>> getPlannedExpensePayments({
    String? plannedExpenseId,
  }) async {
    final db = await database;
    return db.query(
      'planned_expense_payments',
      where: plannedExpenseId != null ? 'planned_expense_id = ?' : null,
      whereArgs: plannedExpenseId != null ? [plannedExpenseId] : null,
      orderBy: 'paid_at DESC',
    );
  }

  Future<List<PlannedExpense>> getPlannedExpenses({
    bool includeCompleted = true,
  }) async {
    final db = await database;
    final where = includeCompleted ? null : 'is_completed = 0';
    final maps = await db.query(
      'planned_expenses',
      where: where,
      orderBy: 'due_date ASC',
    );
    return maps.map((m) => PlannedExpense.fromMap(m)).toList();
  }

  Future<void> addPlannedExpense(PlannedExpense expense) async {
    final db = await database;
    await db.insert('planned_expenses', expense.toMap());
    notifyChanged();
  }

  Future<void> updatePlannedExpense(PlannedExpense expense) async {
    final db = await database;
    await db.update(
      'planned_expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
    notifyChanged();
  }

  Future<void> deletePlannedExpense(String id) async {
    final db = await database;
    await db.delete('planned_expenses', where: 'id = ?', whereArgs: [id]);
    notifyChanged();
  }

  Future<List<QuickExpense>> getQuickExpenses() async {
    final db = await database;
    final rows = await db.query('quick_expenses', orderBy: 'created_at ASC');
    return rows.map((r) => QuickExpense.fromMap(r)).toList();
  }

  Future<void> saveQuickExpense(QuickExpense expense) async {
    final db = await database;
    await db.insert(
      'quick_expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyChanged();
  }

  Future<void> deleteQuickExpense(String id) async {
    final db = await database;
    await db.delete('quick_expenses', where: 'id = ?', whereArgs: [id]);
    notifyChanged();
  }
}
