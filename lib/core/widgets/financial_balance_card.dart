import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';

/// Unified financial balance and liquidity card used across Home and Finances screens.
class FinancialBalanceCard extends StatelessWidget {
  final double balance;
  final double available;
  final String currency;
  final Map<String, double> cashByCurrency;
  final String title;
  final VoidCallback? onAction;
  final String? actionLabel;

  const FinancialBalanceCard({
    super.key,
    required this.balance,
    required this.available,
    required this.currency,
    required this.cashByCurrency,
    this.title = 'Estado financiero',
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final ink = KnotesTheme.onAccent;
    final wash = ink.withValues(alpha: .14);
    return LedgerPanel(
      color: KnotesTheme.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: wash, shape: BoxShape.circle),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: ink,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ink.withValues(alpha: .85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onAction != null && actionLabel != null)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onAction,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          actionLabel!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.chevron_right_rounded, size: 14, color: ink),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              KnotesTheme.formatCurrency(balance, currency),
              style: KnotesTheme.fontDisplay.copyWith(fontSize: 40, color: ink),
            ),
          ),
          if (cashByCurrency.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final entry in cashByCurrency.entries)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: wash,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${entry.key}: ${KnotesTheme.formatCurrency(entry.value, entry.key)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: wash,
              borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: ink),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Libre disponible: ${KnotesTheme.formatCurrency(available, currency)}',
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
