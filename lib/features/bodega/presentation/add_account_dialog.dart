import '../../../core/models/currency_conversion.dart';
import '../../../core/theme/account_visuals.dart';
import '../../../core/widgets/currency_selector.dart';

import 'package:flutter/material.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/mvvm/view_model_state.dart';
import '../view_models/account_editor_view_model.dart';
import '../../../core/theme/kwall_theme.dart';
import '../models/account.dart';

class AddAccountDialog extends StatefulWidget {
  final String currency;
  final String initialType;
  final Account? account;
  const AddAccountDialog({
    super.key,
    this.currency = '\$',
    this.initialType = 'cash',
    this.account,
  });
  @override
  State<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState
    extends ViewModelState<AddAccountDialog, AccountEditorViewModel> {
  @override
  AccountEditorViewModel createViewModel(AppDependencies dependencies) =>
      dependencies.accountEditor();
  late final _name = TextEditingController(text: widget.account?.name ?? '');
  late final _balance = TextEditingController(
    text: widget.account?.balance.toStringAsFixed(2) ?? '0.00',
  );
  late final _minimum = TextEditingController(
    text: widget.account?.minimumBalance.toStringAsFixed(2) ?? '0.00',
  );
  late final _baseCurrency = TextEditingController(
    text: widget.account?.currency ?? widget.currency,
  );
  late final _target = TextEditingController(
    text: widget.account?.savingsTarget.toStringAsFixed(2) ?? '0.00',
  );
  late String _icon =
      widget.account?.iconKey ??
      (widget.initialType == 'vault' ? 'savings' : 'wallet');
  late int _color = widget.account?.colorValue ?? KwallTheme.accent.toARGB32();
  late String _type = widget.account?.type ?? widget.initialType;
  late bool _excludeFromAvailable =
      widget.account?.excludeFromAvailable ?? false;
  bool get _saving => model.busy;
  bool _savedSuccess = false;
  String? get _error => model.error;

  @override
  void dispose() {
    _target.dispose();
    _name.dispose();
    _balance.dispose();
    _minimum.dispose();
    _baseCurrency.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cur = _baseCurrency.text.trim().isEmpty
        ? widget.currency
        : _baseCurrency.text.trim();
    final saved = await model.save(
      original: widget.account,
      name: _name.text,
      balanceText: _balance.text,
      minimumText: _minimum.text,
      type: _type,
      currency: cur,
      currencies: widget.account?.currencies ?? [cur],
      color: _color,
      iconKey: _icon,
      targetText: _target.text,
      excludeFromAvailable: _excludeFromAvailable,
    );
    if (saved && mounted) {
      setState(() => _savedSuccess = true);
      await Future.delayed(const Duration(milliseconds: 320));
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _archive() async {
    if (await model.archive(widget.account!) && mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: Text(
          '¿Eliminar «${widget.account!.name}» de tus cuentas? Sus movimientos se conservarán. No podrás reactivarla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        mounted &&
        await model.delete(widget.account!) &&
        mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _adjust() async {
    final balance = TextEditingController(
      text: widget.account!.balance.toStringAsFixed(2),
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
                  'Saldo registrado: ${KwallTheme.formatCurrency(widget.account!.balance, widget.account!.currency)}',
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
                    prefixText:
                        '${CurrencyConversion.symbol(widget.account!.currency)} ',
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
                  Text(error!, style: TextStyle(color: KwallTheme.expenseRed)),
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
                        widget.account!,
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
    if (saved == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.account == null
                        ? 'Nueva cuenta'
                        : widget.account!.isArchived
                        ? 'Cuenta desactivada'
                        : 'Editar cuenta',
                    style: KwallTheme.fontTitle.copyWith(fontSize: 22),
                  ),
                ),
                if (widget.account != null)
                  PopupMenuButton<String>(
                    tooltip: 'Acciones de cuenta',
                    enabled: !_saving,
                    onSelected: (value) {
                      switch (value) {
                        case 'adjust':
                          _adjust();
                        case 'archive':
                          _archive();
                        case 'delete':
                          _delete();
                      }
                    },
                    itemBuilder: (_) => [
                      if (!widget.account!.isArchived)
                        const PopupMenuItem(
                          value: 'adjust',
                          child: Text('Ajustar saldo'),
                        ),
                      PopupMenuItem(
                        value: 'archive',
                        child: Text(
                          widget.account!.isArchived
                              ? 'Reactivar cuenta'
                              : 'Desactivar cuenta',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar cuenta'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              enabled: !_saving,
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nombre de la cuenta',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              icon: const Icon(Icons.expand_more_rounded),
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final type in {
                  'cash': 'Efectivo',
                  'bank': 'Banco',
                  'vault': 'Ahorro',
                  'credit': 'Crédito',
                }.entries)
                  DropdownMenuItem(value: type.key, child: Text(type.value)),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _type = value!),
            ),
            const SizedBox(height: 12),
            CurrencySelector(
              value: _baseCurrency.text,
              options: model.currencyOptions.isNotEmpty
                  ? (model.currencyOptions.contains(_baseCurrency.text)
                        ? model.currencyOptions.toSet()
                        : {
                            model.currencyOptions.first,
                            ...model.currencyOptions,
                          })
                  : {
                      _baseCurrency.text.trim().isNotEmpty
                          ? _baseCurrency.text.trim()
                          : widget.currency,
                    },
              currencyNames: model.currencyNames,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _baseCurrency.text = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _balance,
              readOnly: widget.account != null,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: widget.account == null
                    ? 'Saldo inicial'
                    : 'Saldo actual',
                prefixText: '${CurrencyConversion.symbol(_baseCurrency.text)} ',
                suffixIcon: widget.account != null
                    ? Tooltip(
                        message: 'Saldo calculado por movimientos',
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                          color: KwallTheme.textSecondary,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _minimum,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Reserva mínima',
                prefixText: '${CurrencyConversion.symbol(_baseCurrency.text)} ',
                prefixIcon: const Icon(Icons.shield_outlined),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Excluir del saldo libre'),
              subtitle: const Text(
                'Su saldo y sus pagos programados quedan fuera del disponible.',
              ),
              value: _excludeFromAvailable,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _excludeFromAvailable = value),
            ),
            if (_type == 'vault') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _target,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Meta de ahorro',
                  prefixText:
                      '${CurrencyConversion.symbol(_baseCurrency.text)} ',
                  helperText: '0 para ahorrar sin una meta fija',
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('Icono', style: KwallTheme.fontTitle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in accountIcons.entries)
                  IconButton.filledTonal(
                    tooltip: entry.value.$2,
                    isSelected: _icon == entry.key,
                    style: IconButton.styleFrom(
                      backgroundColor: _icon == entry.key
                          ? Color(_color).withValues(alpha: .2)
                          : null,
                    ),
                    onPressed: _saving
                        ? null
                        : () => setState(() => _icon = entry.key),
                    icon: Icon(entry.value.$1),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Color', style: KwallTheme.fontTitle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in <int, String>{
                  0xFF416543: 'Bosque',
                  0xFF805183: 'Ciruela',
                  0xFFA24768: 'Rosa',
                  0xFF886000: 'Miel',
                  0xFF336B87: 'Océano',
                  0xFFAD4D32: 'Terracota',
                  0xFF625B52: 'Piedra',
                  if (![
                    0xFF416543,
                    0xFF805183,
                    0xFFA24768,
                    0xFF886000,
                    0xFF336B87,
                    0xFFAD4D32,
                    0xFF625B52,
                  ].contains(_color))
                    _color: 'Actual',
                }.entries)
                  Semantics(
                    selected: _color == entry.key,
                    label: entry.value,
                    child: IconButton(
                      tooltip: entry.value,
                      onPressed: _saving
                          ? null
                          : () => setState(() => _color = entry.key),
                      icon: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(entry.key),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == entry.key
                                ? KwallTheme.textPrimary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(_error!, style: TextStyle(color: KwallTheme.expenseRed)),
            FilledButton.icon(
              onPressed: _saving || _savedSuccess ? null : _save,
              style: _savedSuccess
                  ? FilledButton.styleFrom(
                      backgroundColor: KwallTheme.incomeGreen,
                      foregroundColor: Colors.white,
                    )
                  : null,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _savedSuccess
                            ? Icons.check_circle_rounded
                            : Icons.save_outlined,
                        key: ValueKey(_savedSuccess),
                      ),
              ),
              label: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  _saving
                      ? 'Guardando…'
                      : _savedSuccess
                      ? 'Guardado'
                      : 'Guardar cuenta',
                  key: ValueKey('$_saving-$_savedSuccess'),
                ),
              ),
            ),
            if (widget.account != null) ...[
              const Divider(height: 32),
              if (!widget.account!.isArchived)
                OutlinedButton.icon(
                  onPressed: _saving ? null : _adjust,
                  icon: const Icon(Icons.balance_rounded),
                  label: const Text('Ajustar saldo'),
                ),
              TextButton.icon(
                onPressed: _saving ? null : _archive,
                icon: Icon(
                  widget.account!.isArchived
                      ? Icons.play_circle_outline
                      : Icons.pause_circle_outline,
                ),
                label: Text(
                  widget.account!.isArchived
                      ? 'Reactivar cuenta'
                      : 'Desactivar cuenta',
                ),
              ),
              TextButton.icon(
                onPressed: _saving ? null : _delete,
                style: TextButton.styleFrom(
                  foregroundColor: KwallTheme.expenseRed,
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Eliminar cuenta'),
              ),
            ],
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    ),
  );
}
