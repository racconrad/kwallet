import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/core/models/currency_conversion.dart';
import 'package:knotes/core/models/pet_species.dart';
import 'package:knotes/core/mvvm/view_model_state.dart';
import 'package:knotes/core/services/notification_service.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/currency_definition_sheet.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/core/widgets/kitty_companion.dart';
import 'package:knotes/core/widgets/pet_loading_screen.dart';
import 'package:knotes/features/bodega/models/account.dart';
import 'package:knotes/features/bodega/models/category_model.dart';
import 'package:knotes/features/bodega/models/quick_expense.dart';
import 'package:knotes/features/bodega/presentation/bodega_screen.dart';
import 'package:knotes/features/journal/models/journal_models.dart';
import 'package:knotes/features/welcome/view_models/launch_view_model.dart';
import 'package:knotes/features/welcome/presentation/widgets/adoption_box.dart';
import 'package:knotes/features/welcome/presentation/widgets/adoption_picker.dart';
import 'package:knotes/features/welcome/presentation/widgets/adoption_scene.dart';

import 'package:knotes/features/welcome/presentation/widgets/launch_ui.dart';

part 'launch_steps.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});
  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends ViewModelState<LaunchScreen, LaunchViewModel> {
  @override
  LaunchViewModel createViewModel(AppDependencies dependencies) =>
      dependencies.launch();

  final _petName = TextEditingController();
  final _accountName = TextEditingController();
  final _balance = TextEditingController();
  final _expenseTitle = TextEditingController();
  final _expenseAmount = TextEditingController();
  final _categoryName = TextEditingController();
  final _habitTitle = TextEditingController();
  final _accountId = const Uuid().v4();
  final _accountForm = GlobalKey<FormState>();
  final _expenseForm = GlobalKey<FormState>();
  final Map<String, String> _currencies = {};
  final List<QuickExpense> _expenses = [];
  final List<CategoryModel> _categories = [];
  final Map<String, String> _habits = {};
  String _currency = '';
  String _style = 'classic';
  String _accountType = 'cash';
  int _index = 0;
  bool _long = true;
  final _noteText = TextEditingController();
  String? _habitReminder = '20:00';
  final List<String> _notes = [];
  bool _forward = true;
  bool _initialized = false;
  bool _opened = false;
  bool _advanced = false;
  bool _notifications = false;
  bool _requestingPermission = false;
  bool _greeted = false;
  bool _entered = false;
  String? _validationError;

  String get _name =>
      _petName.text.trim().isEmpty ? 'tu compañero' : _petName.text.trim();
  Map<String, String> get _petSettings => {
    ...model.settings,
    'pet_style': _style,
    'pet_name': _name,
  };
  bool get _hasAccount => _accountName.text.trim().isNotEmpty;
  List<_Step> get _steps => _long
      ? const [
          _Step.box,
          _Step.name,
          _Step.tour,
          _Step.path,
          _Step.currency,
          _Step.account,
          _Step.expenses,
          _Step.habits,
          _Step.notes,
          _Step.review,
        ]
      : const [
          _Step.box,
          _Step.name,
          _Step.tour,
          _Step.path,
          _Step.currency,
          _Step.account,
          _Step.review,
        ];
  _Step get _step => _steps[_index];
  bool get _optional => const {
    _Step.currency,
    _Step.account,
    _Step.expenses,
    _Step.habits,
    _Step.notes,
  }.contains(_step);

  @override
  void onViewModelChanged() {
    if (!_initialized && model.ready) {
      _currencies.addAll(model.userCurrencies);
      _currency =
          model.settings['currency'] ?? _currencies.keys.firstOrNull ?? '';
      final species =
          PetSpecies.values[math.Random().nextInt(PetSpecies.values.length)];
      _style =
          model.settings['pet_style'] ??
          PetSpeciesCatalog.pickRandom(species: species).key;
      _petName.text = model.settings['pet_name'] ?? '';
      KittyCompanionWidget.loadAtlas(PetSpeciesCatalog.resolveAsset(_style))
          .ignore();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _petName,
      _accountName,
      _balance,
      _expenseTitle,
      _expenseAmount,
      _categoryName,
      _habitTitle,
      _noteText,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _go(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      _forward = index > _index;
      _index = index.clamp(0, _steps.length - 1);
      _validationError = null;
    });
  }

  Duration _motion(int ms) => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: ms);

  void _openBox() {
    HapticFeedback.lightImpact();
    setState(() => _opened = true);
  }

  void _next() {
    if (_step == _Step.box && !_opened) {
      _openBox();
      return;
    }
    if (_step == _Step.name && _petName.text.trim().isEmpty) {
      setState(() => _validationError = 'Escribe un nombre para tu compañero.');
      return;
    }
    if (_step == _Step.account) {
      if (!_accountForm.currentState!.validate()) return;
      if (_currency.isEmpty) {
        setState(
          () => _validationError =
              'Elige una moneda en el paso anterior o elige Omitir por ahora.',
        );
        return;
      }
    }
    if (_step == _Step.expenses &&
        [
          _expenseTitle,
          _expenseAmount,
          _categoryName,
        ].any((c) => c.text.trim().isNotEmpty)) {
      if (!_addExpense()) return;
    }
    if (_step == _Step.habits && _habitTitle.text.trim().isNotEmpty) {
      _addHabit();
    }
    if (_step == _Step.notes && _noteText.text.trim().isNotEmpty) _addNote();
    if (_step == _Step.review) {
      _enter();
    } else {
      _go(_index + 1);
    }
  }

  void _skip() {
    setState(() {
      if (_step == _Step.account) {
        _accountName.clear();
        _balance.clear();
        _expenses.clear();
        _categories.clear();
        _expenseTitle.clear();
        _expenseAmount.clear();
        _categoryName.clear();
      } else if (_step == _Step.expenses) {
        _expenses.clear();
        _categories.clear();
        _expenseTitle.clear();
        _expenseAmount.clear();
        _categoryName.clear();
      } else if (_step == _Step.habits) {
        _habits.clear();
        _habitTitle.clear();
        _notifications = false;
      } else if (_step == _Step.notes) {
        _notes.clear();
        _noteText.clear();
      }
    });
    _go(_index + 1);
  }

  Future<void> _addCurrency() async {
    final result = await defineCurrency(context, existing: _currencies.keys);
    if (result == null || !mounted) return;
    setState(() {
      _currencies[result.$1] = result.$2;
      if (_currency.isEmpty) _currency = result.$1;
    });
  }

  bool _addExpense() {
    if (!_hasAccount || !_expenseForm.currentState!.validate()) return false;
    final title = _expenseTitle.text.trim();
    final categoryName = _categoryName.text.trim();
    final existing = _categories
        .where((c) => c.name.toLowerCase() == categoryName.toLowerCase())
        .firstOrNull;
    final category =
        existing ??
        CategoryModel(
          id: const Uuid().v4(),
          name: categoryName,
          type: 'expense',
          iconKey: 'bolt',
          colorValue: KnotesTheme.accent.toARGB32(),
          isDefault: false,
        );
    setState(() {
      if (existing == null) _categories.add(category);
      _expenses.add(
        QuickExpense(
          id: const Uuid().v4(),
          title: title,
          amount: _parseAmount(_expenseAmount.text)!,
          categoryId: category.id,
          accountId: _accountId,
          createdAt: DateTime.now(),
        ),
      );
      _expenseTitle.clear();
      _expenseAmount.clear();
      _categoryName.clear();
    });
    FocusManager.instance.primaryFocus?.unfocus();
    return true;
  }

  void _addHabit() {
    final title = _habitTitle.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _habits[const Uuid().v4()] = title;
      _habitTitle.clear();
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _addNote() {
    final text = _noteText.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _notes.add(text);
      _noteText.clear();
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _pickHabitReminder() async {
    final parts = (_habitReminder ?? '20:00').split(':');
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 20,
        minute: int.tryParse(parts.last) ?? 0,
      ),
    );
    if (time != null && mounted) {
      setState(
        () => _habitReminder =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  double? _parseAmount(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  Future<void> _enter() async {
    if (model.busy) return;
    final ok = await model.enter(
      petStyle: _style,
      petName: _name,
      currency: _currency.isEmpty ? null : _currency,
      currencyName: _currencies[_currency],
      userCurrencies: _currencies,
      referenceCurrencies: _currencies.keys
          .where(
            (c) =>
                CurrencyConversion.code(c) !=
                CurrencyConversion.code(_currency),
          )
          .join(','),
      notificationsEnabled: _notifications,
      account: _hasAccount
          ? Account(
              id: _accountId,
              name: _accountName.text.trim(),
              type: _accountType,
              balance: _balance.text.trim().isEmpty
                  ? 0
                  : _parseAmount(_balance.text)!,
              currency: _currency,
              colorValue: KnotesTheme.accent.toARGB32(),
              createdAt: DateTime.now(),
            )
          : null,
      quickExpenses: _expenses,
      categories: _categories
          .where((c) => _expenses.any((e) => e.categoryId == c.id))
          .toList(),
      habits: _habits,
      habitReminderTime: _notifications ? _habitReminder : null,
      notes: [
        for (final text in _notes)
          ?parseQuickNote(
            text,
            id: const Uuid().v4(),
            newItemId: () => const Uuid().v4(),
          ),
      ],
    );
    if (ok && mounted) {
      HapticFeedback.mediumImpact();
      setState(() => _entered = true);
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
        const SnackBar(
          content: Text('Puedes activarlos después desde Ajustes.'),
        ),
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
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !model.busy) _go(_index - 1);
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
                          child: _index == 0
                              ? null
                              : IconButton(
                                  tooltip: 'Atrás',
                                  onPressed: model.busy
                                      ? null
                                      : () => _go(_index - 1),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                ),
                        ),
                        Expanded(
                          child: StepProgress(
                            index: _index,
                            count: _steps.length,
                            icon: _step.icon,
                            label: _step.label,
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: _motion(300),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (current, previous) => Stack(
                        fit: StackFit.expand,
                        children: [...previous, ?current],
                      ),
                      transitionBuilder: (child, animation) {
                        final incoming = child.key == ValueKey(_step);
                        final dx = (_forward ? 1 : -1) * .08;
                        return FadeTransition(
                          opacity: animation,
                          child: incoming
                              ? SlideTransition(
                                  position: Tween(
                                    begin: Offset(dx, 0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                )
                              : child,
                        );
                      },
                      child: SingleChildScrollView(
                        key: ValueKey(_step),
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (i, child) in _content().indexed)
                              Reveal(order: i, child: child),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_validationError != null || model.error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _validationError ?? model.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        FilledButton.icon(
                          onPressed: model.busy || _requestingPermission
                              ? null
                              : _next,
                          icon: model.busy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(switch (_step) {
                                  _Step.box when !_opened =>
                                    Icons.inventory_2_outlined,
                                  _Step.review => Icons.celebration_rounded,
                                  _ => Icons.arrow_forward_rounded,
                                }),
                          label: Text(
                            model.busy
                                ? 'Guardando…'
                                : switch (_step) {
                                    _Step.box =>
                                      _opened
                                          ? 'Darle un nombre'
                                          : 'Abrir la caja',
                                    _Step.name => 'Continuar con $_name',
                                    _Step.tour => 'Entendido',
                                    _Step.currency =>
                                      _currency.isEmpty
                                          ? 'Continuar'
                                          : 'Usar ${CurrencyConversion.symbol(_currency)}',
                                    _Step.path =>
                                      _long
                                          ? 'Empezar el recorrido'
                                          : 'Empezar rápido',
                                    _Step.account => 'Continuar con mi cuenta',
                                    _Step.expenses =>
                                      _hasAccount
                                          ? 'Continuar'
                                          : 'Seguir sin gastos',
                                    _Step.habits => 'Continuar',
                                    _Step.notes => 'Revisar y empezar',
                                    _Step.review => 'Empezar juntos',
                                  },
                          ),
                        ),
                        if (_optional)
                          TextButton(
                            onPressed: model.busy || _requestingPermission
                                ? null
                                : _skip,
                            child: const Text('Omitir por ahora'),
                          ),
                        if (_step == _Step.box)
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

  // Lets the part-file extension rebuild without touching protected setState.
  void _update(VoidCallback change) => setState(change);
}

enum _Step {
  box(Icons.inventory_2_outlined, 'Sorpresa'),
  name(Icons.badge_outlined, 'Nombre'),
  tour(Icons.explore_outlined, 'Áreas'),
  path(Icons.alt_route_rounded, 'Camino'),
  currency(Icons.currency_exchange_rounded, 'Moneda'),
  account(Icons.account_balance_wallet_outlined, 'Cuenta'),
  expenses(Icons.bolt_rounded, 'Gastos'),
  habits(Icons.local_fire_department_outlined, 'Hábitos'),
  notes(Icons.sticky_note_2_outlined, 'Notas'),
  review(Icons.celebration_outlined, 'Listo');

  final IconData icon;
  final String label;
  const _Step(this.icon, this.label);
}
