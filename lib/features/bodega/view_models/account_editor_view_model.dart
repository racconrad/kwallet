import 'package:uuid/uuid.dart';

import '../../../core/contracts/app_repositories.dart';
import '../../../core/models/amount.dart';
import '../../../core/mvvm/view_model.dart';
import '../models/account.dart';

class AccountEditorViewModel extends ViewModel {
  final FinanceRepository repository;
  final SettingsRepository? preferences;
  List<String> currencyOptions = const [];
  Map<String, String> currencyNames = const {};

  AccountEditorViewModel(this.repository, [this.preferences]);

  Future<void> loadCurrencies() async {
    if (preferences == null) return;
    try {
      final userCurrencies = await preferences!.getUserCurrencies();
      final settings = await preferences!.getSettings();
      if (disposed) return;
      currencyNames = Map.unmodifiable(userCurrencies);
      final mainCur = (settings['currency'] ?? '').trim();
      final refCurrencies = (settings['reference_currencies'] ?? '')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);
      currencyOptions = {
        if (mainCur.isNotEmpty) mainCur,
        ...refCurrencies,
        ...userCurrencies.keys,
      }.where((s) => s.trim().isNotEmpty).toList()..sort();
      changed();
    } catch (_) {
      fail('No se pudieron cargar las monedas');
    }
  }

  Future<bool> save({
    Account? original,
    required String name,
    required String balanceText,
    required String minimumText,
    required String type,
    required String currency,
    List<String>? currencies,
    required int color,
    String iconKey = 'wallet',
    String targetText = '0',
    bool? excludeFromAvailable,
  }) {
    final balance = parseAmount(balanceText);
    final minimum = parseAmount(minimumText);
    final target = parseAmount(targetText);
    if (name.trim().isEmpty ||
        balance == null ||
        minimum == null ||
        minimum < 0 ||
        target == null ||
        target < 0) {
      return Future.value(fail('Completa el nombre, saldo y mínimo válido.'));
    }
    final effectiveCurrencies = currencies != null && currencies.isNotEmpty
        ? (currencies.contains(currency)
              ? currencies
              : [currency, ...currencies])
        : [currency];

    final account =
        original?.copyWith(
          name: name.trim(),
          type: type,
          minimumBalance: minimum,
          savingsTarget: target,
          excludeFromAvailable: excludeFromAvailable,
          colorValue: color,
          iconKey: iconKey,
          currency: currency,
          currencies: effectiveCurrencies,
        ) ??
        Account(
          id: const Uuid().v4(),
          name: name.trim(),
          type: type,
          balance: balance,
          minimumBalance: minimum,
          currency: currency,
          currencies: effectiveCurrencies,
          colorValue: color,
          iconKey: iconKey,
          savingsTarget: target,
          excludeFromAvailable: excludeFromAvailable ?? false,
          createdAt: DateTime.now(),
        );
    return perform(
      () => original == null
          ? repository.createAccount(account)
          : repository.updateAccount(account),
    );
  }

  Future<bool> archive(Account account) => perform(
    () => repository.setAccountArchived(account.id, !account.isArchived),
  );
  Future<bool> delete(Account account) =>
      perform(() => repository.deleteAccount(account.id));
  Future<bool> adjust(Account account, String text, String reason) {
    final balance = parseAmount(text);
    if (balance == null || reason.trim().isEmpty) {
      return Future.value(
        fail('Indica un saldo válido y el motivo del ajuste.'),
      );
    }
    return perform(
      () => repository.adjustAccountBalance(
        account.id,
        balance,
        expectedBalance: account.balance,
        reason: reason,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> loadCurrencyHistory(String accountId) =>
      repository.getAccountCurrencyHistory(accountId);
}
