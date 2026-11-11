import 'package:flutter/material.dart';

import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/core/mvvm/view_model_state.dart';
import 'package:knotes/core/models/currency_conversion.dart';
import 'package:knotes/features/settings/view_models/settings_view_model.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/core/widgets/kitty_companion.dart';
import 'package:knotes/core/widgets/pet_picker.dart';
import 'package:knotes/features/settings/presentation/github_cloud_screen.dart';
import 'package:knotes/features/settings/presentation/widgets/about_section.dart';
import 'package:knotes/features/settings/presentation/widgets/appearance_section.dart';
import 'package:knotes/features/settings/presentation/widgets/categories_settings_card.dart';
import 'package:knotes/features/settings/presentation/widgets/cloud_backup_section.dart';
import 'package:knotes/features/settings/presentation/widgets/general_settings_tile.dart';
import 'package:knotes/features/settings/presentation/widgets/notifications_settings_tile.dart';
import 'package:knotes/features/settings/presentation/widgets/streaks_settings_tile.dart';
import 'package:knotes/features/settings/presentation/widgets/currencies_settings_section.dart';

part 'settings_backup_actions.dart';

class SettingsScreen extends StatefulWidget {
  final String currentCurrency;
  final ValueChanged<String> onCurrencyChanged;
  final VoidCallback? onBack;
  const SettingsScreen({
    super.key,
    required this.currentCurrency,
    required this.onCurrencyChanged,
    this.onBack,
  });
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState
    extends ViewModelState<SettingsScreen, SettingsViewModel> {
  @override
  SettingsViewModel createViewModel(AppDependencies dependencies) =>
      dependencies.settingsScreen();
  final _currency = TextEditingController();
  final _petName = TextEditingController();
  List<String> _referenceCurrencies = [];
  Map<String, String> get _petSettings => model.settings;
  bool get _loading => model.loading;
  bool get _saving => model.busy;
  bool get _backupBusy => model.backupBusy;
  bool _fieldsReady = false;
  bool _justSaved = false;
  int _currencyRevision = 0;
  String? get _error => model.error;
  @override
  void onViewModelChanged() {
    if (!_fieldsReady && !model.loading) {
      _syncFields();
      _fieldsReady = true;
    }
  }

  void _syncFields() {
    _currency.text =
        model.settings['currency'] ??
        (model.currencyNames.isEmpty ? '' : widget.currentCurrency);
    final rawRefs = model.settings['reference_currencies'] ?? '';
    final parsedRefs = rawRefs
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    _referenceCurrencies = {
      ...parsedRefs,
      ...model.currencyNames.keys.where((k) => k != _currency.text.trim()),
    }.toList();
    _petName.text = model.settings['pet_name'] ?? 'Mishi';
  }

  @override
  void dispose() {
    for (final controller in [_currency, _petName]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveCurrencyRate(
    String currency,
    double rate,
    String notes,
  ) async {
    final ok = await model.setCurrencyRate(
      currency: currency,
      rate: rate,
      notes: notes,
    );
    if (!ok) throw StateError(model.error ?? 'No se pudo guardar la tasa');
    if (mounted) {
      if (!_referenceCurrencies.contains(currency)) {
        setState(() {
          _referenceCurrencies.add(currency);
        });
        await _save();
      }
    }
  }

  Future<void> _removeCurrency(String currency) async {
    if (!await model.deleteUserCurrency(currency)) return;
    if (mounted) {
      setState(() => _referenceCurrencies.remove(currency));
      await _save();
    }
  }

  Future<void> _changePrimary(String value) async {
    if (model.busy) return;
    final previous = _currency.text;
    final nextReferences =
        {..._referenceCurrencies, if (previous.isNotEmpty) previous}
            .where(
              (c) =>
                  CurrencyConversion.code(c) != CurrencyConversion.code(value),
            )
            .toList();
    final ok = await model.save(
      currency: value,
      referenceCurrencies: nextReferences,
      petName: _petName.text,
    );
    if (!mounted) return;
    setState(() => _currencyRevision++);
    if (ok) {
      setState(() {
        _currency.text = value;
        _referenceCurrencies = nextReferences;
      });
      widget.onCurrencyChanged(value);
      await model.load();
    } else {
      showFailure(
        context,
        model.error ?? 'Configura primero la tasa de cambio.',
      );
    }
  }

  Future<void> _appearance(String key, String value) =>
      model.appearance(key, value);
  Future<void> _save() async {
    final saved = await model.save(
      currency: _currency.text,
      referenceCurrencies: _referenceCurrencies,
      petName: _petName.text,
    );
    if (saved && mounted) {
      widget.onCurrencyChanged(_currency.text.trim());
      setState(() => _justSaved = true);
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      final iconColor = KnotesTheme.surface;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: iconColor, size: 20),
              const SizedBox(width: 10),
              const Text('Ajustes guardados correctamente'),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _justSaved = false);
      });
    }
  }

  // Lets the part-file extensions rebuild without touching protected setState.
  void _update(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        leading: widget.onBack != null
            ? IconButton(
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ContentWidth(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                children: [
                  Text(
                    'Hazlo tuyo',
                    style: KnotesTheme.fontTitle.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 16),
                  AppearanceSection(onChanged: _appearance),
                  const SizedBox(height: 12),
                  const Divider(height: 40),
                  CurrenciesSettingsSection(
                    key: ValueKey(_currencyRevision),
                    dominantCurrencyController: _currency,
                    onPrimaryChanged: _changePrimary,
                    referenceCurrencies: _referenceCurrencies,
                    rates: model.rates,
                    currencyNames: model.currencyNames,
                    onAddCurrency: (symbol, name) async {
                      if (!await model.addUserCurrency(symbol, name)) {
                        throw StateError('No se guardó la moneda');
                      }
                      if (_currency.text.isEmpty) {
                        await _changePrimary(symbol);
                        return;
                      }
                      if (!_referenceCurrencies.contains(symbol)) {
                        setState(() {
                          _referenceCurrencies.add(symbol);
                        });
                        await _save();
                      }
                    },
                    onSaveRate: _saveCurrencyRate,
                    onRemoveCurrency: _removeCurrency,
                    onFetchHistory: model.getRateHistory,
                  ),
                  const Divider(height: 40),
                  Text(
                    'Tu compañero',
                    style: KnotesTheme.fontTitle.copyWith(fontSize: 21),
                  ),
                  KittyCompanionWidget(size: 100, settings: _petSettings),
                  const SizedBox(height: 12),
                  PetPicker(
                    settings: _petSettings,
                    busy: model.busy,
                    onChoose: model.choosePet,
                    onUpload: model.uploadPet,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _petName,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  const SizedBox(height: 18),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(color: KnotesTheme.expenseRed),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: _justSaved
                        ? FilledButton.styleFrom(
                            backgroundColor: KnotesTheme.incomeGreen,
                            foregroundColor: Colors.white,
                          )
                        : null,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _justSaved
                                  ? Icons.check_circle_rounded
                                  : Icons.check,
                              key: ValueKey(_justSaved),
                            ),
                    ),
                    label: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        _saving
                            ? 'Guardando…'
                            : _justSaved
                            ? '¡Ajustes guardados!'
                            : 'Guardar ajustes',
                        key: ValueKey('$_saving-$_justSaved'),
                      ),
                    ),
                  ),
                  const Divider(height: 40),
                  Text(
                    'Categorías',
                    style: KnotesTheme.fontTitle.copyWith(fontSize: 21),
                  ),
                  const SizedBox(height: 8),
                  const CategoriesSettingsCard(),
                  const Divider(height: 40),
                  Text(
                    'Preferencias de la app',
                    style: KnotesTheme.fontTitle.copyWith(fontSize: 21),
                  ),
                  const SizedBox(height: 6),
                  GeneralSettingsTile(
                    settings: model.settings,
                    onChanged: (key, val) => _appearance(key, val),
                  ),
                  const SizedBox(height: 14),
                  NotificationsSettingsTile(
                    settings: model.settings,
                    onToggle: (key, val) => _appearance(key, val),
                  ),
                  const SizedBox(height: 14),
                  StreaksSettingsTile(
                    settings: model.settings,
                    onToggle: (key, val) => _appearance(key, val),
                  ),
                  const Divider(height: 40),
                  Text(
                    'Tus datos, a salvo',
                    style: KnotesTheme.fontTitle.copyWith(fontSize: 21),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Lleva una copia de todo contigo.',
                    style: TextStyle(color: KnotesTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: _backupBusy ? null : _export,
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text('Exportar respaldo'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _backupBusy ? null : _restore,
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Importar respaldo'),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 32),
                  CloudBackupSection(
                    connected: model.isGitHubConnected,
                    busy: _backupBusy,
                    username: model.githubUsername,
                    lastSync: model.githubLastSync,
                    onManage: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GitHubCloudScreen(model: model),
                      ),
                    ),
                    onConnect: _connectGitHubDialog,
                    onDisconnect: _disconnectGitHub,
                    onSync: _syncToGitHub,
                    onRestore: _restoreFromGitHub,
                  ),
                  if (_backupBusy)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: KittyCompanionWidget(
                          size: 64,
                          settings: _petSettings,
                          activity: PetActivity.run,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _backupBusy ? null : _recoveries,
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('Copias de recuperación locales'),
                  ),
                  const Divider(height: 48),
                  AboutSection(githubUsername: model.githubUsername),
                ],
              ),
            ),
    );
  }
}
