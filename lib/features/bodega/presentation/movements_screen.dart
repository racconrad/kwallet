import '../../../core/theme/category_visuals.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/mvvm/view_model_state.dart';
import '../view_models/movements_view_model.dart';
import '../../../core/theme/kwall_theme.dart';
import '../../../core/widgets/finance_widgets.dart';
import '../models/account.dart';
import '../models/category_model.dart';
import '../models/monthly_movement_summary.dart';
import '../models/transaction_record.dart';

class MovementsScreen extends StatefulWidget {
  final String currency;
  const MovementsScreen({super.key, required this.currency});
  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState
    extends ViewModelState<MovementsScreen, MovementsViewModel> {
  @override
  MovementsViewModel createViewModel(AppDependencies dependencies) =>
      dependencies.movements();
  final _search = TextEditingController();
  final _scroll = ScrollController();
  List<Account> get _accounts => model.accounts;
  Map<String, CategoryModel> get _categories => model.categories;
  List<TransactionRecord> get _records => model.records;
  List<MonthlyMovementSummary> get _months => model.months;
  String? get _account => model.account;
  bool get _archived => model.archived;
  String? get _type => model.type;
  DateTime? get _start => model.start;
  DateTime? get _end => model.end;
  bool get _loading => model.loading;
  bool get _more => model.more;
  int get _count => model.count;
  double get _income => model.income;
  double get _expense => model.expense;
  String? get _error => model.error;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_nearEnd);
  }

  void _refresh() => _load();
  void _nearEnd() {
    if (_scroll.position.extentAfter < 300 && !_loading && _more) {
      _load(next: true);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool next = false}) => model.load(next: next);

  Future<void> _date(bool start) async {
    final date = await showDatePicker(
      context: context,
      initialDate: (start ? _start : _end) ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    model.selectDate(date, from: start);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mis movimientos')),
    body: ContentWidth(
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(20),
        itemCount: _records.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _search,
                  onChanged: model.searchFor,
                  decoration: const InputDecoration(
                    labelText: 'Buscar nota o categoría',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        icon: const Icon(Icons.expand_more_rounded),
                        initialValue: _account,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Cuenta'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Todas'),
                          ),
                          for (final a in _accounts)
                            DropdownMenuItem(
                              value: a.id,
                              child: Text(
                                a.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: model.selectAccount,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        icon: const Icon(Icons.expand_more_rounded),
                        initialValue: _type,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: const [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text('Todos'),
                          ),
                          DropdownMenuItem(
                            value: 'expense',
                            child: Text('Gastos'),
                          ),
                          DropdownMenuItem(
                            value: 'income',
                            child: Text('Ingresos'),
                          ),
                          DropdownMenuItem(
                            value: 'transfer',
                            child: Text('Transferencias'),
                          ),
                          DropdownMenuItem(
                            value: 'adjustment',
                            child: Text('Ajustes de saldo'),
                          ),
                        ],
                        onChanged: model.selectType,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.event_outlined, size: 18),
                      label: Text(
                        _start == null
                            ? 'Desde siempre'
                            : DateFormat('dd/MM/yy').format(_start!),
                      ),
                      onPressed: () => _date(true),
                    ),
                    ActionChip(
                      label: Text(
                        _end == null
                            ? 'Sin límite final'
                            : DateFormat('dd/MM/yy').format(_end!),
                      ),
                      onPressed: () => _date(false),
                    ),
                    if (_start != null || _end != null)
                      ActionChip(
                        label: const Text('Todo el historial'),
                        onPressed: model.clearDates,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ver movimientos anulados'),
                  value: _archived,
                  onChanged: model.showArchived,
                ),
                if (_archived)
                  Text(
                    'Estos importes están anulados: no afectan tus saldos ni presupuestos.',
                    style: TextStyle(color: KwallTheme.textSecondary),
                  ),
                LedgerPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('$_count movimientos', style: KwallTheme.fontTitle),
                      const SizedBox(height: 8),
                      Text(
                        'Ingresos  ${KwallTheme.formatCurrency(_income, widget.currency)}',
                        style: TextStyle(color: KwallTheme.incomeGreen),
                      ),
                      Text(
                        'Gastos  ${KwallTheme.formatCurrency(_expense, widget.currency)}',
                        style: TextStyle(color: KwallTheme.expenseRed),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Neto  ${KwallTheme.formatCurrency(_income - _expense, widget.currency)}',
                        style: KwallTheme.fontTitle,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Totales de todo el rango. Las transferencias internas no cuentan como ingreso ni gasto.',
                        style: TextStyle(
                          fontSize: 12,
                          color: KwallTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_months.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      _archived ? 'Anulaciones por mes' : 'Resumen por mes',
                    ),
                    children: [
                      SizedBox(
                        height: 180,
                        child: ListView.builder(
                          itemCount: _months.length,
                          itemBuilder: (_, i) {
                            final month = _months[i];
                            return ListTile(
                              dense: true,
                              title: Text(month.month),
                              subtitle: Text(
                                '+ ${KwallTheme.formatCurrency(month.income, widget.currency)}   − ${KwallTheme.formatCurrency(month.expense, widget.currency)}',
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                if (_error != null)
                  TextButton(onPressed: _refresh, child: Text(_error!)),
                const SizedBox(height: 12),
              ],
            );
          }
          if (index == _records.length + 1) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _more
                  ? TextButton(
                      onPressed: () => _load(next: true),
                      child: const Text('Cargar más'),
                    )
                  : Center(
                      child: Text(
                        _records.isEmpty
                            ? 'No hay movimientos con estos filtros.'
                            : 'Fin del historial',
                        style: TextStyle(color: KwallTheme.textSecondary),
                      ),
                    ),
            );
          }
          final tx = _records[index - 1];
          final account = _accounts
              .where((a) => a.id == tx.accountId)
              .firstOrNull;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              tx.isTransfer
                  ? Icons.swap_horiz
                  : _categories[tx.categoryId]?.iconData ??
                        Icons.receipt_long_outlined,
              color: KwallTheme.accent,
            ),
            title: Text(
              tx.note.isEmpty
                  ? _categories[tx.categoryId]?.name ?? 'Movimiento'
                  : tx.note,
            ),
            subtitle: Text(
              '${DateFormat('dd/MM/yyyy').format(tx.date)} · ${account?.name ?? 'Cuenta archivada'}',
            ),
            trailing: Text(
              '${tx.isNegative
                  ? '-'
                  : tx.isPositive
                  ? '+'
                  : ''}${KwallTheme.formatCurrency(tx.amount, tx.currency ?? account?.currency ?? widget.currency)}',
              style: TextStyle(
                color: tx.isNegative
                    ? KwallTheme.expenseRed
                    : KwallTheme.incomeGreen,
              ),
            ),
            onTap: () => showModalBottomSheet(
              context: context,
              builder: (_) => SheetBody(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tx.note.isEmpty ? 'Detalle del movimiento' : tx.note,
                      style: KwallTheme.fontTitle.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      KwallTheme.formatCurrency(
                        tx.amount,
                        tx.currency ?? account?.currency ?? widget.currency,
                      ),
                      style: KwallTheme.fontDisplay.copyWith(fontSize: 30),
                    ),
                    Text(
                      DateFormat('dd MMMM yyyy · HH:mm', 'es').format(tx.date),
                    ),
                    const SizedBox(height: 12),
                    Text('Cuenta: ${account?.name ?? 'Cuenta archivada'}'),
                    if (tx.toAccountId != null)
                      Text(
                        'Destino: ${_accounts.where((a) => a.id == tx.toAccountId).firstOrNull?.name ?? 'Cuenta archivada'}',
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
