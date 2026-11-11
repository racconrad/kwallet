part of 'launch_screen.dart';

const _accountTypes = {
  'cash': (Icons.payments_outlined, 'Efectivo'),
  'bank': (Icons.account_balance_outlined, 'Banco'),
  'vault': (Icons.savings_outlined, 'Ahorro'),
  'credit': (Icons.credit_card_rounded, 'Crédito'),
};

const _habitIdeas = {
  'Beber agua': Icons.water_drop_outlined,
  'Leer 10 minutos': Icons.menu_book_outlined,
  'Caminar': Icons.directions_walk_rounded,
  'Respirar': Icons.self_improvement_rounded,
};

/// The page content for each welcome step, plus small shared builders.
extension _LaunchSteps on _LaunchScreenState {
  List<Widget> _content() => switch (_step) {
    _Step.box => [
      _title(
        _opened ? '¡Aquí está tu compañero!' : 'Hay alguien\nesperándote.',
      ),
      _caption(
        _opened
            ? 'Se han encontrado por sorpresa.'
            : 'Toca la caja para conocerle.',
      ),
      const SizedBox(height: 24),
      AdoptionBox(opened: _opened, settings: _petSettings, onOpen: _openBox),
      const SizedBox(height: 24),
      _caption('Un pequeño compañero para tus días.'),
    ],
    _Step.name => [
      _title('¿Cómo se llamará?'),
      AdoptionScene(
        settings: _petSettings,
        greeted: _greeted,
        onGreet: () => _update(() => _greeted = true),
      ),
      if (_greeted) _caption('Ya te reconoce.'),
      TextField(
        controller: _petName,
        maxLength: 20,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Su nombre',
          prefixIcon: Icon(Icons.badge_outlined),
        ),
        onChanged: (_) => _update(() => _validationError = null),
      ),
      const SizedBox(height: 4),
      TextButton.icon(
        onPressed: () => _update(() => _advanced = !_advanced),
        icon: Icon(
          _advanced ? Icons.expand_less_rounded : Icons.palette_outlined,
        ),
        label: Text(
          _advanced ? 'Cerrar personalización' : 'Personalización avanzada',
        ),
      ),
      if (_advanced)
        AdoptionPicker(
          selected: _style,
          onChanged: (style) => _update(() => _style = style),
        ),
      const SizedBox(height: 12),
      _caption('Su nombre y aspecto se pueden cambiar después.'),
    ],
    _Step.tour => [
      const StepBadge(Icons.explore_rounded),
      _title('Así funciona knotes'),
      _caption(
        'Soy $_name. knotes tiene tres áreas que trabajan juntas; cada paso que das en ellas me ayuda a crecer.',
      ),
      const SizedBox(height: 16),
      InfoRow(
        Icons.account_balance_wallet_outlined,
        'Dinero',
        'Cuentas, gastos, presupuesto y pagos. Te digo cuánto tienes libre de verdad.',
      ),
      InfoRow(
        Icons.local_fire_department_outlined,
        'Hábitos',
        'Marca lo que haces cada día, cuida tus rachas y ponte metas con plazo.',
        color: KnotesTheme.pop,
      ),
      InfoRow(
        Icons.sticky_note_2_outlined,
        'Notas',
        'Ideas y listas. Una línea es una nota; «- algo» es una tarea.',
        color: KnotesTheme.warningAmber,
      ),
    ],
    _Step.path => [
      const StepBadge(Icons.alt_route_rounded),
      _title('¿Cómo quieres empezar?'),
      _caption('Elige un camino. Todo se puede cambiar después.'),
      const SizedBox(height: 20),
      ChoiceTile(
        icon: Icons.bolt_rounded,
        title: 'Inicio rápido · 1 minuto',
        body: 'Solo tu moneda y tu primera cuenta.',
        selected: !_long,
        onTap: () => _update(() => _long = false),
      ),
      const SizedBox(height: 12),
      ChoiceTile(
        icon: Icons.map_outlined,
        title: 'Recorrido completo · 3 minutos',
        body: 'También gastos frecuentes, un hábito y tu primera nota.',
        selected: _long,
        onTap: () => _update(() => _long = true),
      ),
      const SizedBox(height: 20),
      _caption('Lo que viene:'),
      const SizedBox(height: 8),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final step in _steps.skip(_index + 1))
            Chip(avatar: Icon(step.icon, size: 18), label: Text(step.label)),
        ],
      ),
    ],
    _Step.currency => [
      const StepBadge(Icons.currency_exchange_rounded),
      _title('¿Con qué moneda?'),
      _caption(
        'La principal se usa en tus totales. Cada cuenta conserva su propia moneda.',
      ),
      const SizedBox(height: 20),
      for (final entry in _currencies.entries) ...[
        ChoiceTile(
          icon: Icons.payments_outlined,
          title: CurrencyConversion.symbol(entry.key),
          body: entry.value.isEmpty ? null : entry.value,
          selected: _currency == entry.key,
          onTap: () => _update(() => _currency = entry.key),
        ),
        const SizedBox(height: 10),
      ],
      OutlinedButton.icon(
        onPressed: _addCurrency,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          _currencies.isEmpty ? 'Añadir mi moneda' : 'Añadir otra moneda',
        ),
      ),
      if (_currencies.length > 1) ...[
        const SizedBox(height: 12),
        _caption('Las tasas entre monedas se configuran en Ajustes.'),
      ],
    ],
    _Step.account => [
      const StepBadge(Icons.account_balance_wallet_rounded),
      _title('Tu primera cuenta'),
      _caption('$_name te acompaña. Empieza con el dinero que tienes hoy.'),
      if (_currency.isEmpty) ...[
        const SizedBox(height: 12),
        InfoRow(
          Icons.currency_exchange_rounded,
          'Falta tu moneda',
          'Elige una para crear la cuenta, o omite este paso.',
          color: KnotesTheme.warningAmber,
        ),
        TextButton.icon(
          onPressed: () => _go(_steps.indexOf(_Step.currency)),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Elegir moneda'),
        ),
      ],
      const SizedBox(height: 20),
      Text('Tipo de cuenta', style: KnotesTheme.fontTitle),
      const SizedBox(height: 10),
      _accountTypeGrid(),
      const SizedBox(height: 20),
      Form(
        key: _accountForm,
        child: Column(
          children: [
            TextFormField(
              controller: _accountName,
              maxLength: 40,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nombre de la cuenta',
                hintText: 'Ej. Mi efectivo',
                prefixIcon: Icon(_accountTypes[_accountType]!.$1),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Escribe un nombre o elige Omitir por ahora.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _balance,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: 'Saldo inicial',
                prefixIcon: const Icon(Icons.account_balance_outlined),
                prefixText: _currency.isEmpty
                    ? null
                    : '${CurrencyConversion.symbol(_currency)} ',
                helperText: 'Déjalo vacío para empezar en cero.',
                helperMaxLines: 2,
              ),
              validator: (v) =>
                  v == null ||
                      v.trim().isEmpty ||
                      (_parseAmount(v)?.isFinite == true)
                  ? null
                  : 'Escribe un saldo válido.',
            ),
          ],
        ),
      ),
    ],
    _Step.expenses => [
      const StepBadge(Icons.bolt_rounded),
      _title('Los gastos que se repiten'),
      _caption(
        'Guarda tus gastos hormiga como atajos. Tu saldo aún no cambia.',
      ),
      const SizedBox(height: 20),
      if (!_hasAccount) ...[
        InfoRow(
          Icons.account_balance_wallet_outlined,
          'Primero, una cuenta',
          'Podrás añadir estos gastos cuando tengas una cuenta.',
          color: KnotesTheme.warningAmber,
        ),
        TextButton(
          onPressed: () => _go(_steps.indexOf(_Step.account)),
          child: const Text('Añadir una cuenta ahora'),
        ),
      ] else ...[
        for (final expense in _expenses)
          _addedRow(
            Icons.bolt_rounded,
            expense.title,
            '${CurrencyConversion.symbol(_currency)} ${expense.amount}',
            () => _update(() => _expenses.remove(expense)),
          ),
        Form(
          key: _expenseForm,
          child: Column(
            children: [
              TextFormField(
                controller: _expenseTitle,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Nombre del gasto',
                  prefixIcon: Icon(Icons.local_cafe_outlined),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Escribe un nombre.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _expenseAmount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Importe',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  prefixText: '${CurrencyConversion.symbol(_currency)} ',
                ),
                validator: (v) {
                  final n = _parseAmount(v ?? '');
                  return n != null && n.isFinite && n > 0
                      ? null
                      : 'Escribe un importe mayor que cero.';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryName,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  hintText: 'Escribe cómo quieres agruparlo',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Ponle un nombre a la categoría.'
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _addExpense,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Añadir gasto hormiga'),
        ),
      ],
    ],
    _Step.habits => [
      _title('Un hábito a la vez'),
      AdoptionScene(settings: _petSettings, activity: PetActivity.curious),
      _caption('Elige algo pequeño. Cada día que lo marcas suma a tu racha.'),
      const SizedBox(height: 16),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final idea in _habitIdeas.entries)
            ActionChip(
              avatar: Icon(idea.value, size: 18),
              label: Text(idea.key),
              onPressed: _habits.containsValue(idea.key)
                  ? null
                  : () => _update(() => _habits[const Uuid().v4()] = idea.key),
            ),
        ],
      ),
      const SizedBox(height: 16),
      for (final entry in _habits.entries)
        _addedRow(
          Icons.local_fire_department_outlined,
          entry.value,
          'Cada día',
          () => _update(() => _habits.remove(entry.key)),
        ),
      TextField(
        controller: _habitTitle,
        maxLength: 80,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Mi hábito',
          prefixIcon: Icon(Icons.edit_outlined),
        ),
        onSubmitted: (_) => _addHabit(),
      ),
      OutlinedButton.icon(
        onPressed: _addHabit,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Añadir hábito'),
      ),
      const SizedBox(height: 16),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: const IconTile(Icons.notifications_none_rounded),
        title: const Text('Recordatorios'),
        subtitle: const Text(
          'Solo si tú quieres. También puedes activarlos después.',
        ),
        value: _notifications,
        onChanged: _requestingPermission ? null : _permission,
      ),
      if (_notifications && _habits.isNotEmpty)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const IconTile(Icons.alarm_rounded),
          title: const Text('Recordarme mis hábitos'),
          subtitle: Text(
            _habitReminder == null
                ? 'Sin hora'
                : 'Cada día a las $_habitReminder',
          ),
          trailing: TextButton(
            onPressed: _pickHabitReminder,
            child: const Text('Cambiar'),
          ),
        ),
    ],
    _Step.notes => [
      _title('Tu primera nota'),
      AdoptionScene(settings: _petSettings, activity: PetActivity.relax),
      _caption(
        'La primera línea es el título; cada «- algo» se vuelve una tarea.',
      ),
      const SizedBox(height: 16),
      for (final note in _notes)
        _addedRow(
          Icons.sticky_note_2_outlined,
          note.split('\n').first,
          '${note.split('\n').where((l) => l.trim().startsWith('-')).length} tareas',
          () => _update(() => _notes.remove(note)),
        ),
      TextField(
        controller: _noteText,
        minLines: 3,
        maxLines: 6,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Mi nota',
          hintText: 'Esta semana\n- pagar la luz\n- llamar a mamá',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _addNote,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Añadir nota'),
      ),
    ],
    _Step.review => [
      _title('Bienvenido a casa,\n$_name.'),
      AdoptionScene(
        settings: _petSettings,
        activity: PetActivity.celebrate,
        greeted: true,
      ),
      _caption('Tu espacio está listo. Puedes cambiarlo todo a tu ritmo.'),
      const SizedBox(height: 16),
      if (_currency.isNotEmpty)
        InfoRow(
          Icons.currency_exchange_rounded,
          'Moneda ${CurrencyConversion.symbol(_currency)}',
          _currencies.length > 1
              ? 'Y ${_currencies.length - 1} más para tus cuentas.'
              : 'La usarás en tus totales.',
        ),
      if (_hasAccount)
        InfoRow(
          _accountTypes[_accountType]!.$1,
          _accountName.text.trim(),
          'Saldo inicial: ${CurrencyConversion.symbol(_currency)} ${_balance.text.trim().isEmpty ? '0' : _balance.text.trim()}',
        ),
      if (_expenses.isNotEmpty)
        InfoRow(
          Icons.bolt_rounded,
          _expenses.length == 1
              ? '1 gasto hormiga'
              : '${_expenses.length} gastos hormiga',
          'Listos para usarlos cuando gastes.',
        ),
      if (_habits.isNotEmpty)
        InfoRow(
          Icons.local_fire_department_outlined,
          _habits.length == 1 ? '1 hábito' : '${_habits.length} hábitos',
          _notifications && _habitReminder != null
              ? 'Te lo recuerdo a las $_habitReminder.'
              : 'Un pequeño paso cada día.',
          color: KnotesTheme.pop,
        ),
      if (_notes.isNotEmpty)
        InfoRow(
          Icons.sticky_note_2_outlined,
          _notes.length == 1 ? '1 nota' : '${_notes.length} notas',
          'Las verás en el área de Notas.',
          color: KnotesTheme.warningAmber,
        ),
      if (!_long)
        const InfoRow(
          Icons.explore_outlined,
          'Lo demás, a tu ritmo',
          'Hábitos, metas y notas te esperan en Inicio cuando quieras.',
        ),
      const SizedBox(height: 16),
      _caption('Tus datos se guardan en tu teléfono.'),
    ],
  };

  Widget _accountTypeGrid() {
    final types = _accountTypes.entries.toList();
    Widget tile(MapEntry<String, (IconData, String)> type) => Expanded(
      child: ChoiceTile(
        icon: type.value.$1,
        title: type.value.$2,
        selected: _accountType == type.key,
        onTap: () => _update(() => _accountType = type.key),
      ),
    );
    return Column(
      children: [
        for (var i = 0; i < types.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                tile(types[i]),
                const SizedBox(width: 10),
                tile(types[i + 1]),
              ],
            ),
          ),
      ],
    );
  }

  Widget _addedRow(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onRemove,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: IconTile(icon, filled: true),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: IconButton(
      tooltip: 'Quitar $title',
      onPressed: onRemove,
      icon: const Icon(Icons.close_rounded),
    ),
  );

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineLarge
          ?.merge(KnotesTheme.fontDisplay),
    ),
  );

  Widget _caption(String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.bodyLarge
        ?.copyWith(color: KnotesTheme.textSecondary),
  );
}
