import 'package:flutter/material.dart';

import 'package:knotes/core/models/currency_conversion.dart';
import 'package:knotes/core/widgets/menu_label.dart';

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
      borderRadius: dropdownRadius,
      key: ValueKey('$selected:${codes.join(',')}'),
      initialValue: selected,
      isExpanded: true,
      icon: const Icon(Icons.expand_more_rounded),
      decoration: InputDecoration(labelText: label),
      items: [
        for (final code in codes)
          DropdownMenuItem(
            value: code,
            child: MenuLabel(
              Icons.payments_outlined,
              CurrencyConversion.label(code, currencyNames),
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
