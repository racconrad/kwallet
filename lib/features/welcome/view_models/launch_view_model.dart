import 'package:knotes/features/bodega/models/account.dart';
import 'package:knotes/features/bodega/models/category_model.dart';
import 'package:knotes/features/bodega/models/quick_expense.dart';
import 'package:knotes/features/journal/models/journal_models.dart';

import 'package:knotes/core/contracts/app_repositories.dart';
import 'package:knotes/core/mvvm/view_model.dart';
import 'package:knotes/core/services/device_files.dart';

class LaunchViewModel extends ViewModel {
  final SettingsRepository repository;
  final DeviceFiles? files;
  Map<String, String> settings = const {};
  Map<String, String> userCurrencies = const {};
  bool ready = false;
  bool returning = false;
  bool hasRecovery = false;
  String? diagnosticInfo;

  LaunchViewModel(this.repository, {this.files});

  Future<void> load() async {
    final request = beginRequest();
    error = null;
    diagnosticInfo = null;
    changed();
    try {
      final data = await repository.getSettings();
      final userCurs = await repository.getUserCurrencies();
      if (!isCurrent(request)) return;
      settings = Map.unmodifiable(data);
      userCurrencies = Map.unmodifiable(userCurs);
      ready = true;
      returning = data['welcome_seen'] == '1';
      changed();
    } catch (e) {
      if (isCurrent(request)) {
        diagnosticInfo = e.toString();
        try {
          hasRecovery = await repository.hasRecoveryCopies();
        } catch (_) {
          hasRecovery = false;
        }
        final isCompatibilityError =
            diagnosticInfo?.contains('no es compatible') == true;
        fail(
          isCompatibilityError
              ? 'Esta base de datos no es compatible y no se puede restaurar automáticamente.'
              : 'No pudimos abrir tus datos.',
        );
      }
    }
  }

  Future<bool> restoreRecovery() => perform(() async {
    final ok = await repository.restoreLatestRecoveryCopy();
    if (!ok) throw StateError('No hay copia disponible para restaurar.');
    await load();
  });

  Future<bool> repairDatabase() => perform(() async {
    await repository.repairOrResetDatabase();
    await load();
  });

  Future<bool> createNewVault() => repairDatabase();

  Future<bool> importBackup() => perform(() async {
    final picker = files ?? NativeDeviceFiles();
    final content = await picker.pickBackup();
    if (content == null || content.trim().isEmpty) return;
    await repository.importRecoveryBackup(content);
    await load();
  });

  Future<bool> enter({
    String? petStyle,
    String? petName,
    String? currency,
    String? currencyName,
    String? referenceCurrencies,
    Map<String, String>? userCurrencies,
    bool notificationsEnabled = false,
    Account? account,
    List<QuickExpense> quickExpenses = const [],
    List<CategoryModel> categories = const [],
    Map<String, String> habits = const {},
    String? habitReminderTime,
    List<PersonalNote> notes = const [],
  }) => perform(() async {
    final updates = <String, String>{
      'welcome_seen': '1',
      'notifications_enabled': notificationsEnabled ? 'true' : 'false',
    };
    if (petStyle != null && petStyle.isNotEmpty) {
      updates['pet_style'] = petStyle;
    }
    if (petName != null && petName.trim().isNotEmpty) {
      updates['pet_name'] = petName.trim();
    }
    if (currency != null && currency.trim().isNotEmpty) {
      updates['currency'] = currency.trim();
    }
    if (referenceCurrencies != null && referenceCurrencies.trim().isNotEmpty) {
      updates['reference_currencies'] = referenceCurrencies.trim();
    }

    final currencies = {...?userCurrencies};
    if (currency != null && currency.trim().isNotEmpty) {
      currencies[currency.trim()] =
          currencyName?.trim() ?? currencies[currency.trim()] ?? '';
    }
    for (final c
        in (referenceCurrencies ?? '')
            .split(',')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)) {
      currencies.putIfAbsent(c, () => '');
    }
    await repository.finishWelcome(
      settings: updates,
      currencies: currencies,
      account: account,
      categories: categories,
      quickExpenses: quickExpenses,
      habits: habits,
      habitReminderTime: habitReminderTime,
      notes: notes,
    );
  });
}
