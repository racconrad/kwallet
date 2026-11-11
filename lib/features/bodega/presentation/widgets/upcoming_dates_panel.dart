import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/features/bodega/models/planned_expense.dart';
import 'package:knotes/features/bodega/view_models/home_view_model.dart';

class UpcomingDatesPanel extends StatelessWidget {
  final HomeViewModel controller;
  final VoidCallback onOpenAgenda;

  const UpcomingDatesPanel({
    super.key,
    required this.controller,
    required this.onOpenAgenda,
  });

  @override
  Widget build(BuildContext context) {
    final plans = controller.upcomingPlans;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return LedgerPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: KnotesTheme.accentLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.event_repeat_rounded,
                  color: KnotesTheme.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fechas importantes y pagos',
                      style: KnotesTheme.fontTitle.copyWith(fontSize: 18),
                    ),
                    Text(
                      plans.isEmpty
                          ? 'Sin compromisos próximos'
                          : '${KnotesTheme.formatCurrency(controller.weeklyCommitments, controller.currency)} previstos esta semana',
                      style: TextStyle(
                        fontSize: 12,
                        color: KnotesTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Ver calendario',
                onPressed: onOpenAgenda,
                icon: const Icon(Icons.calendar_month_outlined, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (plans.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    color: KnotesTheme.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No tienes compromisos próximos en los siguientes 30 días.',
                      style: TextStyle(
                        fontSize: 13,
                        color: KnotesTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            for (final plan in plans.take(3)) ...[
              _buildPlanTile(plan, today),
              const SizedBox(height: 8),
            ],
            TextButton.icon(
              onPressed: onOpenAgenda,
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: const Text('Ver todos en Agenda'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanTile(PlannedExpense plan, DateTime today) {
    final planDate = DateTime(
      plan.dueDate.year,
      plan.dueDate.month,
      plan.dueDate.day,
    );
    final diff = planDate.difference(today).inDays;
    final dateLabel = diff == 0
        ? 'Hoy'
        : diff == 1
        ? 'Mañana'
        : diff > 1 && diff <= 7
        ? 'En $diff días'
        : DateFormat('d MMM', 'es').format(plan.dueDate);

    final isSpecial = plan.amount == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: KnotesTheme.surfaceContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
        border: Border.all(
          color: diff == 0
              ? KnotesTheme.expenseRed.withValues(alpha: 0.4)
              : KnotesTheme.border.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: diff == 0
                  ? KnotesTheme.expenseRed.withValues(alpha: 0.15)
                  : KnotesTheme.accentLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              dateLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: diff == 0 ? KnotesTheme.expenseRed : KnotesTheme.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  plan.recurrenceLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: KnotesTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isSpecial)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, color: KnotesTheme.accent, size: 16),
                const SizedBox(width: 4),
                const Text(
                  'Especial',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            )
          else
            Text(
              KnotesTheme.formatCurrency(plan.amount, controller.currency),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
        ],
      ),
    );
  }
}
