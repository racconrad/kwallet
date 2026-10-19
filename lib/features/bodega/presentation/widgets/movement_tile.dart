import '../../../../core/theme/category_visuals.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/kwall_theme.dart';
import '../../../../core/widgets/finance_widgets.dart';
import '../../models/category_model.dart';
import '../../models/transaction_record.dart';

class MovementTile extends StatelessWidget {
  final TransactionRecord tx;
  final String currency;
  final Map<String, CategoryModel> categories;
  final Future<bool> Function(TransactionRecord) onVoid;
  const MovementTile({
    super.key,
    required this.tx,
    required this.currency,
    required this.categories,
    required this.onVoid,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: KwallTheme.accentLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        tx.isTransfer
            ? Icons.swap_horiz_rounded
            : categories[tx.categoryId]?.iconData ??
                  Icons.receipt_long_outlined,
        color: KwallTheme.accent,
      ),
    ),
    title: Text(
      tx.note.isEmpty
          ? categories[tx.categoryId]?.name ?? 'Movimiento'
          : tx.note,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: Text(DateFormat('dd MMM', 'es').format(tx.date)),
    trailing: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              '${tx.isNegative
                  ? '-'
                  : tx.isPositive
                  ? '+'
                  : ''}${KwallTheme.formatCurrency(tx.amount, tx.currency ?? currency)}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tx.isNegative
                    ? KwallTheme.expenseRed
                    : KwallTheme.incomeGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Anular movimiento',
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            onPressed: () async {
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
                if (confirmed != true) return;
                if (!await onVoid(tx) && context.mounted) {
                  showFailure(
                    context,
                    'No se pudo anular el movimiento. Reintenta.',
                  );
                }
              } catch (e) {
                if (context.mounted) showFailure(context, e);
              }
            },
          ),
        ],
      ),
    ),
  );
}
