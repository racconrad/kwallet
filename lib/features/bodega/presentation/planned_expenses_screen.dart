import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/core/mvvm/view_model_state.dart';
import 'package:knotes/features/bodega/view_models/planning_view_model.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/features/bodega/models/account.dart';
import 'package:knotes/features/bodega/models/category_model.dart';
import 'package:knotes/features/bodega/models/finance_overview.dart';
import 'package:knotes/features/bodega/models/planned_expense.dart';
import 'package:knotes/features/bodega/presentation/planned_expense_sheet.dart';
import 'package:knotes/features/bodega/presentation/widgets/agenda_cashflow_card.dart';
import 'package:knotes/features/bodega/presentation/widgets/agenda_due_notes_panel.dart';
import 'package:knotes/features/bodega/presentation/widgets/plan_calendar.dart';
import 'package:knotes/features/bodega/presentation/widgets/plan_history_section.dart';
import 'package:knotes/core/widgets/menu_label.dart';

class PlannedExpensesScreen extends StatefulWidget {
  final String currency;
  const PlannedExpensesScreen({super.key, this.currency = '\$'});
  @override
  State<PlannedExpensesScreen> createState() => _PlannedExpensesScreenState();
}

class _PlannedExpensesScreenState
    extends ViewModelState<PlannedExpensesScreen, PlanningViewModel> {
  @override
  PlanningViewModel createViewModel(AppDependencies dependencies) =>
      dependencies.planning();
  List<PlannedExpense> get _plans => model.plans;
  List<Account> get _accounts => model.accounts;
  List<CategoryModel> get _categories => model.categories;
  DateTime get _month => model.month;
  DateTimeRange get _range =>
      DateTimeRange(start: model.range.start, end: model.range.end);
  bool get _loading => model.loading;
  bool get _rangeMode => model.rangeMode;
  DateTime? get _rangeAnchor => model.rangeAnchor;
  bool get _busy => model.busy;
  String? get _error => model.error;
  void _refresh() => model.load();
  void _tapDate(DateTime date) => model.tapDate(date);
  Future<void> _selectRange(DateTimeRange range) =>
      model.selectRange(range.start, range.end);

  void _edit([PlannedExpense? plan]) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => PlanSheet(
      plan: plan,
      accounts: _accounts,
      categories: _categories,
      currency: widget.currency,
      initialDate: _range.start,
    ),
  );

  Future<void> _pay(PlannedExpense plan) async {
    if (_busy) return;
    if (plan.amount == 0 || _accounts.isEmpty) {
      await _payWith(plan, null);
      return;
    }
    final accountId = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(
          'Pagar ${KnotesTheme.formatCurrency(plan.amount, widget.currency)}',
        ),
        children: [
          for (final account in _accounts)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, account.id),
              child: ListTile(
                leading: Icon(Icons.account_balance_wallet_outlined),
                title: Text(account.name),
                subtitle: Text(
                  KnotesTheme.formatCurrency(account.balance, widget.currency),
                ),
              ),
            ),
        ],
      ),
    );
    if (accountId != null && mounted) await _payWith(plan, accountId);
  }

  Future<void> _payWith(PlannedExpense plan, String? account) async {
    if (!await model.pay(plan, account) && mounted) {
      showFailure(context, model.error ?? 'No se pudo registrar el pago.');
    }
  }

  Future<void> _remove(PlannedExpense plan) async {
    if (!await model.remove(plan) && mounted) {
      showFailure(context, model.error ?? 'No se pudo eliminar el compromiso.');
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    if (_loading) return Center(child: CircularProgressIndicator());
    final now = dateOnly(DateTime.now());
    final entries = model.entries;
    final overdue = model.overdue;
    return Scaffold(
      appBar: AppBar(title: const Text('Planificación')),
      body: ContentWidth(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
          itemCount: entries.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    TextButton(
                      onPressed: _refresh,
                      child: Text('$_error Reintentar'),
                    ),
                  AgendaCashflowCard(model: model),
                  PlanCalendar(
                    month: _month,
                    range: _range,
                    plans: _plans,
                    onMonth: model.setMonth,
                    onSelect: _tapDate,
                  ),
                  const SizedBox(height: 16),
                  AgendaDueNotesPanel(model: model),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Un día'),
                        icon: Icon(Icons.today_outlined),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Rango'),
                        icon: Icon(Icons.date_range_outlined),
                      ),
                    ],
                    selected: {_rangeMode},
                    onSelectionChanged: (value) =>
                        model.setRangeMode(value.first),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _rangeMode
                        ? (_rangeAnchor == null
                              ? 'Elige inicio y fin.'
                              : 'Elige la fecha final.')
                        : 'Elige un día.',
                    style: TextStyle(color: KnotesTheme.textSecondary),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () =>
                            _selectRange(DateTimeRange(start: now, end: now)),
                        child: const Text('Hoy'),
                      ),
                      TextButton(
                        onPressed: () => _selectRange(
                          DateTimeRange(
                            start: now,
                            end: DateTime(now.year, now.month, now.day + 6),
                          ),
                        ),
                        child: const Text('7 días'),
                      ),
                      TextButton(
                        onPressed: () => _selectRange(
                          DateTimeRange(
                            start: now,
                            end: DateTime(now.year, now.month, now.day + 29),
                          ),
                        ),
                        child: const Text('30 días'),
                      ),
                      if (overdue.isNotEmpty)
                        TextButton.icon(
                          icon: Icon(
                            Icons.warning_amber,
                            color: KnotesTheme.expenseRed,
                          ),
                          label: Text('${overdue.length} vencidos'),
                          onPressed: () {
                            final first = overdue
                                .map((p) => dateOnly(p.dueDate))
                                .reduce((a, b) => a.isBefore(b) ? a : b);
                            _selectRange(DateTimeRange(start: first, end: now));
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateUtils.isSameDay(_range.start, _range.end)
                                  ? DateFormat(
                                      'd MMM yyyy',
                                      'es',
                                    ).format(_range.start)
                                  : '${DateFormat('d MMM', 'es').format(_range.start)} – ${DateFormat('d MMM', 'es').format(_range.end)}',
                              style: KnotesTheme.fontTitle.copyWith(
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              '${entries.length} fechas · ${KnotesTheme.formatCurrency(plannedTotal(_plans, _range.start, _range.end), widget.currency)}',
                              style: TextStyle(
                                color: KnotesTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _edit(),
                        icon: const Icon(Icons.add),
                        label: const Text('Añadir'),
                      ),
                    ],
                  ),
                  Divider(height: 24),
                  if (entries.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Todo tranquilo por aquí. Añade un pago o un día especial.',
                      ),
                    ),
                ],
              );
            }
            if (index <= entries.length) {
              final entry = entries[index - 1];
              return _entry(entry.plan, entry.date);
            }
            return PlanHistorySection(model: model, currency: widget.currency);
          },
        ),
      ),
    );
  }

  IconData _planIcon(PlannedExpense plan) {
    return switch (plan.iconKey) {
      'star' => Icons.star_rounded,
      'cake' => Icons.cake_rounded,
      'celebration' => Icons.celebration_rounded,
      'flight' => Icons.flight_rounded,
      'heart' => Icons.favorite_rounded,
      'gift' => Icons.card_giftcard_rounded,
      'alarm' => Icons.alarm_rounded,
      'event' => Icons.event_rounded,
      'work' => Icons.work_rounded,
      'home' => Icons.home_rounded,
      'book' => Icons.menu_book_rounded,
      'flag' => Icons.flag_rounded,
      _ => plan.amount == 0 ? Icons.flag_outlined : Icons.event_outlined,
    };
  }

  Widget _entry(PlannedExpense plan, DateTime date) {
    final current = DateUtils.isSameDay(plan.dueDate, date);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_planIcon(plan)),
      title: Text(plan.title),
      subtitle: Text(
        '${DateFormat('dd/MM/yyyy').format(date)} · ${plan.recurrenceLabel}${plan.note.isEmpty ? '' : '\n${plan.note}'}',
      ),
      isThreeLine: plan.note.isNotEmpty,
      onTap: () => _edit(plan),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (plan.amount > 0)
            Text(KnotesTheme.formatCurrency(plan.amount, widget.currency)),
          PopupMenuButton<String>(
            tooltip: 'Acciones del compromiso',
            enabled: !_busy,
            onSelected: (value) {
              if (value == 'pay') _pay(plan);
              if (value == 'edit') _edit(plan);
              if (value == 'delete') {
                _remove(plan);
              }
            },
            itemBuilder: (_) => [
              if (current)
                menuItem(
                  'pay',
                  Icons.check_circle_outline_rounded,
                  plan.amount == 0 ? 'Completar' : 'Registrar pago',
                ),
              menuItem('edit', Icons.edit_outlined, 'Editar'),
              menuItem(
                'delete',
                Icons.delete_outline_rounded,
                'Eliminar',
                danger: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
