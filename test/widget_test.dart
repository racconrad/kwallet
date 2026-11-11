import 'package:flutter_test/flutter_test.dart';
import 'package:knotes/core/services/widget_sync_service.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/features/bodega/models/account.dart';
import 'package:knotes/features/bodega/models/planned_expense.dart';
import 'package:knotes/features/bodega/models/category_model.dart';

void main() {
  test('Account model serialization and currency format test', () {
    final now = DateTime.now();
    final acc = Account(
      id: 'acc_1',
      name: 'Bolsillo',
      type: 'cash',
      balance: 150.75,
      createdAt: now,
    );

    expect(acc.name, 'Bolsillo');
    expect(acc.balance, 150.75);
    expect(KnotesTheme.formatCurrency(acc.balance), '\$150.75');

    final map = acc.toMap();
    final restored = Account.fromMap(map);
    expect(restored.id, acc.id);
    expect(restored.balance, acc.balance);
  });

  test('PlannedExpense model serialization test', () {
    final now = DateTime.now();
    final expense = PlannedExpense(
      id: 'plan_1',
      title: 'Netflix',
      amount: 12.99,
      dueDate: now.add(const Duration(days: 10)),
      recurrence: 'monthly',
      categoryId: 'cat_bills',
      createdAt: now,
    );

    expect(expense.title, 'Netflix');
    expect(expense.recurrenceLabel, 'Mensual recurrente');
    expect(expense.daysRemaining, 10);

    final map = expense.toMap();
    final restored = PlannedExpense.fromMap(map);
    expect(restored.id, expense.id);
    expect(restored.amount, 12.99);
  });

  test('CategoryModel custom creation test', () {
    final cat = CategoryModel(
      id: 'custom_1',
      name: 'Gimnasio',
      type: 'expense',
      iconKey: 'potion',
      colorValue: 0xFF10B981,
      isDefault: false,
    );

    expect(cat.isDefault, false);
    final map = cat.toMap();
    final restored = CategoryModel.fromMap(map);
    expect(restored.name, 'Gimnasio');
  });

  test(
    'WidgetSyncService handles platform checks and calls gracefully',
    () async {
      final synced = await WidgetSyncService.syncWidget(
        petName: 'Mishi',
        xp: 150,
        completedHabits: 2,
        totalHabits: 3,
        pendingHabits: 1,
        petStyle: 'ginger',
        themePalette: 'plum',
      );
      // In unit test environment (running on host OS, not Android emulator), returns false gracefully
      expect(synced, isFalse);

      final route = await WidgetSyncService.getLaunchRoute();
      expect(route, isNull);
    },
  );
}
