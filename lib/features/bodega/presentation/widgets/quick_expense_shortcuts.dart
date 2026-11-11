import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/core/widgets/pet_visual_toast.dart';
import 'package:knotes/features/bodega/view_models/home_view_model.dart';

class QuickExpenseShortcuts extends StatelessWidget {
  final HomeViewModel controller;

  const QuickExpenseShortcuts({super.key, required this.controller});

  Future<void> _trigger(
    BuildContext context, {
    required String title,
    required double amount,
    required String categoryId,
    String? accountId,
  }) async {
    HapticFeedback.lightImpact();
    final record = await controller.logQuickExpense(
      title: title,
      amount: amount,
      categoryId: categoryId,
      accountId: accountId,
    );

    if (record != null && context.mounted) {
      final currency =
          controller.accounts.firstOrNull?.currency ?? controller.currency;
      PetVisualToast.show(
        context,
        type: PetVisualToastType.expense,
        badgeValue: '-${KnotesTheme.formatCurrency(amount, currency)}',
      );
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          content: Text(
            '$title (${KnotesTheme.formatCurrency(amount, currency)}) registrado',
          ),
          action: SnackBarAction(
            label: 'Deshacer',
            textColor: KnotesTheme.accent,
            onPressed: () {
              controller.voidMovement(record);
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = controller.quickExpenses;
    if (controller.accounts.isEmpty || shortcuts.isEmpty) {
      return const SizedBox.shrink();
    }

    final currency =
        controller.accounts.firstOrNull?.currency ?? controller.currency;

    return LedgerPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on_rounded, size: 18, color: KnotesTheme.accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Gastos rápidos (1 toque)',
                  overflow: TextOverflow.ellipsis,
                  style: KnotesTheme.fontTitle.copyWith(fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in shortcuts) ...[
                  ActionChip(
                    avatar: Icon(
                      Icons.bolt_rounded,
                      size: 15,
                      color: KnotesTheme.accent,
                    ),
                    label: Text(
                      '${item.title} (${KnotesTheme.formatCurrency(item.amount, currency)})',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: KnotesTheme.textPrimary,
                      ),
                    ),
                    backgroundColor: KnotesTheme.surfaceContainer.withValues(
                      alpha: 0.7,
                    ),
                    side: BorderSide(
                      color: KnotesTheme.border.withValues(alpha: 0.35),
                    ),
                    onPressed: () => _trigger(
                      context,
                      title: item.title,
                      amount: item.amount,
                      categoryId: item.categoryId,
                      accountId: item.accountId,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
