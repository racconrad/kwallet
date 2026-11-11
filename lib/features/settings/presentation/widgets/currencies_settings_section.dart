import 'package:knotes/core/models/currency_conversion.dart';
import 'package:knotes/core/widgets/currency_selector.dart';
import 'package:knotes/core/widgets/currency_definition_sheet.dart';

import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/features/settings/presentation/widgets/currency_rate_dialog.dart';

class CurrenciesSettingsSection extends StatelessWidget {
  final TextEditingController dominantCurrencyController;
  final ValueChanged<String>? onPrimaryChanged;
  final List<String> referenceCurrencies;
  final Map<String, double> rates;
  final Map<String, String>? currencyNames;
  final Future<void> Function(String symbol, String name)? onAddCurrency;
  final Future<void> Function(String currency, double rate, String notes)
  onSaveRate;
  final Future<void> Function(String currency) onRemoveCurrency;
  final Future<List<Map<String, dynamic>>> Function(String currency)
  onFetchHistory;

  const CurrenciesSettingsSection({
    super.key,
    required this.dominantCurrencyController,
    this.onPrimaryChanged,
    required this.referenceCurrencies,
    required this.rates,
    this.currencyNames,
    this.onAddCurrency,
    required this.onSaveRate,
    required this.onRemoveCurrency,
    required this.onFetchHistory,
  });

  void _openRateDialog(
    BuildContext context,
    String currency, {
    bool isNew = false,
  }) {
    final dominant = dominantCurrencyController.text.trim().isEmpty
        ? '\$'
        : dominantCurrencyController.text.trim();
    final currentRate =
        rates[CurrencyConversion.code(currency)] ?? rates[currency] ?? 1.0;

    showDialog<void>(
      context: context,
      builder: (ctx) => CurrencyRateDialog(
        currency: currency,
        dominantCurrency: dominant,
        currentRate: currentRate,
        onFetchHistory: onFetchHistory,
        onSave: (newRate, notes) => onSaveRate(currency, newRate, notes),
      ),
    );
  }

  Future<void> _promptAddCurrency(BuildContext context) async {
    final result = await defineCurrency(
      context,
      existing: currencyNames?.keys ?? const [],
    );
    if (result == null || onAddCurrency == null) return;
    try {
      await onAddCurrency!(result.$1, result.$2);
      if (context.mounted &&
          dominantCurrencyController.text.isNotEmpty &&
          CurrencyConversion.code(dominantCurrencyController.text) !=
              CurrencyConversion.code(result.$1)) {
        _openRateDialog(context, result.$1, isNew: true);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar la moneda. Inténtalo otra vez.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dominant = dominantCurrencyController.text.trim().isEmpty
        ? '\$'
        : dominantCurrencyController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Monedas', style: KnotesTheme.fontTitle.copyWith(fontSize: 21)),
        const SizedBox(height: 16),
        if (dominantCurrencyController.text.isNotEmpty)
          CurrencySelector(
            value: dominantCurrencyController.text,
            options: {
              if (dominantCurrencyController.text.trim().isNotEmpty)
                dominantCurrencyController.text.trim(),
              ...referenceCurrencies.where((s) => s.trim().isNotEmpty),
              if (currencyNames != null)
                ...currencyNames!.keys.where((s) => s.trim().isNotEmpty),
            }.toSet(),
            currencyNames: currencyNames,
            label: 'Moneda principal',
            onChanged:
                onPrimaryChanged ??
                (value) => dominantCurrencyController.text = value,
          ),
        const SizedBox(height: 14),
        const Text(
          'La moneda principal se usa para mostrar tus totales. Tus cuentas conservan su moneda y saldo; sus movimientos no cambian. Los presupuestos y planes sin cuenta se convierten con la tasa guardada.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Antes de cambiarla, configura su tasa respecto a la principal actual.',
        ),
        Text(
          'Tipos de cambio',
          style: KnotesTheme.fontTitle.copyWith(fontSize: 14),
        ),
        const SizedBox(height: 10),
        if (referenceCurrencies.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in referenceCurrencies.where(
                (c) =>
                    CurrencyConversion.code(c) !=
                    CurrencyConversion.code(dominant),
              ))
                InputChip(
                  avatar: const Icon(Icons.currency_exchange_rounded, size: 16),
                  label: Text(
                    '${CurrencyConversion.label(c, currencyNames)}${rates.containsKey(CurrencyConversion.code(c)) ? ' (1 = ${rates[CurrencyConversion.code(c)]!.toStringAsFixed(2)} ${CurrencyConversion.symbol(dominant)})' : ''}',
                  ),
                  onPressed: () => _openRateDialog(context, c),
                  onDeleted: () => onRemoveCurrency(c),
                  deleteIconColor: KnotesTheme.textSecondary,
                  backgroundColor: KnotesTheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _promptAddCurrency(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Añadir moneda'),
        ),
      ],
    );
  }
}
