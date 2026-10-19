import '../../../core/contracts/app_repositories.dart';
import '../../../core/mvvm/view_model.dart';
import '../../../core/services/device_files.dart';

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
    await repository.repairOrResetDatabase();
    await repository.importFullDataFromJson(content);
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

    await repository.saveSettings({...updates}..remove('welcome_seen'));

    final userDefinedCodes = <String>{};
    if (currency != null && currency.trim().isNotEmpty) {
      userDefinedCodes.add(currency.trim());
    }
    if (referenceCurrencies != null && referenceCurrencies.trim().isNotEmpty) {
      userDefinedCodes.addAll(
        referenceCurrencies
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty),
      );
    }
    if (userCurrencies != null) {
      userDefinedCodes.addAll(
        userCurrencies.keys.map((s) => s.trim()).where((s) => s.isNotEmpty),
      );
    }

    // The user defines all currencies; no others exist.
    // Clean up any initial default/pre-seeded currencies not chosen by the user.
    final existingCurrencies = await repository.getUserCurrencies();
    for (final existingCode in existingCurrencies.keys) {
      if (userDefinedCodes.isNotEmpty &&
          !userDefinedCodes.contains(existingCode)) {
        await repository.deleteUserCurrency(existingCode);
      }
    }

    if (userCurrencies != null && userCurrencies.isNotEmpty) {
      for (final entry in userCurrencies.entries) {
        final code = entry.key.trim();
        if (code.isNotEmpty) {
          await repository.saveUserCurrency(code, entry.value.trim());
        }
      }
    }
    if (currency != null && currency.trim().isNotEmpty) {
      await repository.saveUserCurrency(
        currency.trim(),
        currencyName?.trim() ?? '',
      );
    }
    if (referenceCurrencies != null && referenceCurrencies.trim().isNotEmpty) {
      for (final c in referenceCurrencies.split(',')) {
        final code = c.trim();
        if (code.isNotEmpty) {
          await repository.saveUserCurrency(
            code,
            userCurrencies?[code]?.trim() ?? '',
          );
        }
      }
    }
    await repository.saveSettings({'welcome_seen': '1'});
  });
}
