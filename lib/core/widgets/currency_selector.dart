import 'package:flutter/material.dart';

import '../models/currency_conversion.dart';

class CurrencySelector extends StatelessWidget {
  final String value;
  final Iterable<String> options;
  final Map<String, String>? currencyNames;
  final ValueChanged<String>? onChanged;
  final String label;

  const CurrencySelector({
    super.key,
    required this.value,
    required this.options,
    this.currencyNames,
    this.onChanged,
    this.label = 'Moneda',
  });

  @override
  Widget build(BuildContext context) {
    final selected = CurrencyConversion.code(value);
    final codes = {
      selected,
      ...options.map(CurrencyConversion.code),
    }.where((s) => s.isNotEmpty).toList()..sort();
    return DropdownButtonFormField<String>(
      key: ValueKey('$selected:${codes.join(',')}'),
      initialValue: selected,
      isExpanded: true,
      icon: const Icon(Icons.expand_more_rounded),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.payments_outlined),
      ),
      items: [
        for (final code in codes)
          DropdownMenuItem(
            value: code,
            child: Text(
              CurrencyConversion.label(code, currencyNames),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged == null
          ? null
          : (value) {
              if (value != null) onChanged!(value);
            },
    );
  }
}
