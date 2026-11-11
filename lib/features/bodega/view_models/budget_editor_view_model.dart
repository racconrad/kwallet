import 'package:knotes/core/contracts/app_repositories.dart';
import 'package:knotes/core/models/amount.dart';
import 'package:knotes/core/mvvm/view_model.dart';
import 'package:knotes/features/bodega/models/finance_overview.dart';

class BudgetEditorViewModel extends ViewModel {
  final FinanceRepository repository;
  BudgetEditorViewModel(this.repository);
  double previewAmount(String text) => parseAmount(text) ?? 0;
  Future<bool> save(
    BudgetPeriod period,
    String amountText,
    String mode,
    double share,
  ) {
    final amount = parseAmount(amountText);
    if (mode == 'assigned' && (amount == null || amount < 0)) {
      return Future.value(fail('Escribe un monto válido.'));
    }
    return perform(
      () => repository.allocateBudget(
        period,
        DateTime.now(),
        mode == 'assigned' ? amount : null,
        mode: mode,
        share: share,
      ),
    );
  }
}
