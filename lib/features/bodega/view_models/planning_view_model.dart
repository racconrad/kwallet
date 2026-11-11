import 'package:knotes/core/models/currency_conversion.dart';
import 'package:knotes/core/contracts/app_repositories.dart';
import 'package:knotes/core/models/date_span.dart';
import 'package:knotes/core/mvvm/view_model.dart';
import 'package:knotes/features/journal/models/journal_models.dart';
import 'package:knotes/features/bodega/models/account.dart';
import 'package:knotes/features/bodega/models/category_model.dart';
import 'package:knotes/features/bodega/models/finance_overview.dart';
import 'package:knotes/features/bodega/models/planned_expense.dart';

class PlanningViewModel extends ViewModel {
  final FinanceRepository repository;
  final SettingsRepository preferences;
  final JournalRepository? journal;
  List<PlannedExpense> plans = const [];
  List<Account> accounts = const [];
  Map<String, String> _accountCurrencies = const {};
  List<CategoryModel> categories = const [];
  List<PersonalNote> notes = const [];
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateSpan range = DateSpan(dateOnly(DateTime.now()), dateOnly(DateTime.now()));
  String currency = '\$';
  Map<String, double> rates = const {};
  bool loading = true;
  bool rangeMode = false;
  DateTime? rangeAnchor;
  List<Map<String, dynamic>> paymentHistory = const [];

  PlanningViewModel(this.repository, this.preferences, [this.journal]) {
    for (final source in {
      repository.changes,
      preferences.changes,
      if (journal != null) journal!.changes,
    }) {
      observe(source, load);
    }
  }

  double _convert(double amount, String from) => CurrencyConversion.convert(
    amount,
    from: from,
    to: currency,
    rates: rates,
    dominantCurrency: currency,
  );
  double get balance =>
      accounts.fold(0, (sum, a) => sum + _convert(a.balance, a.currency));
  double get committed => plannedTotal(
    plans
        .map(
          (p) => p.copyWith(
            amount: _convert(
              p.amount,
              _accountCurrencies[p.accountId] ?? currency,
            ),
          ),
        )
        .toList(),
    dateOnly(DateTime.now()),
    DateTime.now().add(const Duration(days: 30)),
    includeOverdue: true,
  );
  List<PlannedExpense> get overdue => plans
      .where(
        (p) =>
            !p.isCompleted &&
            dateOnly(p.dueDate).isBefore(dateOnly(DateTime.now())),
      )
      .toList();
  List<PlannedExpense> get completedPlans =>
      plans.where((p) => p.isCompleted).toList();
  List<({PlannedExpense plan, DateTime date})> get entries => [
    for (final plan in plans)
      for (final date in plan.datesBetween(range.start, range.end))
        (plan: plan, date: date),
  ]..sort((a, b) => a.date.compareTo(b.date));

  List<({PersonalNote note, int itemIndex, NoteItem item})> get dueNoteItems =>
      [
        for (final note in notes)
          for (var i = 0; i < note.items.length; i++)
            if (note.items[i].dueDate != null &&
                !dateOnly(note.items[i].dueDate!).isBefore(range.start) &&
                !dateOnly(note.items[i].dueDate!).isAfter(range.end))
              (note: note, itemIndex: i, item: note.items[i]),
      ];

  Map<String, ({double balance, double scheduled, List<Account> shortAccounts})>
  get cashflowForecast {
    final currencyMap =
        <
          String,
          ({double balance, double scheduled, List<Account> shortAccounts})
        >{};
    final accountScheduled = <String, double>{};
    for (final entry in entries) {
      if (entry.plan.accountId != null) {
        accountScheduled[entry.plan.accountId!] =
            (accountScheduled[entry.plan.accountId!] ?? 0) + entry.plan.amount;
      }
    }

    final fallbackCurrency = accounts.isNotEmpty
        ? accounts.first.currency
        : '\$';
    for (final account in accounts) {
      final cur = account.currency.trim().isEmpty
          ? fallbackCurrency
          : account.currency.trim();
      final sched = accountScheduled[account.id] ?? 0.0;
      final current = currencyMap[cur];
      final isShort = sched > account.balance;
      final shortList = current?.shortAccounts != null
          ? List<Account>.from(current!.shortAccounts)
          : <Account>[];
      if (isShort && !shortList.any((a) => a.id == account.id)) {
        shortList.add(account);
      }
      currencyMap[cur] = (
        balance: (current?.balance ?? 0.0) + account.balance,
        scheduled: (current?.scheduled ?? 0.0) + sched,
        shortAccounts: shortList,
      );
    }
    return currencyMap;
  }

  Future<void> toggleNoteItem(PersonalNote note, int index, bool done) async {
    if (journal == null) return;
    await journal!.setNoteItem(
      note.id,
      index,
      done,
      expectedText: note.items[index].text,
    );
  }

  Future<void> load({bool restoreRange = false}) async {
    final request = beginRequest();
    try {
      final nextPlans = await repository.getPlannedExpenses();
      final historicalAccounts = await repository.getAccounts(
        includeArchived: true,
        includeDeleted: true,
      );
      final nextAccounts = historicalAccounts
          .where((a) => !a.isArchived && !a.isDeleted)
          .toList();
      final nextCategories = await repository.getCategories(type: 'expense');
      final nextNotes = journal != null
          ? await journal!.getNotes()
          : const <PersonalNote>[];
      final nextPayments = await repository.getPlannedExpensePayments();
      final settings = await preferences.getSettings();
      final nextRates = await preferences.getCurrencyRates();
      for (final account in nextAccounts) {
        CurrencyConversion.convert(
          account.balance,
          from: account.currency,
          to: settings['currency'] ?? '\$',
          rates: nextRates,
          dominantCurrency: settings['currency'] ?? '\$',
        );
      }
      if (!isCurrent(request)) return;
      currency = settings['currency'] ?? '\$';
      rates = Map.unmodifiable(nextRates);
      plans = List.unmodifiable(nextPlans);
      paymentHistory = List.unmodifiable(nextPayments);
      _accountCurrencies = Map.unmodifiable({
        for (final a in historicalAccounts) a.id: a.currency,
      });
      accounts = List.unmodifiable(nextAccounts);
      categories = List.unmodifiable(nextCategories);
      notes = List.unmodifiable(nextNotes);
      loading = false;
      error = null;
      final start = DateTime.tryParse(settings['plan_range_start'] ?? '');
      final end = DateTime.tryParse(settings['plan_range_end'] ?? '');
      if (restoreRange &&
          start != null &&
          end != null &&
          !end.isBefore(start)) {
        range = DateSpan(dateOnly(start), dateOnly(end));
        rangeMode = dateOnly(start) != dateOnly(end);
        month = DateTime(start.year, start.month);
      }
      changed();
    } catch (_) {
      if (isCurrent(request)) {
        loading = false;
        fail('No se pudo cargar la planificación.');
      }
    }
  }

  Future<void> selectRange(
    DateTime start,
    DateTime end, {
    bool preserveMode = false,
  }) async {
    range = DateSpan(dateOnly(start), dateOnly(end));
    if (!preserveMode) rangeMode = dateOnly(start) != dateOnly(end);
    month = DateTime(start.year, start.month);
    changed();
    try {
      await preferences.saveSettings({
        'plan_range_start': start.toIso8601String(),
        'plan_range_end': end.toIso8601String(),
      });
    } catch (_) {
      fail('No se pudo guardar la selección. Reintenta.');
    }
  }

  void setMonth(DateTime value) {
    month = value;
    changed();
  }

  void setRangeMode(bool value) {
    rangeMode = value;
    rangeAnchor = null;
    changed();
  }

  void tapDate(DateTime date) {
    if (!rangeMode || rangeAnchor == null) {
      rangeAnchor = rangeMode ? date : null;
      selectRange(date, date, preserveMode: true);
    } else {
      final anchor = rangeAnchor!;
      rangeAnchor = null;
      selectRange(
        date.isBefore(anchor) ? date : anchor,
        date.isBefore(anchor) ? anchor : date,
        preserveMode: true,
      );
    }
  }

  Future<bool> pay(PlannedExpense plan, String? account) {
    if (plan.amount > 0 && account == null) {
      return Future.value(fail('Añade una cuenta antes de registrar el pago.'));
    }
    return perform(
      () => repository.payPlannedExpense(
        plan.id,
        account ?? plan.accountId ?? '',
        expectedDueDate: plan.dueDate,
      ),
    );
  }

  Future<bool> remove(PlannedExpense plan) =>
      perform(() => repository.deletePlannedExpense(plan.id));
}
