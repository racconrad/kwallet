import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/features/bodega/view_models/planning_view_model.dart';

class AgendaCashflowCard extends StatelessWidget {
  final PlanningViewModel model;

  const AgendaCashflowCard({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    final forecast = model.cashflowForecast;
    if (forecast.isEmpty) return const SizedBox.shrink();

    final allShortAccounts = <String>[];
    for (final entry in forecast.entries) {
      for (final acc in entry.value.shortAccounts) {
        allShortAccounts.add('${acc.name} (${acc.currency})');
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LedgerPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  size: 18,
                  color: KnotesTheme.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Previsión de flujo por divisa',
                    style: KnotesTheme.fontTitle.copyWith(fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in forecast.entries)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: KnotesTheme.surfaceContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
                      border: Border.all(
                        color: item.value.shortAccounts.isNotEmpty
                            ? KnotesTheme.expenseRed.withValues(alpha: 0.5)
                            : KnotesTheme.border.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.key,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: KnotesTheme.accent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Previsto: ${KnotesTheme.formatCurrency(item.value.scheduled, item.key)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: KnotesTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Disponible: ${KnotesTheme.formatCurrency(item.value.balance, item.key)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: KnotesTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (allShortAccounts.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: KnotesTheme.expenseRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: KnotesTheme.expenseRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: KnotesTheme.expenseRed,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Saldo insuficiente previsto en: ${allShortAccounts.join(", ")}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: KnotesTheme.expenseRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
