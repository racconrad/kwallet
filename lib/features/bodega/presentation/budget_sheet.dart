import '../../../core/models/currency_conversion.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/mvvm/view_model_state.dart';
import '../view_models/budget_editor_view_model.dart';
import '../../../core/theme/kwall_theme.dart';
import '../../../core/widgets/finance_widgets.dart';
import '../models/finance_overview.dart';

String periodLabel(BudgetPeriod period) => switch (period) {
  BudgetPeriod.daily => 'Hoy',
  BudgetPeriod.weekly => 'Esta semana',
  BudgetPeriod.monthly => 'Este mes',
};

class BudgetSheet extends StatefulWidget {
  final BudgetPeriod period;
  final double current;
  final double available;
  final String currency;
  final String mode;
  final double share;
  const BudgetSheet({
    super.key,
    required this.period,
    required this.current,
    required this.available,
    required this.currency,
    required this.mode,
    required this.share,
  });
  @override
  State<BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState
    extends ViewModelState<BudgetSheet, BudgetEditorViewModel> {
  @override
  BudgetEditorViewModel createViewModel(AppDependencies dependencies) =>
      dependencies.budgetEditor();
  late final _amount = TextEditingController(
    text: widget.current.toStringAsFixed(2),
  );
  late String _mode = widget.mode;
  late double _share = widget.share.clamp(1, 100);
  bool get _saving => model.busy;
  String? get _error => model.error;
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (await model.save(widget.period, _amount.text, _mode, _share) &&
        mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = model.previewAmount(_amount.text);
    final maximum = math.max(100.0, math.max(widget.available, amount * 1.5));
    return SheetBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tu presupuesto, a tu ritmo',
            style: KwallTheme.fontTitle.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 8),
          Text(
            periodLabel(widget.period),
            style: TextStyle(color: KwallTheme.textSecondary),
          ),
          const SizedBox(height: 18),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: 'assigned',
                label: Text('Asignar'),
                icon: Icon(Icons.edit_outlined),
              ),
              ButtonSegment(
                value: 'available',
                label: Text('Saldo libre'),
                icon: Icon(Icons.auto_awesome_outlined),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (set) => setState(() => _mode = set.first),
          ),
          const SizedBox(height: 20),
          if (_mode == 'assigned') ...[
            TextField(
              controller: _amount,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: KwallTheme.fontDisplay.copyWith(fontSize: 30),
              decoration: InputDecoration(
                labelText: 'Asignación para este período',
                prefixText: '${CurrencyConversion.symbol(widget.currency)} ',
              ),
            ),
            Slider(
              value: amount.clamp(0, maximum),
              min: 0,
              max: maximum,
              onChanged: (value) =>
                  setState(() => _amount.text = value.toStringAsFixed(2)),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final value in [25, 50, 100])
                  ActionChip(
                    label: Text('$value% del saldo libre'),
                    onPressed: () => setState(
                      () => _amount.text = (widget.available * value / 100)
                          .toStringAsFixed(2),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Solo para este período.'),
          ] else ...[
            Text(
              '${_share.round()}% del saldo libre',
              style: KwallTheme.fontTitle.copyWith(fontSize: 24),
            ),
            Slider(
              value: _share,
              min: 1,
              max: 100,
              divisions: 99,
              onChanged: (value) => setState(() => _share = value),
            ),
            const Text('Tus reservas y próximos pagos quedan protegidos.'),
          ],
          const SizedBox(height: 20),
          if (_error != null)
            Text(_error!, style: TextStyle(color: KwallTheme.expenseRed)),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(_saving ? 'Guardando…' : 'Aplicar presupuesto'),
          ),
        ],
      ),
    );
  }
}
