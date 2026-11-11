import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/features/bodega/view_models/home_view_model.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/core/widgets/juice_widgets.dart';
import 'package:knotes/features/bodega/models/finance_overview.dart';

class BudgetPanel extends StatelessWidget {
  final HomeViewModel controller;
  final VoidCallback onEdit;
  const BudgetPanel({
    super.key,
    required this.controller,
    required this.onEdit,
  });
  @override
  Widget build(BuildContext context) {
    final limit = controller.limit;
    if (limit <= 0) return const SizedBox.shrink();
    final spent = controller.spent;
    final remaining = limit - spent;
    return LedgerPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Presupuesto',
                  style: KnotesTheme.fontTitle.copyWith(fontSize: 20),
                ),
              ),
              IconButton(
                tooltip: 'Asignar presupuesto',
                onPressed: onEdit,
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final period in BudgetPeriod.values)
                ChoiceChip(
                  label: Text(switch (period) {
                    BudgetPeriod.daily => 'Día',
                    BudgetPeriod.weekly => 'Semana',
                    BudgetPeriod.monthly => 'Mes',
                  }),
                  selected: controller.period == period,
                  onSelected: (_) => controller.selectPeriod(period),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircularMeter(
                value: limit > 0 ? spent / limit : 0,
                icon: Icons.donut_small_rounded,
                color: remaining < 0
                    ? KnotesTheme.expenseRed
                    : KnotesTheme.accent,
                size: 58,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${remaining >= 0 ? 'Quedan' : 'Exceso'} ${KnotesTheme.formatCurrency(remaining.abs(), controller.currency)}',
                      style: KnotesTheme.fontTitle.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${KnotesTheme.formatCurrency(spent, controller.currency)} de ${KnotesTheme.formatCurrency(limit, controller.currency)}',
                      style: TextStyle(color: KnotesTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onEdit,
            icon: Icon(
              controller.budgetMode == 'available'
                  ? Icons.auto_awesome
                  : Icons.edit_outlined,
              size: 18,
            ),
            label: Text(
              controller.budgetMode == 'available'
                  ? 'Se adapta al saldo libre · ${controller.share.round()}%'
                  : 'Cambiar presupuesto',
            ),
          ),
        ],
      ),
    );
  }
}
