import 'package:flutter/material.dart';

import 'package:knotes/core/models/currency_conversion.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';

Future<(String, String)?> defineCurrency(
  BuildContext context, {
  Iterable<String> existing = const [],
}) => showModalBottomSheet<(String, String)>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _CurrencyDefinitionSheet(existing: existing),
);

class _CurrencyDefinitionSheet extends StatefulWidget {
  final Iterable<String> existing;
  const _CurrencyDefinitionSheet({required this.existing});

  @override
  State<_CurrencyDefinitionSheet> createState() =>
      _CurrencyDefinitionSheetState();
}

class _CurrencyDefinitionSheetState extends State<_CurrencyDefinitionSheet> {
  final _form = GlobalKey<FormState>();
  final _symbol = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _symbol.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SheetBody(
    child: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Añadir moneda',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _symbol,
            maxLength: 8,
            decoration: const InputDecoration(
              labelText: 'Símbolo',
              hintText: 'Ej. C\$, € o USD',
            ),
            validator: (value) {
              final symbol = value?.trim() ?? '';
              if (symbol.isEmpty ||
                  symbol.contains(',') ||
                  RegExp(r'\s').hasMatch(symbol)) {
                return 'Escribe un símbolo sin espacios ni comas.';
              }
              if (widget.existing.any(
                (c) =>
                    CurrencyConversion.code(c) ==
                    CurrencyConversion.code(symbol),
              )) {
                return 'Esta moneda ya está añadida.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej. Córdoba',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Escribe el nombre de la moneda.'
                : null,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              if (_form.currentState!.validate()) {
                Navigator.pop(context, (
                  _symbol.text.trim(),
                  _name.text.trim(),
                ));
              }
            },
            child: const Text('Añadir moneda'),
          ),
        ],
      ),
    ),
  );
}
