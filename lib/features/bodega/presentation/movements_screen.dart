import 'package:knotes/core/theme/category_visuals.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/core/mvvm/view_model_state.dart';
import 'package:knotes/features/bodega/view_models/movements_view_model.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/features/bodega/models/account.dart';
import 'package:knotes/features/bodega/models/category_model.dart';
import 'package:knotes/features/bodega/models/monthly_movement_summary.dart';
import 'package:knotes/features/bodega/models/transaction_record.dart';
import 'package:knotes/core/widgets/menu_label.dart';
import 'package:knotes/core/theme/account_visuals.dart';

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
  bool _confirmingVoid = false;
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

  Future<void> _voidMovement(
    TransactionRecord tx,
    BuildContext sheetContext,
  ) async {
    if (_confirmingVoid || model.busy || _archived) return;
    _confirmingVoid = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Anular movimiento'),
          content: const Text(
            'El saldo se corregirá y el registro quedará en el archivo de anulaciones.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Anular'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final success = await model.voidMovement(tx);
      if (!mounted) return;
      if (sheetContext.mounted) Navigator.pop(sheetContext);
      if (!success) {
        showFailure(context, 'No se pudo anular el movimiento. Reintenta.');
      }
    } finally {
      _confirmingVoid = false;
    }
  }

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
                        borderRadius: dropdownRadius,
                        icon: const Icon(Icons.expand_more_rounded),
                        initialValue: _account,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Cuenta'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: MenuLabel(
                              Icons.all_inclusive_rounded,
                              'Todas',
                            ),
                          ),
                          for (final a in _accounts)
                            DropdownMenuItem(
                              value: a.id,
                              child: MenuLabel(
                                a.iconData,
                                a.name,
                                color: a.displayColor,
                              ),
                            ),
                        ],
                        onChanged: model.selectAccount,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        borderRadius: dropdownRadius,
                        icon: const Icon(Icons.expand_more_rounded),
                        initialValue: _type,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: [
                          for (final (value, icon, text) in [
                            (null, Icons.all_inclusive_rounded, 'Todos'),
                            ('expense', Icons.south_west_rounded, 'Gastos'),
                            ('income', Icons.north_east_rounded, 'Ingresos'),
                            (
                              'transfer',
                              Icons.swap_horiz_rounded,
                              'Transferencias',
                            ),
                            (
                              'adjustment',
                              Icons.tune_rounded,
                              'Ajustes de saldo',
                            ),
                          ])
                            DropdownMenuItem<String>(
                              value: value,
                              child: MenuLabel(icon, text),
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
                    style: TextStyle(color: KnotesTheme.textSecondary),
                  ),
                LedgerPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('$_count movimientos', style: KnotesTheme.fontTitle),
                      const SizedBox(height: 8),
                      Text(
                        'Ingresos  ${KnotesTheme.formatCurrency(_income, widget.currency)}',
                        style: TextStyle(color: KnotesTheme.incomeGreen),
                      ),
                      Text(
                        'Gastos  ${KnotesTheme.formatCurrency(_expense, widget.currency)}',
                        style: TextStyle(color: KnotesTheme.expenseRed),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Neto  ${KnotesTheme.formatCurrency(_income - _expense, widget.currency)}',
                        style: KnotesTheme.fontTitle,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Totales de todo el rango. Las transferencias internas no cuentan como ingreso ni gasto.',
                        style: TextStyle(
                          fontSize: 12,
                          color: KnotesTheme.textSecondary,
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
                                '+ ${KnotesTheme.formatCurrency(month.income, widget.currency)}   − ${KnotesTheme.formatCurrency(month.expense, widget.currency)}',
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
                        style: TextStyle(color: KnotesTheme.textSecondary),
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
              color: KnotesTheme.accent,
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
                  : ''}${KnotesTheme.formatCurrency(tx.amount, tx.currency ?? account?.currency ?? widget.currency)}',
              style: TextStyle(
                color: tx.isNegative
                    ? KnotesTheme.expenseRed
                    : KnotesTheme.incomeGreen,
              ),
            ),
            onTap: () => showModalBottomSheet(
              context: context,
              builder: (sheetContext) => SheetBody(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      tx.note.isEmpty ? 'Detalle del movimiento' : tx.note,
                      style: KnotesTheme.fontTitle.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      KnotesTheme.formatCurrency(
                        tx.amount,
                        tx.currency ?? account?.currency ?? widget.currency,
                      ),
                      style: KnotesTheme.fontDisplay.copyWith(fontSize: 30),
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
                    if (!_archived) ...[
                      const SizedBox(height: 16),
                      AnimatedBuilder(
                        animation: model,
                        builder: (_, _) => TextButton.icon(
                          onPressed: model.busy
                              ? null
                              : () => _voidMovement(tx, sheetContext),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Anular movimiento'),
                        ),
                      ),
                    ],
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
