import 'package:knotes/features/bodega/presentation/components/account_balance_adjustment.dart';
import 'package:knotes/core/models/currency_conversion.dart';
import 'package:knotes/core/theme/account_visuals.dart';
import 'package:knotes/core/widgets/currency_selector.dart';
import 'package:knotes/core/widgets/currency_definition_sheet.dart';

import 'package:flutter/material.dart';

import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/core/mvvm/view_model_state.dart';
import 'package:knotes/features/bodega/view_models/account_editor_view_model.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/features/bodega/models/account.dart';
import 'package:knotes/core/widgets/menu_label.dart';

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
  late int _color = widget.account?.colorValue ?? KnotesTheme.accent.toARGB32();
  late String _type = widget.account?.type ?? widget.initialType;
  late bool _excludeFromAvailable =
      widget.account?.excludeFromAvailable ?? false;
  bool get _saving => model.busy;
  bool _savedSuccess = false;
  bool _currenciesInitialized = false;

  @override
  void onViewModelChanged() {
    if (!_currenciesInitialized && model.currenciesReady) {
      if (widget.account == null &&
          !model.currencyOptions.any(
            (c) =>
                CurrencyConversion.code(c) ==
                CurrencyConversion.code(_baseCurrency.text),
          )) {
        _baseCurrency.text = model.currencyOptions.firstOrNull ?? '';
      }
      _currenciesInitialized = true;
    }
  }

  Future<void> _addCurrency() async {
    final value = await defineCurrency(
      context,
      existing: model.currencyNames.keys,
    );
    if (value == null || !mounted) return;
    if (await model.addCurrency(value.$1, value.$2) && mounted) {
      setState(() => _baseCurrency.text = value.$1);
    }
  }

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
    final cur = _baseCurrency.text.trim();
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
    final saved = await adjustAccountBalance(
      context,
      account: widget.account!,
      model: model,
    );
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
                    style: KnotesTheme.fontTitle.copyWith(fontSize: 22),
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
                        menuItem('adjust', Icons.tune_rounded, 'Ajustar saldo'),
                      widget.account!.isArchived
                          ? menuItem(
                              'archive',
                              Icons.unarchive_outlined,
                              'Reactivar cuenta',
                            )
                          : menuItem(
                              'archive',
                              Icons.archive_outlined,
                              'Desactivar cuenta',
                            ),
                      menuItem(
                        'delete',
                        Icons.delete_outline_rounded,
                        'Eliminar cuenta',
                        danger: true,
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
              borderRadius: dropdownRadius,
              isExpanded: true,
              icon: const Icon(Icons.expand_more_rounded),
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final type in {
                  'cash': (Icons.payments_outlined, 'Efectivo'),
                  'bank': (Icons.account_balance_outlined, 'Banco'),
                  'vault': (Icons.savings_outlined, 'Ahorro'),
                  'credit': (Icons.credit_card_rounded, 'Crédito'),
                }.entries)
                  DropdownMenuItem(
                    value: type.key,
                    child: MenuLabel(type.value.$1, type.value.$2),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _type = value!),
            ),
            const SizedBox(height: 12),
            if (_baseCurrency.text.isNotEmpty &&
                (model.currencyOptions.isNotEmpty || widget.account != null))
              CurrencySelector(
                value: _baseCurrency.text,
                options: {
                  ...model.currencyOptions,
                  if (widget.account != null) widget.account!.currency,
                },
                currencyNames: model.currencyNames,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _baseCurrency.text = value),
              ),
            OutlinedButton.icon(
              onPressed: _saving ? null : _addCurrency,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Añadir moneda'),
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
                          color: KnotesTheme.textSecondary,
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
            Text('Icono', style: KnotesTheme.fontTitle),
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
            Text('Color', style: KnotesTheme.fontTitle),
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
                                ? KnotesTheme.textPrimary
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
              Text(_error!, style: TextStyle(color: KnotesTheme.expenseRed)),
            FilledButton.icon(
              onPressed: _saving || _savedSuccess ? null : _save,
              style: _savedSuccess
                  ? FilledButton.styleFrom(
                      backgroundColor: KnotesTheme.incomeGreen,
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
                  foregroundColor: KnotesTheme.expenseRed,
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
