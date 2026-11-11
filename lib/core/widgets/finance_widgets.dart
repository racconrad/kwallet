import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';

class ContentWidth extends StatelessWidget {
  final Widget child;
  final double width;
  const ContentWidth({super.key, required this.child, this.width = 800});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: child,
    ),
  );
}

class LedgerPanel extends StatelessWidget {
  final Widget child;
  final Color? color;
  const LedgerPanel({super.key, required this.child, this.color});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(KnotesTheme.radiusMd),
      boxShadow: KnotesTheme.hardShadow,
    ),
    child: Material(
      color: color ?? KnotesTheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KnotesTheme.radiusMd),
        side: BorderSide(color: KnotesTheme.border, width: 1.5),
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    ),
  );
}

class CommitmentAlert extends StatelessWidget {
  final double balance;
  final double committed;
  final String currency;
  const CommitmentAlert({
    super.key,
    required this.balance,
    required this.committed,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    if (committed <= balance) return SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: LedgerPanel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: KnotesTheme.expenseRed),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Te faltan ${KnotesTheme.formatCurrency(committed - balance, currency)}',
                    style: KnotesTheme.fontTitle.copyWith(
                      color: KnotesTheme.expenseRed,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pagos vencidos y próximos 30 días',
                    style: TextStyle(color: KnotesTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SheetBody extends StatelessWidget {
  final Widget child;
  const SheetBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ContentWidth(
      width: 560,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(padding: EdgeInsets.all(20), child: child),
      ),
    ),
  );
}

void showFailure(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        error is String
            ? error
            : 'No se pudo guardar. Revisa los datos e inténtalo otra vez.',
      ),
    ),
  );
}
