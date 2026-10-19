import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kwall/core/contracts/app_repositories.dart';
import 'package:kwall/core/models/recovery_copy.dart';
import 'package:kwall/core/services/device_files.dart';
import 'package:kwall/features/welcome/view_models/launch_view_model.dart';

class FakeSettingsRepository implements SettingsRepository {
  String? _token;
  @override
  Future<String?> getGitHubToken() async => _token;
  @override
  Future<void> saveGitHubToken(String? token) async {
    _token = token;
  }

  final Map<String, String> data = {};
  final ValueNotifier<int> _changes = ValueNotifier<int>(0);
  @override
  Listenable get changes => _changes;

  @override
  Future<Map<String, String>> getSettings() async => Map.from(data);

  @override
  Future<void> saveSettings(Map<String, String> values) async {
    data.addAll(values);
    _changes.value++;
  }

  @override
  Future<String> exportFullDataAsJson() async => '{}';

  @override
  Future<Map<String, int>> inspectBackup(String content) async => {};

  @override
  Future<void> importFullDataFromJson(String content) async {}

  @override
  Future<List<RecoveryCopy>> getRecoveryCopies() async => [];

  @override
  Future<String> readRecoveryCopy(String id) async => '{}';

  @override
  Future<Map<String, double>> getCurrencyRates() async => {};

  @override
  Future<void> setCurrencyRate({
    required String currency,
    required double rate,
    String notes = '',
  }) async {}

  @override
  Future<void> removeCurrencyRate(String currency) async {}

  final Map<String, String> userCurrencies = {};

  @override
  Future<List<Map<String, dynamic>>> getCurrencyRateHistory({
    String? currency,
  }) async => [];

  @override
  Future<Map<String, String>> getUserCurrencies() async =>
      Map.from(userCurrencies);

  @override
  Future<void> saveUserCurrency(String code, [String name = '']) async {
    userCurrencies[code] = name;
  }

  @override
  Future<void> deleteUserCurrency(String code) async {
    userCurrencies.remove(code);
  }

  @override
  Future<bool> hasRecoveryCopies() async => false;

  @override
  Future<bool> restoreLatestRecoveryCopy() async => true;

  @override
  Future<void> repairOrResetDatabase() async {}

  @override
  Future<String> checkDatabaseIntegrity() async => 'ok';
}

void main() {
  group('LaunchViewModel Start Flow Tests', () {
    test('enter saves selected petStyle, petName, currency, and referenceCurrencies', () async {
      final repo = FakeSettingsRepository();
      final vm = LaunchViewModel(repo);

      await vm.load();
      expect(vm.returning, false);

      final entered = await vm.enter(
        petStyle: 'calico',
        petName: 'Manchitas',
        currency: 'USD',
        currencyName: 'Dólar',
        referenceCurrencies: 'EUR,NIO',
        userCurrencies: {'USD': 'Dólar', 'EUR': 'Euro', 'NIO': 'Córdoba'},
        notificationsEnabled: true,
      );
      expect(entered, true);
      expect(repo.data['welcome_seen'], '1');
      expect(repo.data['notifications_enabled'], 'true');
      expect(repo.data['pet_style'], 'calico');
      expect(repo.data['pet_name'], 'Manchitas');
      expect(repo.data['currency'], 'USD');
      expect(repo.data['reference_currencies'], 'EUR,NIO');
      expect(repo.userCurrencies['USD'], 'Dólar');
      expect(repo.userCurrencies['EUR'], 'Euro');
      expect(repo.userCurrencies['NIO'], 'Córdoba');
    });

    test('enter defaults gracefully when parameters are omitted', () async {
      final repo = FakeSettingsRepository();
      final vm = LaunchViewModel(repo);

      await vm.load();
      final entered = await vm.enter();
      expect(entered, true);
      expect(repo.data['welcome_seen'], '1');
      expect(repo.data['notifications_enabled'], 'false');
    });

    test(
      'failed currency save leaves welcome unfinished so the user can retry',
      () async {
        final repo = CurrencySaveFailingRepository();
        final vm = LaunchViewModel(repo);
        await vm.load();
        expect(
          await vm.enter(
            petStyle: 'classic',
            petName: 'Mishi',
            currency: 'NIO',
            userCurrencies: {'NIO': 'Córdoba'},
          ),
          isFalse,
        );
        expect(repo.data['welcome_seen'], isNull);
        expect(vm.returning, isFalse);
      },
    );

    test(
      'load failure sets error, diagnosticInfo, and checks recovery copies',
      () async {
        final repo = FailingSettingsRepository();
        final vm = LaunchViewModel(repo);

        await vm.load();
        expect(vm.ready, isFalse);
        expect(vm.error, 'No pudimos abrir tus datos.');
        expect(vm.diagnosticInfo, contains('Simulated database disk failure'));
        expect(vm.hasRecovery, isTrue);
      },
    );

    test(
      'restoreRecovery calls repository.restoreLatestRecoveryCopy and reloads',
      () async {
        final repo = RecoverableSettingsRepository();
        final vm = LaunchViewModel(repo);

        await vm.load();
        expect(vm.ready, isFalse);

        final restored = await vm.restoreRecovery();
        expect(restored, isTrue);
        expect(vm.ready, isTrue);
        expect(repo.restoredCalled, isTrue);
      },
    );

    test(
      'repairDatabase calls repository.repairOrResetDatabase and reloads',
      () async {
        final repo = RecoverableSettingsRepository();
        final vm = LaunchViewModel(repo);

        await vm.load();
        expect(vm.ready, isFalse);

        final repaired = await vm.repairDatabase();
        expect(repaired, isTrue);
        expect(vm.ready, isTrue);
        expect(repo.repairCalled, isTrue);
      },
    );

    test('load failure sets specific warning when database version is incompatible', () async {
      final repo = IncompatibleSettingsRepository();
      final vm = LaunchViewModel(repo);

      await vm.load();
      expect(vm.ready, isFalse);
      expect(
        vm.error,
        'Esta base de datos no es compatible y no se puede restaurar automáticamente.',
      );
      expect(
        vm.diagnosticInfo,
        contains('no es compatible con tu versión actual de kwall'),
      );
    });

    test(
      'createNewVault calls repository.repairOrResetDatabase and reloads',
      () async {
        final repo = RecoverableSettingsRepository();
        final vm = LaunchViewModel(repo);

        await vm.load();
        expect(vm.ready, isFalse);

        final created = await vm.createNewVault();
        expect(created, isTrue);
        expect(vm.ready, isTrue);
        expect(repo.repairCalled, isTrue);
      },
    );

    test(
      'importBackup picks backup file, resets vault, imports data and reloads',
      () async {
        final repo = RecoverableSettingsRepository();
        final fakeFiles = FakeDeviceFiles(backupContent: '{"app":"kwall"}');
        final vm = LaunchViewModel(repo, files: fakeFiles);

        await vm.load();
        expect(vm.ready, isFalse);

        final imported = await vm.importBackup();
        expect(imported, isTrue);
        expect(vm.ready, isTrue);
        expect(repo.repairCalled, isTrue);
        expect(repo.importedContent, '{"app":"kwall"}');
      },
    );
  });
}

class IncompatibleSettingsRepository extends FakeSettingsRepository {
  @override
  Future<Map<String, String>> getSettings() async {
    throw StateError(
      'Esta base de datos (v99) no es compatible con tu versión actual de kwall (v6). No se puede restaurar automáticamente.',
    );
  }
}

class FakeDeviceFiles implements DeviceFiles {
  final String? backupContent;
  FakeDeviceFiles({this.backupContent});

  @override
  Future<String?> pickBackup() async => backupContent;

  @override
  Future<String?> pickPetImage() async => null;

  @override
  Future<bool> saveBackup(String content, String name) async => true;
}

class FailingSettingsRepository extends FakeSettingsRepository {
  @override
  Future<Map<String, String>> getSettings() async {
    throw StateError('Simulated database disk failure');
  }

  @override
  Future<bool> hasRecoveryCopies() async => true;
}

class RecoverableSettingsRepository extends FakeSettingsRepository {
  bool failNext = true;
  bool restoredCalled = false;
  bool repairCalled = false;
  String? importedContent;

  @override
  Future<void> importFullDataFromJson(String content) async {
    importedContent = content;
  }

  @override
  Future<Map<String, String>> getSettings() async {
    if (failNext) {
      throw StateError('Database opening failed');
    }
    return {'welcome_seen': '1'};
  }

  @override
  Future<bool> hasRecoveryCopies() async => true;

  @override
  Future<bool> restoreLatestRecoveryCopy() async {
    restoredCalled = true;
    failNext = false;
    return true;
  }

  @override
  Future<void> repairOrResetDatabase() async {
    repairCalled = true;
    failNext = false;
  }
}

class CurrencySaveFailingRepository extends FakeSettingsRepository {
  @override
  Future<void> saveUserCurrency(String code, [String name = '']) async {
    throw StateError('No se pudo guardar la moneda');
  }
}
