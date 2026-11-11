import 'package:uuid/uuid.dart';

import 'package:knotes/core/contracts/app_repositories.dart';
import 'package:knotes/core/models/amount.dart';
import 'package:knotes/core/mvvm/view_model.dart';
import 'package:knotes/features/bodega/models/planned_expense.dart';

class PlanEditorViewModel extends ViewModel {
  final FinanceRepository repository;
  PlanEditorViewModel(this.repository);
  Future<bool> save({
    PlannedExpense? original,
    required String title,
    required String amountText,
    required bool special,
    required DateTime date,
    required String recurrence,
    required String note,
    String? iconKey,
    String? categoryId,
    String? accountId,
  }) {
    final amount = special ? 0.0 : parseAmount(amountText);
    if (title.trim().isEmpty || amount == null || (!special && amount <= 0)) {
      return Future.value(fail('Escribe un título y un monto válido.'));
    }
    final sameDay =
        original != null &&
        original.dueDate.year == date.year &&
        original.dueDate.month == date.month &&
        original.dueDate.day == date.day;
    final plan = PlannedExpense(
      id: original?.id ?? const Uuid().v4(),
      title: title.trim(),
      amount: amount,
      dueDate: date,
      recurrence: recurrence,
      recurrenceDay: sameDay ? original.recurrenceDay : date.day,
      categoryId: categoryId ?? 'cat_other',
      accountId: accountId,
      note: note.trim(),
      iconKey: iconKey,
      createdAt: original?.createdAt ?? DateTime.now(),
    );
    return perform(
      () => original == null
          ? repository.addPlannedExpense(plan)
          : repository.updatePlannedExpense(plan),
    );
  }
}
