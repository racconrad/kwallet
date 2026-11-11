import 'package:flutter/material.dart';

import 'package:knotes/core/models/currency_conversion.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/features/bodega/models/account.dart';
import 'package:knotes/features/bodega/view_models/account_editor_view_model.dart';

Future<bool?> adjustAccountBalance(
  BuildContext context, {
  required Account account,
  required AccountEditorViewModel model,
}) async {
  final balance = TextEditingController(
    text: account.balance.toStringAsFixed(2),
  );
  final reason = TextEditingController();
  bool saving = false;
  String? error;
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => AlertDialog(
        title: const Text('Ajustar saldo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Saldo registrado: ${KnotesTheme.formatCurrency(account.balance, account.currency)}',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: balance,
                enabled: !saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Saldo real',
                  prefixText: '${CurrencyConversion.symbol(account.currency)} ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'Motivo del ajuste',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'La diferencia quedará en el historial como ajuste de saldo.',
              ),
              if (error != null)
                Text(error!, style: TextStyle(color: KnotesTheme.expenseRed)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    update(() => saving = true);
                    final ok = await model.adjust(
                      account,
                      balance.text,
                      reason.text,
                    );
                    if (!ctx.mounted) return;
                    if (ok) {
                      Navigator.pop(ctx, true);
                    } else {
                      update(() {
                        saving = false;
                        error = model.error;
                      });
                    }
                  },
            child: Text(saving ? 'Guardando…' : 'Guardar ajuste'),
          ),
        ],
      ),
    ),
  );
  // Dialog route finishes its reverse transition before releasing controllers.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  balance.dispose();
  reason.dispose();
  return saved;
}
