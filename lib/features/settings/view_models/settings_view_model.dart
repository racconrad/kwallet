import 'package:knotes/core/contracts/app_repositories.dart';
import 'package:knotes/core/models/backup_preview.dart';
import 'package:knotes/core/models/recovery_copy.dart';
import 'package:knotes/core/mvvm/view_model.dart';
import 'package:knotes/core/services/device_files.dart';
import 'package:knotes/core/services/github_cloud_service.dart';

class SettingsViewModel extends ViewModel {
  final SettingsRepository repository;
  final DeviceFiles files;
  final GitHubCloudService cloud;
  Map<String, String> settings = const {};
  Map<String, double> rates = const {};
  Map<String, String> currencyNames = const {};
  List<RecoveryCopy> recoveries = const [];
  bool loading = true;
  bool _backupOperation = false;
  bool _githubBusy = false;
  bool get backupBusy => (busy && _backupOperation) || _githubBusy;
  bool get githubBusy => _githubBusy;
  bool get isGitHubConnected => settings['github_connected'] == 'true';
  String get githubUsername => settings['github_username'] ?? '';
  String get githubGistId => settings['github_gist_id'] ?? '';
  String get githubLastSync => settings['github_last_sync'] ?? '';
  String? _pendingRestore;

  SettingsViewModel(this.repository, this.files, [GitHubCloudService? cloud])
    : cloud = cloud ?? GitHubCloudService();
  Future<void> load() async {
    final request = beginRequest();
    try {
      final data = await repository.getSettings();
      final ratesData = await repository.getCurrencyRates();
      final userCurrencies = await repository.getUserCurrencies();
      if (!isCurrent(request)) return;
      settings = Map.unmodifiable(data);
      rates = Map.unmodifiable(ratesData);
      currencyNames = Map.unmodifiable(userCurrencies);
      loading = false;
      error = null;
      changed();
    } catch (_) {
      if (isCurrent(request)) {
        loading = false;
        fail('No se pudieron cargar tus ajustes.');
      }
    }
  }

  Future<void> _write(Map<String, String> values) async {
    await repository.saveSettings(values);
    if (!disposed) settings = Map.unmodifiable({...settings, ...values});
  }

  Future<bool> appearance(String key, String value) async {
    if (disposed) return false;
    settings = Map.unmodifiable({...settings, key: value});
    changed();
    try {
      await repository.saveSettings({key: value});
      return true;
    } catch (_) {
      if (!disposed) {
        error = 'No se pudo guardar la preferencia.';
        changed();
      }
      return false;
    }
  }

  Future<bool> save({
    required String currency,
    List<String>? referenceCurrencies,
    bool mirrorEnabled = false,
    String mirror = '',
    String rateText = '',
    required String petName,
  }) {
    final refCurrenciesStr =
        (referenceCurrencies != null && referenceCurrencies.isNotEmpty)
        ? referenceCurrencies
              .map((c) => c.trim())
              .where((c) => c.isNotEmpty)
              .join(',')
        : (mirrorEnabled && mirror.trim().isNotEmpty ? mirror.trim() : '');

    return perform(
      () => _write({
        if (currency.trim().isNotEmpty) 'currency': currency.trim(),
        'reference_currencies': refCurrenciesStr,
        'mirror_currency': '',
        'mirror_rate': '',
        'pet_name': petName.trim().isEmpty ? 'Mishi' : petName.trim(),
      }),
    );
  }

  Future<bool> setCurrencyRate({
    required String currency,
    required double rate,
    String notes = '',
  }) async {
    final ok = await perform(
      () => repository.setCurrencyRate(
        currency: currency,
        rate: rate,
        notes: notes,
      ),
      failure: 'No se pudo actualizar la tasa de cambio.',
    );
    if (ok) {
      rates = Map.unmodifiable(await repository.getCurrencyRates());
      currencyNames = Map.unmodifiable(await repository.getUserCurrencies());
      changed();
    }
    return ok;
  }

  Future<bool> removeCurrencyRate(String currency) async {
    final ok = await perform(
      () => repository.removeCurrencyRate(currency),
      failure: 'No se pudo eliminar la moneda.',
    );
    if (ok) {
      rates = Map.unmodifiable(await repository.getCurrencyRates());
      currencyNames = Map.unmodifiable(await repository.getUserCurrencies());
      changed();
    }
    return ok;
  }

  Future<bool> addUserCurrency(String symbol, [String name = '']) async {
    final cleanSymbol = symbol.trim();
    if (cleanSymbol.isEmpty) return false;
    final ok = await perform(
      () => repository.saveUserCurrency(cleanSymbol, name.trim()),
      failure: 'No se pudo guardar la moneda.',
    );
    if (ok) {
      currencyNames = Map.unmodifiable(await repository.getUserCurrencies());
      changed();
    }
    return ok;
  }

  Future<bool> deleteUserCurrency(String symbol) async {
    final ok = await perform(
      () => repository.deleteUserCurrency(symbol),
      failure: 'No se pudo eliminar la moneda.',
    );
    if (ok) {
      currencyNames = Map.unmodifiable(await repository.getUserCurrencies());
      rates = Map.unmodifiable(await repository.getCurrencyRates());
      changed();
    }
    return ok;
  }

  Future<List<Map<String, dynamic>>> getRateHistory(String currency) =>
      repository.getCurrencyRateHistory(currency: currency);

  Future<bool> _backup(
    Future<void> Function() action, {
    required String failure,
  }) async {
    if (busy) return false;
    _backupOperation = true;
    try {
      return await perform(action, failure: failure);
    } finally {
      _backupOperation = false;
    }
  }

  Future<bool> export() async {
    var saved = false;
    final ok = await _backup(() async {
      final content = await repository.exportFullDataAsJson();
      saved = await files.saveBackup(
        content,
        'knotes-${DateTime.now().toIso8601String().substring(0, 10)}.json',
      );
    }, failure: 'No se pudo guardar el respaldo. Reintenta.');
    return ok && saved;
  }

  Future<BackupPreview?> prepareRestore({String? recovery}) async {
    BackupPreview? preview;
    _pendingRestore = null;
    await _backup(() async {
      final content = recovery == null
          ? await files.pickBackup()
          : await repository.readRecoveryCopy(recovery);
      if (content == null) return;
      preview = BackupPreview.fromCounts(
        await repository.inspectBackup(content),
      );
      _pendingRestore = content;
    }, failure: 'No pudimos leer ese respaldo. Elige otro archivo.');
    return preview;
  }

  void discardRestore() {
    _pendingRestore = null;
  }

  Future<bool> restore() async {
    final content = _pendingRestore;
    if (content == null) return false;
    final restored = await _backup(
      () => repository.importFullDataFromJson(content),
      failure:
          'No pudimos restaurar el respaldo. Tus datos actuales se conservan.',
    );
    if (restored) {
      _pendingRestore = null;
      await load();
    }
    return restored;
  }

  Future<bool> connectGitHub(String token) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) {
      fail('Ingresa tu Personal Access Token de GitHub.');
      return false;
    }
    _githubBusy = true;
    error = null;
    changed();
    try {
      final user = await cloud.verifyToken(cleanToken);
      final existingGistId = await cloud.findBackupGist(cleanToken);
      await repository.saveGitHubToken(cleanToken);
      await _write({
        'github_connected': 'true',
        'github_username': user.login,
        'github_gist_id': existingGistId ?? '',
      });
      return true;
    } catch (_) {
      fail(
        'No pudimos validar tu token de GitHub. Revisa que tenga permiso "gist".',
      );
      return false;
    } finally {
      _githubBusy = false;
      changed();
    }
  }

  Future<bool> disconnectGitHub() async {
    _githubBusy = true;
    error = null;
    changed();
    try {
      await repository.saveGitHubToken(null);
      await _write({
        'github_connected': 'false',
        'github_username': '',
        'github_gist_id': '',
        'github_last_sync': '',
      });
      return true;
    } finally {
      _githubBusy = false;
      changed();
    }
  }

  Future<bool> syncToGitHub() async {
    final token = await repository.getGitHubToken();
    if (token == null || token.isEmpty) {
      fail('Conecta tu cuenta de GitHub antes de sincronizar.');
      return false;
    }
    _githubBusy = true;
    error = null;
    changed();
    try {
      final content = await repository.exportFullDataAsJson();
      final result = await cloud.syncBackup(
        token: token,
        backupJson: content,
        gistId: settings['github_gist_id'],
      );
      final nowFormatted = DateTime.now()
          .toIso8601String()
          .substring(0, 19)
          .replaceAll('T', ' ');
      await _write({
        'github_gist_id': result.gistId,
        'github_last_sync': nowFormatted,
      });
      return true;
    } catch (e) {
      fail('Error al sincronizar con GitHub. Reintenta.');
      return false;
    } finally {
      _githubBusy = false;
      changed();
    }
  }

  Future<BackupPreview?> prepareGitHubRestore() async {
    _pendingRestore = null;
    final token = await repository.getGitHubToken();
    final gistId = settings['github_gist_id'];
    if (token == null || token.isEmpty || gistId == null || gistId.isEmpty) {
      fail('No se encontró un respaldo vinculado en tu cuenta de GitHub.');
      return null;
    }
    _githubBusy = true;
    error = null;
    changed();
    try {
      final content = await cloud.fetchBackup(token: token, gistId: gistId);
      final preview = BackupPreview.fromCounts(
        await repository.inspectBackup(content),
      );
      _pendingRestore = content;
      return preview;
    } catch (_) {
      fail('No pudimos descargar el respaldo desde GitHub.');
      return null;
    } finally {
      _githubBusy = false;
      changed();
    }
  }

  Future<bool> loadRecoveries() => _backup(() async {
    final data = await repository.getRecoveryCopies();
    if (!disposed) recoveries = List.unmodifiable(data);
  }, failure: 'No se pudieron abrir las copias de recuperación.');
  Future<bool> choosePet(String style) async {
    if (disposed) return false;
    settings = Map.unmodifiable({
      ...settings,
      'pet_style': style,
      'pet_image': '',
    });
    changed();
    try {
      await repository.saveSettings({'pet_style': style, 'pet_image': ''});
      return true;
    } catch (_) {
      if (!disposed) {
        error = 'No se pudo guardar la mascota.';
        changed();
      }
      return false;
    }
  }

  Future<bool> uploadPet() async {
    var selected = false;
    final ok = await perform(
      () async {
        final data = await files.pickPetImage();
        if (data == null) return;
        await _write({
          'pet_style': 'custom',
          'pet_image_data': data,
          'pet_image': '',
        });
        selected = true;
      },
      failure: 'No pudimos abrir esa imagen. Usa una imagen fija de hasta 4 MB y 2048 × 2048.',
    );
    return ok && selected;
  }

  @override
  void dispose() {
    _pendingRestore = null;
    super.dispose();
  }
}
