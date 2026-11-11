import 'dart:math' as math;

import 'package:knotes/features/bodega/models/budget_model.dart';
import 'package:knotes/features/bodega/models/planned_expense.dart';

enum BudgetPeriod { daily, weekly, monthly }

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

({DateTime start, DateTime end}) periodRange(
  BudgetPeriod period,
  DateTime now,
) {
  final today = dateOnly(now);
  final start = switch (period) {
    BudgetPeriod.daily => today,
    BudgetPeriod.weekly => DateTime(
      now.year,
      now.month,
      now.day - now.weekday + 1,
    ),
    BudgetPeriod.monthly => DateTime(now.year, now.month),
  };
  final end = switch (period) {
    BudgetPeriod.daily => DateTime(start.year, start.month, start.day + 1),
    BudgetPeriod.weekly => DateTime(start.year, start.month, start.day + 7),
    BudgetPeriod.monthly => DateTime(start.year, start.month + 1),
  };
  return (start: start, end: end);
}

double budgetLimit(BudgetModel budget, BudgetPeriod period) {
  final days = DateTime(budget.year, budget.month + 1, 0).day;
  return switch (period) {
    BudgetPeriod.daily => budget.dailyLimit ?? budget.monthlyLimit / days,
    BudgetPeriod.weekly => budget.weeklyLimit ?? budget.monthlyLimit * 7 / days,
    BudgetPeriod.monthly => budget.monthlyLimit,
  };
}

double plannedTotal(
  List<PlannedExpense> plans,
  DateTime start,
  DateTime end, {
  bool includeOverdue = false,
}) {
  return plans.fold(
    0.0,
    (sum, plan) =>
        sum +
        plan.amount *
            plan
                .datesBetween(start, end, includeOverdue: includeOverdue)
                .length,
  );
}

double flexibleBudget({
  required double spent,
  required double balance,
  required double reserves,
  required double commitments,
  required double share,
}) => spent + math.max(0, balance - reserves - commitments) * share / 100;
