import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/core/mvvm/view_model_state.dart';
import 'package:knotes/features/journal/view_models/journal_actions_view_model.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/features/journal/models/journal_models.dart';
import 'package:knotes/features/journal/presentation/widgets/habit_time_block_selector.dart';

class HabitSheet extends StatefulWidget {
  final String initial;
  final Habit? habit;
  const HabitSheet({super.key, required this.initial, this.habit});
  @override
  State<HabitSheet> createState() => _HabitSheetState();
}

class _HabitSheetState
    extends ViewModelState<HabitSheet, JournalActionsViewModel> {
  @override
  JournalActionsViewModel createViewModel(AppDependencies dependencies) =>
      dependencies.journalActions();
  late final _title = TextEditingController(text: widget.initial);
  late String _iconKey = widget.habit?.iconKey ?? 'spa_rounded';
  late int _colorValue = widget.habit?.colorValue ?? 0xFF4CAF50;
  late String _timeBlock = widget.habit?.timeBlock ?? 'anytime';
  late String? _reminder = widget.habit?.reminderTime;
  late final Set<int> _days = {
    for (final d in (widget.habit?.reminderDays ?? '1234567').split(''))
      int.parse(d),
  };
  int _selectedCategoryIndex = 0;

  Future<void> _pickReminder() async {
    final parts = (_reminder ?? '20:00').split(':');
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 20,
        minute: int.tryParse(parts.last) ?? 0,
      ),
    );
    if (time != null && mounted) {
      setState(
        () => _reminder =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Match initial category if editing
    for (var i = 0; i < habitPalettes.length; i++) {
      if (habitPalettes[i].icons.any((ic) => ic.$1 == _iconKey) ||
          habitPalettes[i].colors.any((c) => c.$1 == _colorValue)) {
        _selectedCategoryIndex = i;
        break;
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPalette = habitPalettes[_selectedCategoryIndex];
    return SheetBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(_colorValue).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Color(_colorValue), width: 2),
                ),
                child: Icon(
                  getHabitIcon(_iconKey),
                  color: Color(_colorValue),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.habit == null ? 'Nuevo hábito' : 'Editar hábito',
                  style: KnotesTheme.fontTitle.copyWith(fontSize: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: '¿Qué quieres hacer cada día?',
              hintText: 'Caminar 15 minutos',
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Temática y estilo',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: KnotesTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < habitPalettes.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(habitPalettes[i].category),
                      selected: _selectedCategoryIndex == i,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategoryIndex = i;
                            _iconKey = habitPalettes[i].icons.first.$1;
                            _colorValue = habitPalettes[i].colors.first.$1;
                          });
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (iconKey, label) in currentPalette.icons)
                InkWell(
                  borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
                  onTap: () => setState(() => _iconKey = iconKey),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _iconKey == iconKey
                          ? Color(_colorValue).withValues(alpha: 0.2)
                          : KnotesTheme.surfaceContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
                      border: Border.all(
                        color: _iconKey == iconKey
                            ? Color(_colorValue)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Tooltip(
                      message: label,
                      child: Icon(
                        getHabitIcon(iconKey),
                        color: _iconKey == iconKey
                            ? Color(_colorValue)
                            : KnotesTheme.textSecondary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (colorVal, name) in currentPalette.colors)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(KnotesTheme.radiusMd),
                    onTap: () => setState(() => _colorValue = colorVal),
                    child: Tooltip(
                      message: name,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(colorVal),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _colorValue == colorVal
                                ? Colors.white
                                : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: _colorValue == colorVal
                              ? [
                                  BoxShadow(
                                    color: Color(colorVal)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: _colorValue == colorVal
                            ? const Icon(
                                Icons.check,
                                size: 18,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          HabitTimeBlockSelector(
            selected: _timeBlock,
            onChanged: (val) => setState(() => _timeBlock = val),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.alarm_rounded),
            title: const Text('Recordármelo cada día'),
            subtitle: Text(
              _reminder == null
                  ? 'No te avisa si ya lo marcaste ese día.'
                  : 'A las $_reminder · toca para cambiar la hora',
            ),
            value: _reminder != null,
            onChanged: (on) =>
                on ? _pickReminder() : setState(() => _reminder = null),
          ),
          if (_reminder != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _pickReminder,
                icon: const Icon(Icons.schedule_rounded),
                label: Text('Cambiar hora ($_reminder)'),
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (day, label) in const [
                  (1, 'L'),
                  (2, 'M'),
                  (3, 'X'),
                  (4, 'J'),
                  (5, 'V'),
                  (6, 'S'),
                  (7, 'D'),
                ])
                  FilterChip(
                    label: Text(label),
                    tooltip: DateFormat.EEEE('es')
                        .dateSymbols
                        .WEEKDAYS[day % 7],
                    showCheckmark: false,
                    selected: _days.contains(day),
                    onSelected: (on) =>
                        setState(() => on ? _days.add(day) : _days.remove(day)),
                  ),
              ],
            ),
          ],
          if (model.error != null) ...[
            const SizedBox(height: 8),
            Text(model.error!, style: TextStyle(color: KnotesTheme.expenseRed)),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: model.busy
                ? null
                : () async {
                    final saved = await model.saveHabit(
                      _title.text,
                      habit: widget.habit,
                      iconKey: _iconKey,
                      colorValue: _colorValue,
                      timeBlock: _timeBlock,
                      reminderTime: _reminder,
                      reminderDays: _reminder == null || _days.length == 7
                          ? null
                          : (_days.toList()..sort()).join(),
                    );
                    if (saved && context.mounted) Navigator.pop(context, true);
                  },
            child: const Text('Guardar hábito'),
          ),
        ],
      ),
    );
  }
}
