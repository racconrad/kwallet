import 'package:knotes/core/models/currency_conversion.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/core/mvvm/view_model_state.dart';
import 'package:knotes/features/bodega/view_models/plan_editor_view_model.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/features/bodega/models/account.dart';
import 'package:knotes/features/bodega/models/category_model.dart';
import 'package:knotes/features/bodega/models/planned_expense.dart';
import 'package:knotes/core/widgets/menu_label.dart';
import 'package:knotes/core/theme/account_visuals.dart';
import 'package:knotes/core/theme/category_visuals.dart';

class PlanSheet extends StatefulWidget {
  final PlannedExpense? plan;
  final List<Account> accounts;
  final List<CategoryModel> categories;
  final String currency;
  final DateTime initialDate;
  const PlanSheet({
    super.key,
    this.plan,
    required this.accounts,
    required this.categories,
    required this.currency,
    required this.initialDate,
  });
  @override
  State<PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends ViewModelState<PlanSheet, PlanEditorViewModel> {
  @override
  PlanEditorViewModel createViewModel(AppDependencies dependencies) =>
      dependencies.planEditor();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late DateTime _date;
  String _recurrence = 'one_time';
  String? _account;
  String? _category;
  bool _special = false;
  String _iconKey = 'flag';
  bool get _saving => model.busy;
  String? get _error => model.error;

  static const _availableIcons = [
    ('flag', Icons.flag_rounded, 'Bandera'),
    ('star', Icons.star_rounded, 'Estrella'),
    ('cake', Icons.cake_rounded, 'Cumple'),
    ('celebration', Icons.celebration_rounded, 'Fiesta'),
    ('flight', Icons.flight_rounded, 'Viaje'),
    ('heart', Icons.favorite_rounded, 'Especial'),
    ('gift', Icons.card_giftcard_rounded, 'Regalo'),
    ('alarm', Icons.alarm_rounded, 'Alarma'),
    ('event', Icons.event_rounded, 'Evento'),
    ('work', Icons.work_rounded, 'Trabajo'),
    ('home', Icons.home_rounded, 'Hogar'),
    ('book', Icons.menu_book_rounded, 'Lectura'),
  ];

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _title.text = plan?.title ?? '';
    _amount.text = plan?.amount.toString() ?? '';
    _note.text = plan?.note ?? '';
    _special = plan?.amount == 0;
    _iconKey = plan?.iconKey ?? (plan?.amount == 0 ? 'flag' : 'event');
    _date = plan?.dueDate ?? widget.initialDate;
    _recurrence = plan?.recurrence ?? 'one_time';
    _account = widget.accounts.any((a) => a.id == plan?.accountId)
        ? plan!.accountId
        : null;
    _category = widget.categories.any((c) => c.id == plan?.categoryId)
        ? plan!.categoryId
        : widget.categories.firstOrNull?.id;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await model.save(
      original: widget.plan,
      title: _title.text,
      amountText: _amount.text,
      special: _special,
      date: _date,
      recurrence: _recurrence,
      note: _note.text,
      iconKey: _iconKey,
      categoryId: _category,
      accountId: _account,
    );
    if (saved && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => SheetBody(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.plan == null ? 'Nueva fecha' : 'Editar fecha',
                style: KnotesTheme.fontTitle.copyWith(fontSize: 20),
              ),
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Día especial, sin gasto'),
          value: _special,
          onChanged: (value) => setState(() {
            _special = value;
            if (value && _iconKey == 'event') _iconKey = 'flag';
          }),
        ),
        if (_special) ...[
          const SizedBox(height: 6),
          Text(
            'Icono del día especial',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: KnotesTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (key, icon, label) in _availableIcons)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(icon, size: 16),
                      label: Text(label),
                      selected: _iconKey == key,
                      onSelected: (_) => setState(() => _iconKey = key),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _title,
          decoration: InputDecoration(labelText: 'Título'),
        ),
        SizedBox(height: 12),
        if (!_special) ...[
          TextField(
            controller: _amount,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto previsto',
              prefixText: '${CurrencyConversion.symbol(widget.currency)} ',
            ),
          ),
          SizedBox(height: 12),
          DropdownButtonFormField<String>(
            borderRadius: dropdownRadius,
            icon: const Icon(Icons.expand_more_rounded),
            initialValue: _category,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'Categoría'),
            items: [
              for (final cat in widget.categories)
                DropdownMenuItem(
                  value: cat.id,
                  child: MenuLabel(cat.iconData, cat.name),
                ),
            ],
            onChanged: (value) => setState(() => _category = value),
          ),
          SizedBox(height: 12),
          DropdownButtonFormField<String>(
            borderRadius: dropdownRadius,
            icon: const Icon(Icons.expand_more_rounded),
            initialValue: _account,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Cuenta de referencia (opcional)',
            ),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: MenuLabel(Icons.touch_app_outlined, 'Elegir al pagar'),
              ),
              for (final account in widget.accounts)
                DropdownMenuItem(
                  value: account.id,
                  child: MenuLabel(
                    account.iconData,
                    account.name,
                    color: account.displayColor,
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _account = value),
          ),
          SizedBox(height: 12),
        ],
        TextField(
          controller: _note,
          decoration: InputDecoration(labelText: 'Nota'),
        ),
        SizedBox(height: 12),
        DropdownButtonFormField<String>(
          borderRadius: dropdownRadius,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded),
          initialValue: _recurrence,
          decoration: InputDecoration(labelText: 'Repetir'),
          items: [
            for (final (value, icon, text) in const [
              ('one_time', Icons.event_outlined, 'Una vez'),
              ('weekly', Icons.view_week_outlined, 'Cada semana'),
              ('monthly', Icons.calendar_month_outlined, 'Cada mes'),
              ('yearly', Icons.event_repeat_outlined, 'Cada año'),
            ])
              DropdownMenuItem(value: value, child: MenuLabel(icon, text)),
          ],
          onChanged: (value) => setState(() => _recurrence = value!),
        ),
        SizedBox(height: 12),
        OutlinedButton.icon(
          icon: Icon(Icons.event),
          label: Text(DateFormat('dd/MM/yyyy').format(_date)),
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (date != null && mounted) setState(() => _date = date);
          },
        ),
        if (_error != null)
          Text(_error!, style: TextStyle(color: KnotesTheme.expenseRed)),
        SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: Icon(Icons.check),
          label: Text(_saving ? 'Guardando…' : 'Guardar'),
        ),
      ],
    ),
  );
}
