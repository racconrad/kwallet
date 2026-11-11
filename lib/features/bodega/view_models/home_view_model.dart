import 'package:knotes/core/models/currency_conversion.dart';

import 'dart:math' as math;

import 'package:knotes/core/mvvm/view_model.dart';

import 'package:uuid/uuid.dart';

import 'package:knotes/core/contracts/app_repositories.dart';
import 'package:knotes/core/services/device_files.dart';
import 'package:knotes/core/services/notification_service.dart';
import 'package:knotes/core/services/reminder_check_in_sync.dart';
import 'package:knotes/core/services/widget_sync_service.dart';
import 'package:knotes/features/journal/models/journal_models.dart';
import 'package:knotes/features/bodega/models/account.dart';
import 'package:knotes/features/bodega/models/budget_model.dart';
import 'package:knotes/features/bodega/models/category_model.dart';
import 'package:knotes/features/bodega/models/finance_overview.dart';
import 'package:knotes/features/bodega/models/planned_expense.dart';
import 'package:knotes/features/bodega/models/quick_expense.dart';
import 'package:knotes/core/theme/knotes_palette.dart';
import 'package:knotes/features/bodega/models/transaction_record.dart';

class HomeViewModel extends ViewModel {
  final FinanceRepository finance;
  final JournalRepository journal;
  final SettingsRepository preferences;
  final DeviceFiles? files;
  bool hasRecovery = false;
  String? diagnosticInfo;

  HomeViewModel(this.finance, this.journal, this.preferences, {this.files}) {
    for (final source in {
      finance.changes,
      journal.changes,
      preferences.changes,
    }) {
      observe(source, load);
    }
  }
  int _xp = 0;
  int _reward = 0;
  bool _loaded = false;
  List<Account> inactiveAccounts = const [];
  List<Account> _accounts = const [];
  Map<String, String> _accountCurrencies = const {};
  Set<String> _excludedAccountIds = const {};
  List<TransactionRecord> _transactions = const [];
  Map<String, CategoryModel> _categories = const {};
  List<PlannedExpense> _plans = const [];
  List<PersonalNote> _notes = const [];
  List<Habit> _habits = const [];
  List<Goal> _goals = const [];
  bool _snapshotRunning = false;
  late final _reminderCheckIns = ReminderCheckInSync(journal);
  List<QuickExpense> _quickExpenses = const [];
  Map<String, String> _settings = const {};
  Map<String, double> _rates = const {};
  Map<BudgetPeriod, double> _allocations = const {};
  BudgetModel? _budget;
  Map<BudgetPeriod, double> _spent = const {};
  BudgetPeriod _period = BudgetPeriod.monthly;
  String? _filter;

  List<Account> get accounts => _accounts;
  List<TransactionRecord> get transactions => _transactions;
  Map<String, CategoryModel> get categories => _categories;
  List<QuickExpense> get quickExpenses => _quickExpenses;
  List<PersonalNote> get notes => _notes;
  List<Habit> get habits => _habits;
  List<Goal> get goals => _goals;
  List<Goal> get activeGoals =>
      _goals.where((g) => !g.isExpired(DateTime.now())).toList();
  Map<String, String> get settings => _settings;
  Map<String, double> get rates => _rates;
  BudgetModel? get budget => _budget;
  BudgetPeriod get period => _period;
  double get spent => _spent[_period] ?? 0;
  String? get filter => _filter;
  int get xp => _xp;
  String get currency => _settings['currency'] ?? '\$';
  double _convert(double value, String from) => CurrencyConversion.convert(
    value,
    from: from,
    to: currency,
    rates: _rates,
    dominantCurrency: currency,
  );
  double get balance =>
      _accounts.fold(0, (sum, a) => sum + _convert(a.balance, a.currency));

  // Grouped cash diversification by account base currency
  Map<String, double> get cashByCurrency {
    final map = <String, double>{};
    for (final a in _accounts) {
      final cur = a.currency.trim().isEmpty ? currency : a.currency.trim();
      map[cur] = (map[cur] ?? 0.0) + a.balance;
    }
    return map;
  }

  double get reserves => _accounts.fold(
    0,
    (sum, a) =>
        sum +
        _convert(
          a.type == 'vault' ? math.max(0, a.balance) : a.minimumBalance,
          a.currency,
        ),
  );
  List<PlannedExpense> get _convertedPlans => _plans
      .map(
        (p) => p.copyWith(
          amount: _convert(
            p.amount,
            _accountCurrencies[p.accountId] ?? currency,
          ),
        ),
      )
      .toList();
  double get committed => plannedTotal(
    _convertedPlans,
    DateTime.now(),
    DateTime.now().add(const Duration(days: 30)),
    includeOverdue: true,
  );
  double get weeklyCommitments {
    final week = periodRange(BudgetPeriod.weekly, DateTime.now());
    return plannedTotal(
      _convertedPlans,
      week.start,
      week.end.subtract(const Duration(days: 1)),
    );
  }

  double get savings => _accounts
      .where((a) => a.type == 'vault')
      .fold(0, (sum, a) => sum + _convert(math.max(0, a.balance), a.currency));
  double get _availableCommitments => plannedTotal(
    _convertedPlans
        .where((p) => !_excludedAccountIds.contains(p.accountId))
        .toList(),
    DateTime.now(),
    DateTime.now().add(const Duration(days: 30)),
    includeOverdue: true,
  );
  double get _spendable => _accounts
      .where((a) => !a.excludeFromAvailable)
      .fold(
        0,
        (sum, a) =>
            sum +
            _convert(
              a.type == 'vault'
                  ? math.min(0, a.balance)
                  : a.balance - a.minimumBalance,
              a.currency,
            ),
      );
  double get available => math.max(0, _spendable - _availableCommitments);
  String get budgetMode => _settings['budget_mode'] ?? 'assigned';
  double get share =>
      (double.tryParse(_settings['budget_share'] ?? '') ?? 100).clamp(1, 100);
  double get limit => budgetMode == 'available'
      ? flexibleBudget(
          spent: spent,
          balance: _spendable,
          reserves: 0,
          commitments: _availableCommitments,
          share: share,
        )
      : _allocations[_period] ??
            (_budget == null ? 0 : budgetLimit(_budget!, _period));

  void selectAccount(String? id) {
    _filter = id != null && _filter != id ? id : null;
    _reward = 0;
    changed();
    load();
  }

  void selectPeriod(BudgetPeriod period) {
    _period = period;
    _reward = 0;
    changed();
  }

  int takeReward() {
    final reward = _reward;
    _reward = 0;
    return reward;
  }

  int get completedHabitsToday =>
      _habits.where((h) => h.logFor(DateTime.now())?.completed == true).length;
  int get totalHabitsToday => _habits.length;
  int get pendingHabitsCount =>
      _habits.where((h) => h.logFor(DateTime.now())?.completed != true).length;

  List<({PersonalNote note, int index, NoteItem item})> get pendingTasks {
    final result = <({PersonalNote note, int index, NoteItem item})>[];
    for (final note in _notes) {
      if (note.items.isNotEmpty) {
        for (var i = 0; i < note.items.length; i++) {
          if (!note.items[i].done) {
            result.add((note: note, index: i, item: note.items[i]));
          }
        }
      }
    }
    return result;
  }

  List<PlannedExpense> get upcomingPlans {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final limit = today.add(const Duration(days: 30));
    return _plans
        .where((p) => !p.dueDate.isBefore(today) && !p.dueDate.isAfter(limit))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  Future<bool> voidMovement(TransactionRecord tx) =>
      perform(() => finance.deleteTransaction(tx));

  Future<TransactionRecord?> logQuickExpense({
    required String title,
    required double amount,
    required String categoryId,
    String? accountId,
  }) async {
    final targetAccount = accountId != null
        ? _accounts.where((a) => a.id == accountId).firstOrNull ??
              _accounts.firstOrNull
        : _accounts.firstOrNull;
    if (targetAccount == null) return null;

    final record = TransactionRecord(
      id: const Uuid().v4(),
      accountId: targetAccount.id,
      categoryId: categoryId,
      amount: amount,
      type: 'expense',
      note: title,
      date: DateTime.now(),
      createdAt: DateTime.now(),
    );

    final ok = await perform(() => finance.addTransactions([record]));
    return ok ? record : null;
  }

  Future<bool> saveQuickExpense(QuickExpense item) =>
      perform(() => finance.saveQuickExpense(item));

  Future<bool> deleteQuickExpense(String id) =>
      perform(() => finance.deleteQuickExpense(id));

  Future<bool> completeHabit(Habit habit, [DateTime? day]) async {
    final ok = await perform(
      () => journal.logHabitDays(
        [habit.id],
        [day ?? DateTime.now()],
        completed: true,
        mood: 'happy',
      ),
    );
    if (ok) {
      final now = day ?? DateTime.now();
      final todayStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await journal.markFrontPendingItemDone(
        'habit_${habit.id}_$todayStr',
        true,
      );
      _syncWidget();
    }
    return ok;
  }

  Future<bool> markGoal(Goal goal, [int delta = 1]) =>
      perform(() => journal.markGoal(goal.id, delta: delta));

  Future<bool> checkNote(PersonalNote note, int index, bool done) async {
    final ok = await perform(
      () => journal.setNoteItem(
        note.id,
        index,
        done,
        expectedText: note.items[index].text,
      ),
    );
    if (ok) {
      await journal.markFrontPendingItemDone('task_${note.id}_$index', done);
    }
    return ok;
  }

  Future<bool> petCompanion([int points = 2]) async {
    bool awarded = false;
    await perform(() async {
      awarded = await journal.awardAffection(points);
    });
    if (awarded) {
      _syncWidget();
    }
    return awarded;
  }

  String _petPose = 'idle';
  String _petMood = 'normal';
  bool _petFacingRight = true;
  void syncPetState(String pose, String mood, bool facingRight) {
    if (_petPose == pose &&
        _petMood == mood &&
        _petFacingRight == facingRight) {
      return;
    }
    _petPose = pose;
    _petMood = mood;
    _petFacingRight = facingRight;
    WidgetSyncService.syncPetState(
      pose: pose,
      mood: mood,
      facingRight: facingRight,
    );
  }

  void _syncWidget() {
    final bgMode = _settings['widget_bg_mode'] ?? 'default';
    final bgColor = int.tryParse(_settings['widget_bg_color'] ?? '');

    WidgetSyncService.syncWidget(
      petName: _settings['pet_name'] ?? 'Mishi',
      xp: _xp,
      completedHabits: completedHabitsToday,
      totalHabits: totalHabitsToday,
      pendingHabits: pendingHabitsCount,
      statusMessage: pendingHabitsCount > 0
          ? 'Tienes $pendingHabitsCount ${pendingHabitsCount == 1 ? "hábito pendiente" : "hábitos pendientes"} hoy.'
          : (totalHabitsToday > 0
                ? 'Todos tus hábitos completados hoy.'
                : 'Todo al día y organizado.'),
      petStyle: _settings['pet_style'] ?? 'classic',
      petSettings: _settings,
      petPose: _petPose,
      petMood: _petMood,
      petFacingRight: _petFacingRight,
      themePalette: _settings['palette'] ?? KnotesPalette.fallback,
      widgetBgMode: bgMode,
      widgetBgColor: bgColor,
    );
  }

  Future<void> load() async {
    final version = beginRequest();
    try {
      await _reminderCheckIns.sync();
      final pendingAffection =
          await WidgetSyncService.consumePendingAffection();
      if (pendingAffection > 0) {
        await journal.awardAffection(pendingAffection);
      }
      final now = DateTime.now();
      final allAccounts = await finance.getAccounts(
        includeArchived: true,
        includeDeleted: true,
      );
      final accounts = allAccounts
          .where((a) => !a.isArchived && !a.isDeleted)
          .toList();
      final filter = accounts.any((a) => a.id == _filter) ? _filter : null;
      final transactions = await finance.getTransactions(
        accountId: filter,
        limit: 5,
      );
      final categories = await finance.getCategories();
      final budget = await finance.getCurrentBudget();
      final plans = await finance.getPlannedExpenses(includeCompleted: false);
      final settings = await preferences.getSettings();
      final rates = await preferences.getCurrencyRates();
      final allocations = await finance.getBudgetAllocations(now);
      final xp = await journal.getExperience();
      final notes = await journal.getNotes();
      final habits = await journal.getHabits();
      final quickExpenses = await finance.getQuickExpenses();
      final spent = await finance.getPeriodSpending(now);
      final goals = await journal.getGoals();
      if (!isCurrent(version)) return;
      _reward = _loaded ? math.max(0, xp - _xp) : 0;
      _accountCurrencies = Map.unmodifiable({
        for (final a in allAccounts) a.id: a.currency,
      });
      _excludedAccountIds = Set.unmodifiable(
        allAccounts.where((a) => a.excludeFromAvailable).map((a) => a.id),
      );
      _accounts = List.unmodifiable(accounts);
      inactiveAccounts = List.unmodifiable(
        allAccounts.where((a) => a.isArchived && !a.isDeleted),
      );
      _filter = filter;
      _transactions = List.unmodifiable(transactions);
      _categories = Map.unmodifiable({for (final c in categories) c.id: c});
      _budget = budget;
      _plans = List.unmodifiable(plans);
      _settings = Map.unmodifiable(settings);
      _rates = Map.unmodifiable(rates);
      _allocations = Map.unmodifiable(allocations);
      _spent = Map.unmodifiable(spent);
      _notes = List.unmodifiable(notes);
      _habits = List.unmodifiable(habits);
      _goals = List.unmodifiable(goals);
      _quickExpenses = List.unmodifiable(quickExpenses);
      _xp = xp;
      _loaded = true;
      error = null;

      changed();
      _syncWidget();
      NotificationService.syncReminders(
        settings: settings,
        habits: habits,
        goals: goals,
        plans: upcomingPlans,
        accountCurrencies: _accountCurrencies,
      ).ignore();
      if (!_snapshotRunning && settings['auto_backup'] != 'false') {
        _snapshotRunning = true;
        // The repository checks the day; only overlapping attempts are skipped.
        preferences
            .ensureDailySnapshot()
            .catchError((_) => false)
            .whenComplete(() => _snapshotRunning = false)
            .ignore();
      }
    } catch (e) {
      if (isCurrent(version)) {
        _reward = 0;
        diagnosticInfo = e.toString();
        try {
          hasRecovery = await preferences.hasRecoveryCopies();
        } catch (_) {
          hasRecovery = false;
        }

        final errStr = e.toString().toLowerCase();
        if (errStr.contains('no es compatible') ||
            errStr.contains('incompatible')) {
          error = 'Versión no compatible con tu app actual. Requiere una versión más reciente de knotes.';
        } else if (errStr.contains('corrupt') ||
            errStr.contains('databaseexception') ||
            errStr.contains('malformed') ||
            errStr.contains('disk') ||
            errStr.contains('lock')) {
          error = 'El archivo de tu bóveda tiene problemas de lectura en este dispositivo.';
        } else {
          error = 'No se pudieron cargar tus datos en este momento.';
        }
        changed();
      }
    }
  }

  Future<bool> restoreRecovery() => perform(() async {
    final ok = await preferences.restoreLatestRecoveryCopy();
    if (!ok) throw StateError('No hay copia disponible para restaurar.');
    await load();
  });

  Future<bool> repairDatabase() => perform(() async {
    await preferences.repairOrResetDatabase();
    await load();
  });

  Future<bool> createNewVault() => repairDatabase();

  Future<bool> importBackup() => perform(() async {
    final picker = files ?? NativeDeviceFiles();
    final content = await picker.pickBackup();
    if (content == null || content.trim().isEmpty) return;
    await preferences.importRecoveryBackup(content);
    await load();
  });

  Future<void> saveSetting(String key, String value) async {
    _settings = Map.unmodifiable({..._settings, key: value});
    await preferences.saveSettings({key: value});
    changed();
  }
}
