import '../../../core/models/currency_conversion.dart';
import '../../../core/theme/category_visuals.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/mvvm/view_model_state.dart';
import '../view_models/transaction_editor_view_model.dart';
import '../../../core/theme/kwall_theme.dart';
import '../../../core/widgets/finance_widgets.dart';
import '../models/account.dart';
import '../models/category_model.dart';
import '../models/transaction_record.dart';
import 'categories_sheet.dart';

class AddTransactionSheet extends StatefulWidget {
  final List<Account> accounts;
  final String? preselectedAccountId;
  final String? preselectedDestinationId;
  final String initialType;
  final String currency;
  const AddTransactionSheet({
    super.key,
    required this.accounts,
    this.preselectedAccountId,
    this.preselectedDestinationId,
    this.initialType = 'expense',
    this.currency = '\$',
  });
  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState
    extends ViewModelState<AddTransactionSheet, TransactionEditorViewModel> {
  @override
  TransactionEditorViewModel createViewModel(AppDependencies dependencies) =>
      dependencies.transactionEditor(widget.accounts, widget.initialType);
  final _amount = TextEditingController();
  final _note = TextEditingController();
  List<TransactionRecord> get _queue => model.queue;
  String get _type => model.type;
  late String _account;
  String? _destination;
  String? get _category => model.category;
  DateTime _date = DateTime.now();
  List<CategoryModel> get _categories => model.categories;
  bool get _saving => model.busy;
  String? get _error => model.error;

  @override
  void initState() {
    super.initState();
    _account = model.initialAccount(widget.preselectedAccountId);
    final others = widget.accounts.where((a) => a.id != _account);
    _destination = others.any((a) => a.id == widget.preselectedDestinationId)
        ? widget.preselectedDestinationId
        : others.firstOrNull?.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  MovementInput get _input => (
    amount: _amount.text,
    note: _note.text,
    date: _date,
    account: _account,
    destination: _destination,
    category: _category,
  );
  void _addToQueue() {
    if (model.enqueue(_input)) {
      _amount.clear();
      _note.clear();
    }
  }

  Future<void> _repeatDates() async {
    if (!model.validate(_input)) return;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Repetir el gasto en cada día del rango',
      saveText: 'Añadir días',
    );
    if (range != null &&
        mounted &&
        model.repeat(_input, range.start, range.end)) {
      _amount.clear();
      _note.clear();
    }
  }

  Future<void> _save() async {
    if (await model.save(_input) && mounted) Navigator.pop(context);
  }

  Widget _accountPicker({
    bool destination = false,
  }) => DropdownButtonFormField<String>(
    icon: const Icon(Icons.expand_more_rounded),
    initialValue: destination ? _destination : _account,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: destination ? 'Cuenta destino' : 'Cuenta',
    ),
    items: [
      for (final account in widget.accounts)
        DropdownMenuItem(
          value: account.id,
          child: Text(
            '${account.name} · ${CurrencyConversion.symbol(account.currency)}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: _saving
        ? null
        : (value) => setState(() {
            if (destination) {
              _destination = value;
            } else {
              _account = value!;
            }
          }),
  );

  @override
  Widget build(BuildContext context) => SheetBody(
    child: AbsorbPointer(
      absorbing: _saving,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Nuevo movimiento',
                  style: KwallTheme.fontTitle.copyWith(fontSize: 20),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final type in ['expense', 'income', 'transfer'])
                ChoiceChip(
                  label: Text(switch (type) {
                    'expense' => 'Gasto',
                    'income' => 'Ingreso',
                    _ => 'Transferir',
                  }),
                  avatar: Icon(switch (type) {
                    'expense' => Icons.remove,
                    'income' => Icons.add,
                    _ => Icons.sync_alt,
                  }, size: 18),
                  selected: _type == type,
                  onSelected: _queue.isNotEmpty
                      ? null
                      : (_) {
                          model.selectType(type);
                        },
                ),
            ],
          ),
          SizedBox(height: 16),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            style: KwallTheme.fontDisplay.copyWith(fontSize: 28),
            decoration: InputDecoration(
              labelText: 'Monto',
              prefixText:
                  '${CurrencyConversion.symbol(widget.accounts.firstWhere((a) => a.id == _account).currency)} ',
            ),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: InputDecoration(
              labelText: 'Nota',
              prefixIcon: Icon(Icons.edit_note),
            ),
          ),
          SizedBox(height: 12),
          _accountPicker(),
          if (_type == 'transfer') ...[
            SizedBox(height: 12),
            _accountPicker(destination: true),
          ],
          if (_type != 'transfer') ...[
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    icon: const Icon(Icons.expand_more_rounded),
                    key: ValueKey('$_type:$_category:${_categories.length}'),
                    initialValue: _category,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: 'Categoría'),
                    items: [
                      for (final category in _categories)
                        DropdownMenuItem(
                          value: category.id,
                          child: Row(
                            children: [
                              Icon(category.iconData, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  category.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: model.selectCategory,
                  ),
                ),
                IconButton(
                  tooltip: 'Gestionar categorías',
                  icon: Icon(Icons.category_outlined),
                  onPressed: () async {
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => CategoriesSheet(
                        type: _type == 'income' ? 'income' : 'expense',
                      ),
                    );
                    if (mounted) model.loadCategories();
                  },
                ),
              ],
            ),
          ],
          SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: Icon(Icons.event, size: 18),
              label: Text(DateFormat('dd/MM/yyyy').format(_date)),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null && mounted) setState(() => _date = date);
              },
            ),
          ),
          if (_type == 'expense') ...[
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _addToQueue,
                  icon: Icon(Icons.playlist_add),
                  label: Text('Sumar gasto'),
                ),
                TextButton.icon(
                  onPressed: _repeatDates,
                  icon: Icon(Icons.date_range),
                  label: Text('Repetir en días'),
                ),
              ],
            ),
            if (_queue.isNotEmpty) ...[
              Divider(height: 24),
              Text(
                '${_queue.length} gastos · ${KwallTheme.formatCurrency(model.queueTotal, widget.currency)}',
              ),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  itemCount: _queue.length,
                  itemBuilder: (_, index) {
                    final tx = _queue[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${KwallTheme.formatCurrency(tx.amount, widget.currency)} · ${tx.note}',
                      ),
                      subtitle: Text(DateFormat('dd/MM/yyyy').format(tx.date)),
                      trailing: IconButton(
                        tooltip: 'Quitar del lote',
                        icon: Icon(Icons.close),
                        onPressed: () => model.removeQueued(index),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
          if (_error != null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                style: TextStyle(color: KwallTheme.expenseRed),
              ),
            ),
          SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: Icon(Icons.check),
            label: Text(
              _saving
                  ? 'Guardando…'
                  : _queue.isEmpty
                  ? 'Guardar'
                  : 'Guardar lote',
            ),
          ),
        ],
      ),
    ),
  );
}
