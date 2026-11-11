import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/core/mvvm/view_model_state.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/features/journal/models/journal_models.dart';
import 'package:knotes/features/journal/view_models/journal_actions_view_model.dart';

import 'package:knotes/features/journal/presentation/components/goal_kinds.dart';
import 'package:knotes/core/widgets/menu_label.dart';

class GoalSheet extends StatefulWidget {
  final Goal? goal;
  final List<Habit> habits;
  const GoalSheet({super.key, this.goal, required this.habits});
  @override
  State<GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState
    extends ViewModelState<GoalSheet, JournalActionsViewModel> {
  @override
  JournalActionsViewModel createViewModel(AppDependencies dependencies) =>
      dependencies.journalActions();

  static DateTime get _today => DateUtils.dateOnly(DateTime.now());
  late final _title = TextEditingController(text: widget.goal?.title ?? '');
  late final _target = TextEditingController(
    text: '${widget.goal?.target ?? 10}',
  );
  late String _kind = widget.goal?.kind ?? 'tasks';
  late String? _habitId = widget.goal?.habitId;
  late DateTime _start = widget.goal?.startDay ?? _today;
  late DateTime _end =
      widget.goal?.endDay ?? _today.add(const Duration(days: 6));
  late String? _reminder = widget.goal?.reminderTime;

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  void _window(int days) => setState(() {
    _start = _today;
    _end = _today.add(Duration(days: days - 1));
  });

  Future<void> _pickEnd() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: _start,
      lastDate: _today.add(const Duration(days: 366 * 3)),
    );
    if (date != null && mounted) setState(() => _end = date);
  }

  Future<void> _pickReminder() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 0),
    );
    if (time != null && mounted) {
      setState(
        () => _reminder =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _end.difference(_start).inDays + 1;
    return SheetBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.goal == null ? 'Nueva meta' : 'Editar meta',
            style: KnotesTheme.fontTitle.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej. Terminar 10 tareas',
            ),
          ),
          const Text('¿Qué cuenta?'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final MapEntry(key: kind, value: (icon, label))
                  in goalKinds.entries)
                ChoiceChip(
                  avatar: Icon(icon, size: 18),
                  label: Text(label),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() => _kind = kind),
                ),
            ],
          ),
          if (_kind == 'habits' && widget.habits.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              borderRadius: dropdownRadius,
              isExpanded: true,
              icon: const Icon(Icons.expand_more_rounded),
              initialValue: _habitId,
              decoration: const InputDecoration(labelText: 'Hábito'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: MenuLabel(
                    Icons.all_inclusive_rounded,
                    'Cualquier hábito',
                  ),
                ),
                for (final habit in widget.habits)
                  DropdownMenuItem(
                    value: habit.id,
                    child: MenuLabel(habit.icon, habit.title),
                  ),
              ],
              onChanged: (value) => setState(() => _habitId = value),
            ),
          ],
          if (_kind == 'manual')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Sumas uno con el botón + cada vez que lo cumplas.',
                style: TextStyle(color: KnotesTheme.textSecondary),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Cantidad'),
          ),
          const SizedBox(height: 12),
          Text('Plazo: $days ${days == 1 ? 'día' : 'días'}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (n, label) in [
                (7, '1 semana'),
                (14, '2 semanas'),
                (30, '1 mes'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _start == _today && days == n,
                  onSelected: (_) => _window(n),
                ),
              ActionChip(
                avatar: const Icon(Icons.event_outlined, size: 18),
                label: Text('Hasta ${DateFormat('d MMM', 'es').format(_end)}'),
                onPressed: _pickEnd,
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.alarm_rounded),
            title: const Text('Recordatorio diario'),
            subtitle: Text(
              _reminder == null
                  ? 'Te dice cuánto falta hasta lograrla.'
                  : 'A las $_reminder',
            ),
            value: _reminder != null,
            onChanged: (on) =>
                on ? _pickReminder() : setState(() => _reminder = null),
          ),
          if (model.error != null)
            Text(model.error!, style: TextStyle(color: KnotesTheme.expenseRed)),
          const SizedBox(height: 12),
          Row(
            children: [
              if (widget.goal != null)
                TextButton.icon(
                  onPressed: model.busy
                      ? null
                      : () async {
                          if (await model.deleteGoal(widget.goal!) &&
                              context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Eliminar'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: model.busy
                    ? null
                    : () async {
                        final saved = await model.saveGoal(
                          original: widget.goal,
                          title: _title.text,
                          kind: _kind,
                          habitId: _habitId,
                          target: int.tryParse(_target.text) ?? 0,
                          startDay: _start,
                          endDay: _end,
                          reminderTime: _reminder,
                        );
                        if (saved && context.mounted) Navigator.pop(context);
                      },
                child: const Text('Guardar meta'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
