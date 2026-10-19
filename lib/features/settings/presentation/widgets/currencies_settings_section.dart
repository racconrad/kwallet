import '../../../../core/models/currency_conversion.dart';
import '../../../../core/widgets/currency_selector.dart';

import 'package:flutter/material.dart';

import '../../../../core/theme/kwall_theme.dart';
import 'currency_rate_dialog.dart';

class CurrenciesSettingsSection extends StatelessWidget {
  final TextEditingController dominantCurrencyController;
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
    final currentRate = rates[currency] ?? 1.0;

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

  void _promptAddCurrency(BuildContext context) {
    final symbolController = TextEditingController();
    final nameController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Añadir moneda'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: symbolController,
              decoration: const InputDecoration(
                labelText: 'Símbolo / Código *',
                hintText: 'Ej. €, C\$, MXN, USD',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la moneda (opcional)',
                hintText: 'Ej. Euro, Córdoba, Peso',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final symbol = symbolController.text.trim();
              final name = nameController.text.trim();
              if (symbol.isEmpty) return;
              Navigator.pop(ctx);
              if (onAddCurrency != null) {
                await onAddCurrency!(symbol, name);
              }
              if (context.mounted) {
                _openRateDialog(context, symbol, isNew: true);
              }
            },
            child: const Text('Siguiente'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dominant = dominantCurrencyController.text.trim().isEmpty
        ? '\$'
        : dominantCurrencyController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Monedas', style: KwallTheme.fontTitle.copyWith(fontSize: 21)),
        const SizedBox(height: 16),
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
          onChanged: (value) => dominantCurrencyController.text = value,
        ),
        const SizedBox(height: 14),
        Text(
          'Tipos de cambio',
          style: KwallTheme.fontTitle.copyWith(fontSize: 14),
        ),
        const SizedBox(height: 10),
        if (referenceCurrencies.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in referenceCurrencies)
                InputChip(
                  avatar: const Icon(Icons.currency_exchange_rounded, size: 16),
                  label: Text(
                    '${CurrencyConversion.label(c, currencyNames)}${rates.containsKey(c) ? ' (1 = ${rates[c]!.toStringAsFixed(rates[c]! % 1 == 0 ? 0 : 2)} ${CurrencyConversion.symbol(dominant)})' : ''}',
                  ),
                  onPressed: () => _openRateDialog(context, c),
                  onDeleted: () => onRemoveCurrency(c),
                  deleteIconColor: KwallTheme.textSecondary,
                  backgroundColor: KwallTheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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
