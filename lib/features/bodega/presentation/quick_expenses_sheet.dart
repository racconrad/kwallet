import '../../../core/models/currency_conversion.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/kwall_theme.dart';
import '../../../core/widgets/finance_widgets.dart';
import '../../../core/widgets/pet_visual_toast.dart';
import '../models/quick_expense.dart';
import '../view_models/home_view_model.dart';

class QuickExpensesSheet extends StatefulWidget {
  final HomeViewModel controller;

  const QuickExpensesSheet({super.key, required this.controller});

  @override
  State<QuickExpensesSheet> createState() => _QuickExpensesSheetState();
}

class _QuickExpensesSheetState extends State<QuickExpensesSheet> {
  HomeViewModel get _controller => widget.controller;

  IconData _iconFor(String key) => switch (key) {
    'food' => Icons.restaurant_rounded,
    'coffee' => Icons.coffee_rounded,
    'transport' => Icons.directions_bus_rounded,
    'potion' => Icons.water_drop_rounded,
    'game' => Icons.sports_esports_rounded,
    'gift' => Icons.card_giftcard_rounded,
    'home' => Icons.home_rounded,
    _ => Icons.flash_on_rounded,
  };

  Future<void> _execute(QuickExpense qe) async {
    HapticFeedback.lightImpact();
    final record = await _controller.logQuickExpense(
      title: qe.title,
      amount: qe.amount,
      categoryId: qe.categoryId,
      accountId: qe.accountId,
    );

    if (record != null && mounted) {
      Navigator.pop(context);
      final currency =
          _controller.accounts
              .where((a) => a.id == qe.accountId)
              .firstOrNull
              ?.currency ??
          _controller.currency;
      PetVisualToast.show(
        context,
        type: PetVisualToastType.expense,
        badgeValue: '-${KwallTheme.formatCurrency(qe.amount, currency)}',
      );
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          content: Text(
            '${qe.title} (${KwallTheme.formatCurrency(qe.amount, currency)}) registrado',
          ),
          action: SnackBarAction(
            label: 'Deshacer',
            textColor: KwallTheme.accent,
            onPressed: () => _controller.voidMovement(record),
          ),
        ),
      );
    }
  }

  void _openEditor([QuickExpense? item]) {
    final titleController = TextEditingController(text: item?.title ?? '');
    final amountController = TextEditingController(
      text: item?.amount.toString() ?? '',
    );
    String categoryId =
        item?.categoryId ??
        _controller.categories.values.firstOrNull?.id ??
        'cat_other';
    String? accountId = item?.accountId;
    String iconKey = item?.iconKey ?? 'bolt';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            item == null ? 'Nuevo gasto rápido' : 'Editar gasto rápido',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre / Título',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Monto',
                    prefixText:
                        '${CurrencyConversion.symbol(_controller.currency)} ',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: [
                    for (final cat in _controller.categories.values)
                      DropdownMenuItem(value: cat.id, child: Text(cat.name)),
                  ],
                  onChanged: (val) =>
                      setDialogState(() => categoryId = val ?? categoryId),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: accountId,
                  decoration: const InputDecoration(
                    labelText: 'Cuenta a debitar',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Cuenta principal'),
                    ),
                    for (final acc in _controller.accounts)
                      DropdownMenuItem(value: acc.id, child: Text(acc.name)),
                  ],
                  onChanged: (val) => setDialogState(() => accountId = val),
                ),
              ],
            ),
          ),
          actions: [
            if (item != null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _controller.deleteQuickExpense(item.id);
                  if (mounted) setState(() {});
                },
                child: Text(
                  'Eliminar',
                  style: TextStyle(color: KwallTheme.expenseRed),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final amt = double.tryParse(amountController.text) ?? 0.0;
                final title = titleController.text.trim();
                if (title.isEmpty || amt <= 0) return;
                Navigator.pop(ctx);
                await _controller.saveQuickExpense(
                  QuickExpense(
                    id: item?.id ?? const Uuid().v4(),
                    title: title,
                    amount: amt,
                    categoryId: categoryId,
                    accountId: accountId,
                    iconKey: iconKey,
                    createdAt: item?.createdAt ?? DateTime.now(),
                  ),
                );
                if (mounted) setState(() {});
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _controller.quickExpenses;

    return SheetBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on_rounded, color: KwallTheme.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gastos rápidos',
                  style: KwallTheme.fontTitle.copyWith(fontSize: 20),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Añadir gasto rápido',
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No hay gastos rápidos configurados.',
                  style: TextStyle(color: KwallTheme.textSecondary),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in list)
                  InputChip(
                    avatar: Icon(_iconFor(item.iconKey), size: 16),
                    label: Text(
                      '${item.title} (${KwallTheme.formatCurrency(item.amount, _controller.currency)})',
                    ),
                    onPressed: () => _execute(item),
                    onDeleted: () => _openEditor(item),
                    deleteIcon: const Icon(Icons.edit_outlined, size: 14),
                    deleteButtonTooltipMessage: 'Editar',
                  ),
              ],
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
