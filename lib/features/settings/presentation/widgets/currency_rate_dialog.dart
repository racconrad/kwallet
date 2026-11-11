import 'package:knotes/core/models/currency_conversion.dart';

import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';

class CurrencyRateDialog extends StatefulWidget {
  final String currency;
  final String dominantCurrency;
  final double currentRate;
  final Future<List<Map<String, dynamic>>> Function(String currency)
  onFetchHistory;
  final Future<void> Function(double newRate, String notes) onSave;

  const CurrencyRateDialog({
    super.key,
    required this.currency,
    required this.dominantCurrency,
    required this.currentRate,
    required this.onFetchHistory,
    required this.onSave,
  });

  @override
  State<CurrencyRateDialog> createState() => _CurrencyRateDialogState();
}

class _CurrencyRateDialogState extends State<CurrencyRateDialog> {
  late final TextEditingController _rateController;
  final TextEditingController _notesController = TextEditingController();
  List<Map<String, dynamic>>? _history;
  bool _showHistory = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rateController = TextEditingController(
      text: widget.currentRate > 0 ? widget.currentRate.toString() : '1.0',
    );
  }

  @override
  void dispose() {
    _rateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final list = await widget.onFetchHistory(widget.currency);
    if (mounted) {
      setState(() {
        _history = list;
        _showHistory = true;
      });
    }
  }

  Future<void> _submit() async {
    final val = double.tryParse(
      _rateController.text.trim().replaceAll(',', '.'),
    );
    if (val == null || !val.isFinite || val <= 0) {
      setState(() => _error = 'Escribe una tasa mayor que cero.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(val, _notesController.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No se guardó la tasa. Reintenta.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Tasa: 1 ${CurrencyConversion.symbol(widget.currency)}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Text(
              '1 ${CurrencyConversion.symbol(widget.currency)} =',
              style: TextStyle(fontSize: 13, color: KnotesTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rateController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Tasa de conversión',
                suffixText: CurrencyConversion.symbol(widget.dominantCurrency),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Nota opcional',
                hintText: 'Ej. Ajuste de mercado',
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            if (!_showHistory)
              TextButton.icon(
                onPressed: _loadHistory,
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('Historial'),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Historial de tasas', style: KnotesTheme.fontTitle),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(() => _showHistory = false),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_history == null)
                const Center(child: CircularProgressIndicator())
              else if (_history!.isEmpty)
                Text(
                  'Sin cambios registrados aún.',
                  style: TextStyle(
                    fontSize: 12,
                    color: KnotesTheme.textSecondary,
                  ),
                )
              else
                ..._history!.map((entry) {
                  final base =
                      entry['base_currency'] as String? ??
                      widget.dominantCurrency;
                  final prev = (entry['previous_rate'] as num?)?.toDouble();
                  final next = (entry['new_rate'] as num?)?.toDouble() ?? 1.0;
                  final date = (entry['created_at'] as String? ?? '')
                      .replaceAll('T', ' ')
                      .split('.')
                      .first;
                  final notes = entry['notes'] as String? ?? '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: KnotesTheme.surfaceContainer.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prev == null
                                ? '1 = $next $base'
                                : '$prev → $next $base',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          if (notes.isNotEmpty)
                            Text(notes, style: const TextStyle(fontSize: 11)),
                          Text(
                            date,
                            style: TextStyle(
                              fontSize: 10,
                              color: KnotesTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
