import '../../../../core/theme/account_visuals.dart';

import 'package:flutter/material.dart';

import '../../../../core/models/currency_conversion.dart';
import '../../../../core/theme/kwall_theme.dart';
import '../../../../core/widgets/juice_widgets.dart';
import '../../models/account.dart';

class AccountCard extends StatelessWidget {
  final Account account;
  final String currency;
  final Map<String, double> rates;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  const AccountCard({
    super.key,
    required this.account,
    required this.currency,
    this.rates = const {},
    required this.selected,
    required this.onTap,
    required this.onEdit,
  });
  @override
  Widget build(BuildContext context) {
    final below = account.balance < account.minimumBalance;
    final progress = account.minimumBalance > 0
        ? account.balance / account.minimumBalance
        : account.balance > 0
        ? 1.0
        : 0.0;
    final icon = account.iconData;
    return Material(
      color: selected ? KwallTheme.accentLight : KwallTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: below
              ? KwallTheme.expenseRed
              : KwallTheme.border.withValues(alpha: .65),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: CircularMeter(
                      value: progress,
                      icon: icon,
                      size: 54,
                      color: below
                          ? KwallTheme.expenseRed
                          : account.displayColor,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar ${account.name}',
                    onPressed: onEdit,
                    icon: const Icon(Icons.more_horiz_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                account.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KwallTheme.fontTitle,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  KwallTheme.formatCurrency(account.balance, account.currency),
                  style: KwallTheme.fontDisplay.copyWith(fontSize: 20),
                ),
              ),
              Builder(
                builder: (context) {
                  final isDiff =
                      account.currency.trim().toUpperCase() !=
                      currency.trim().toUpperCase();
                  final equivalents = <String>[];

                  try {
                    if (isDiff) {
                      final inDominant = CurrencyConversion.convert(
                        account.balance,
                        from: account.currency,
                        to: currency,
                        rates: rates,
                        dominantCurrency: currency,
                      );
                      equivalents.add(
                        '≈ ${KwallTheme.formatCurrency(inDominant, currency)}',
                      );
                    } else if (rates.isNotEmpty) {
                      for (final entry in rates.entries) {
                        if (entry.key.toUpperCase() != currency.toUpperCase()) {
                          final inAlt = CurrencyConversion.convert(
                            account.balance,
                            from: currency,
                            to: entry.key,
                            rates: rates,
                            dominantCurrency: currency,
                          );
                          equivalents.add(
                            '≈ ${KwallTheme.formatCurrency(inAlt, entry.key)}',
                          );
                        }
                      }
                    }
                  } on StateError {
                    equivalents.add('Tasa pendiente');
                  }
                  if (equivalents.isEmpty) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final eq in equivalents)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: KwallTheme.surfaceContainer.withValues(
                                alpha: 0.7,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              eq,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: KwallTheme.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Mín. ${KwallTheme.formatCurrency(account.minimumBalance, account.currency)}',
                style: TextStyle(fontSize: 12, color: KwallTheme.textSecondary),
              ),
              if (below)
                Text(
                  'Bajo el mínimo',
                  style: TextStyle(
                    fontSize: 12,
                    color: KwallTheme.expenseRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
