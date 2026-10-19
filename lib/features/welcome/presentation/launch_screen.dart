import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/models/currency_conversion.dart';
import '../../../core/models/pet_species.dart';
import '../../../core/mvvm/view_model_state.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/kwall_theme.dart';
import '../../../core/widgets/currency_selector.dart';
import '../../../core/widgets/finance_widgets.dart';
import '../../../core/widgets/kitty_companion.dart';
import '../../../core/widgets/pet_loading_screen.dart';
import '../../bodega/presentation/bodega_screen.dart';
import '../view_models/launch_view_model.dart';
import 'widgets/adoption_picker.dart';
import 'widgets/adoption_scene.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});
  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends ViewModelState<LaunchScreen, LaunchViewModel> {
  @override
  LaunchViewModel createViewModel(AppDependencies dependencies) =>
      dependencies.launch();
  final _pages = PageController();
  final _petName = TextEditingController(text: 'Mishi');
  String _currency = '\$';
  final Map<String, String> _currencies = {};
  final Set<String> _references = {};
  String _style = 'classic';
  int _step = 0;
  bool _initialized = false;
  bool _notifications = false;
  bool _requestingPermission = false;
  bool _greeted = false;
  bool _entered = false;
  String get _name => _petName.text.trim().isEmpty
      ? PetSpeciesCatalog.get(_style).name
      : _petName.text.trim();
  Map<String, String> get _petSettings => {
    ...model.settings,
    'pet_style': _style,
    'pet_name': _name,
  };
  @override
  void initState() {
    super.initState();
    for (final asset
        in PetSpeciesCatalog.styles.values
            .map((s) => PetSpeciesCatalog.resolveAsset(s.key))
            .toSet()) {
      KittyCompanionWidget.loadAtlas(asset).ignore();
    }
  }

  @override
  void onViewModelChanged() {
    if (!_initialized && model.ready) {
      _currencies.addAll(model.userCurrencies);
      _style = model.settings['pet_style'] ?? 'classic';
      _petName.text =
          model.settings['pet_name'] ?? PetSpeciesCatalog.get(_style).name;
      _currency = model.settings['currency'] ?? '\$';
      _references.addAll(
        (model.settings['reference_currencies'] ?? '')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty),
      );
      _notifications = model.settings['notifications_enabled'] == 'true';
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _petName.dispose();
    super.dispose();
  }

  void _go(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.selectionClick();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(step);
    } else {
      _pages.animateToPage(
        step,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _choose(String style) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_petName.text.trim().isEmpty ||
          _petName.text == PetSpeciesCatalog.get(_style).name) {
        _petName.text = PetSpeciesCatalog.get(style).name;
      }
      _style = style;
      _greeted = false;
    });
  }

  void _randomName() {
    final options = switch (PetSpeciesCatalog.get(_style).species) {
      PetSpecies.cat => ['Mishi', 'Kuro', 'Copito', 'Simba'],
      PetSpecies.rat => ['Mimi', 'Quesito', 'Pixie', 'Remi'],
      PetSpecies.raccoon => ['Pillo', 'Bandit', 'Rocket', 'Mapi'],
      PetSpecies.opossum => ['Pepita', 'Luna', 'Nube', 'Pipa'],
      PetSpecies.rock => ['Roco', 'Piedrito', 'Coco', 'Rufi'],
      PetSpecies.plant => ['Brotito', 'Oliva', 'Hoja', 'Trébol'],
    };
    setState(
      () => _petName.text =
          (options.where((n) => n != _name).toList()..shuffle(math.Random()))
              .first,
    );
  }

  Future<void> _enter() async {
    if (model.busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final references = _references
        .where(
          (c) =>
              CurrencyConversion.code(c) != CurrencyConversion.code(_currency),
        )
        .toSet();
    final selected = {_currency, ...references};
    String nameFor(String code) =>
        _currencies.entries
            .where(
              (e) =>
                  CurrencyConversion.code(e.key) ==
                  CurrencyConversion.code(code),
            )
            .firstOrNull
            ?.value ??
        '';
    final ok = await model.enter(
      petStyle: _style,
      petName: _name,
      currency: _currency,
      currencyName: nameFor(_currency),
      referenceCurrencies: references.join(','),
      userCurrencies: {for (final c in selected) c: nameFor(c)},
      notificationsEnabled: _notifications,
    );
    if (ok && mounted) {
      HapticFeedback.mediumImpact();
      setState(() => _entered = true);
    } else if (mounted) {
      showFailure(context, 'No se pudo guardar. Inténtalo otra vez.');
    }
  }

  Future<void> _permission(bool enabled) async {
    if (!enabled) {
      setState(() => _notifications = false);
      return;
    }
    setState(() => _requestingPermission = true);
    final granted = await NotificationService.requestNotificationPermission();
    if (!mounted) return;
    setState(() {
      _notifications = granted;
      _requestingPermission = false;
    });
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Puedes activarlos después.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_entered || model.returning) return const BodegaScreen();
    if (!model.ready) {
      return PetLoadingScreen(
        settings: model.settings,
        failed: model.error != null,
        errorMessage: model.error,
        hasRecovery: model.hasRecovery,
        onRestoreRecovery: model.restoreRecovery,
        onRepairDatabase: model.repairDatabase,
        onImportBackup: model.importBackup,
        diagnosticInfo: model.diagnosticInfo,
      );
    }
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !model.busy) _go(_step - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ContentWidth(
              width: 560,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: _step == 0
                              ? null
                              : IconButton(
                                  tooltip: 'Atrás',
                                  onPressed: model.busy
                                      ? null
                                      : () => _go(_step - 1),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                ),
                        ),
                        Expanded(
                          child: Center(
                            child: Semantics(
                              label: 'Paso ${_step + 1} de 5',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0; i < 5; i++)
                                    AnimatedContainer(
                                      duration:
                                          MediaQuery.disableAnimationsOf(
                                            context,
                                          )
                                          ? Duration.zero
                                          : const Duration(milliseconds: 240),
                                      width: i == _step ? 24 : 6,
                                      height: 6,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: i <= _step
                                            ? KwallTheme.accent
                                            : KwallTheme.border.withValues(
                                                alpha: .3,
                                              ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 48,
                          child: Icon(Icons.pets_outlined, size: 22),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      physics: model.busy
                          ? const NeverScrollableScrollPhysics()
                          : const PageScrollPhysics(),
                      onPageChanged: (step) => setState(() => _step = step),
                      children: [
                        _page(
                          children: [
                            const SizedBox(height: 16),
                            _title('Hay alguien\nesperándote.'),
                            const SizedBox(height: 10),
                            _caption('Un pequeño compañero para tus días.'),
                            const SizedBox(height: 28),
                            AdoptionScene(
                              settings: _petSettings,
                              arriving: true,
                            ),
                            const SizedBox(height: 24),
                            _caption('Crezcan juntos, un día a la vez.'),
                          ],
                        ),
                        _page(
                          children: [
                            _title('¿Quién va contigo?'),
                            const SizedBox(height: 8),
                            _caption('Elige a tu compañero.'),
                            AdoptionScene(
                              settings: _petSettings,
                              activity: PetActivity.curious,
                            ),
                            AdoptionPicker(
                              selected: _style,
                              onChanged: _choose,
                            ),
                          ],
                        ),
                        _page(
                          children: [
                            _title('Un nombre.\nUn nuevo amigo.'),
                            AdoptionScene(
                              settings: _petSettings,
                              greeted: _greeted,
                              onGreet: () => setState(() => _greeted = true),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: Text(
                                _greeted
                                    ? 'Ya te reconoce.'
                                    : 'Tócalo para saludar.',
                                key: ValueKey(_greeted),
                                style: TextStyle(color: KwallTheme.accent),
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextField(
                              controller: _petName,
                              maxLength: 20,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.done,
                              textAlign: TextAlign.center,
                              style: KwallTheme.fontTitle.copyWith(
                                fontSize: 22,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Su nombre',
                                counterText: '',
                                suffixIcon: IconButton(
                                  tooltip: 'Sugerir un nombre',
                                  onPressed: _randomName,
                                  icon: const Icon(Icons.casino_outlined),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            _caption('Puedes cambiarlo cuando quieras.'),
                          ],
                        ),
                        _page(
                          children: [
                            _title('Tus días,\na tu manera.'),
                            const SizedBox(height: 22),
                            _dailyIcons(),
                            const SizedBox(height: 24),
                            CurrencySelector(
                              value: _currency,
                              options: {
                                _currency,
                                ..._currencies.keys,
                                '\$',
                                'C\$',
                                '€',
                                '£',
                                'L',
                                'Q',
                                '₡',
                              },
                              currencyNames: _currencies,
                              label: 'Tu moneda',
                              onChanged: (value) =>
                                  setState(() => _currency = value),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.center,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _addCurrency(primary: true),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Otra moneda'),
                                ),
                                TextButton.icon(
                                  onPressed: () => _addCurrency(primary: false),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('Uso otra también'),
                                ),
                              ],
                            ),
                            if (_references.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final c in _references)
                                    InputChip(
                                      label: Text(
                                        CurrencyConversion.label(
                                          c,
                                          _currencies,
                                        ),
                                      ),
                                      onDeleted: () =>
                                          setState(() => _references.remove(c)),
                                    ),
                                ],
                              ),
                            const SizedBox(height: 16),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              secondary: const Icon(
                                Icons.notifications_none_rounded,
                              ),
                              title: const Text('Un pequeño recordatorio'),
                              subtitle: const Text('Si tú quieres.'),
                              value: _notifications,
                              onChanged: _requestingPermission
                                  ? null
                                  : _permission,
                            ),
                            const SizedBox(height: 16),
                            _caption('Lo demás puede esperar.'),
                          ],
                        ),
                        _page(
                          children: [
                            _title('Bienvenido a casa,\n$_name.'),
                            const SizedBox(height: 8),
                            _caption('Juntos, desde hoy.'),
                            AdoptionScene(
                              settings: _petSettings,
                              activity: PetActivity.celebrate,
                              greeted: true,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.favorite_border_rounded,
                                  size: 20,
                                  color: KwallTheme.accent,
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    'Tus pequeños pasos le ayudarán a crecer.',
                                    style: TextStyle(
                                      color: KwallTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.phonelink_lock_rounded,
                                  size: 18,
                                  color: KwallTheme.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Guardado en tu teléfono.',
                                    style: TextStyle(
                                      color: KwallTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (model.error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'No se pudo guardar. Vuelve a intentarlo.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: KwallTheme.expenseRed),
                            ),
                          ),
                        FilledButton.icon(
                          onPressed: model.busy
                              ? null
                              : _step == 4
                              ? _enter
                              : () => _go(_step + 1),
                          icon: model.busy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _step == 4
                                      ? Icons.favorite_border_rounded
                                      : Icons.arrow_forward_rounded,
                                ),
                          label: Text(
                            model.busy
                                ? 'Un momento…'
                                : switch (_step) {
                                    0 => 'Quiero conocerle',
                                    1 => 'Este va conmigo',
                                    2 => 'Me gusta su nombre',
                                    3 => 'Todo listo',
                                    _ => 'Empezar juntos',
                                  },
                          ),
                        ),
                        if (_step == 0)
                          TextButton(
                            onPressed: model.busy ? null : model.importBackup,
                            child: const Text('Traer mis datos'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _page({required List<Widget> children}) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: math.max(0, constraints.maxHeight - 32),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
  Widget _title(String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: KwallTheme.fontDisplay.copyWith(fontSize: 32, height: 1.16),
  );
  Widget _caption(String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: TextStyle(color: KwallTheme.textSecondary, height: 1.4),
  );
  Widget _dailyIcons() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      for (final item in [
        (Icons.account_balance_wallet_outlined, 'Dinero'),
        (Icons.edit_note_rounded, 'Notas'),
        (Icons.spa_outlined, 'Hábitos'),
      ])
        Expanded(
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: KwallTheme.accentLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(item.$1, size: 28, color: KwallTheme.accent),
              ),
              const SizedBox(height: 8),
              Text(item.$2, textAlign: TextAlign.center),
            ],
          ),
        ),
    ],
  );
  Future<void> _addCurrency({required bool primary}) async {
    final symbol = TextEditingController();
    final name = TextEditingController();
    String? error;
    final value = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => SheetBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                primary ? 'Tu moneda' : 'Otra moneda',
                style: KwallTheme.fontTitle.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: symbol,
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: 'Símbolo',
                  hintText: 'C\$, €, L…',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Córdoba, Euro…',
                ),
              ),
              const SizedBox(height: 16),
              if (error != null)
                Text(error!, style: TextStyle(color: KwallTheme.expenseRed)),
              FilledButton(
                onPressed: () {
                  final code = symbol.text.trim();
                  if (code.isEmpty || code.contains(',')) {
                    update(() => error = 'Escribe un símbolo.');
                    return;
                  }
                  Navigator.pop(ctx, (code, name.text.trim()));
                },
                child: const Text('Usar esta moneda'),
              ),
            ],
          ),
        ),
      ),
    );
    if (value != null && mounted) {
      setState(() {
        _currencies[value.$1] = value.$2;
        if (primary) {
          _currency = value.$1;
        } else if (CurrencyConversion.code(value.$1) !=
            CurrencyConversion.code(_currency)) {
          _references.add(value.$1);
        }
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    symbol.dispose();
    name.dispose();
  }
}
