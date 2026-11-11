import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/core/mvvm/view_model_state.dart';
import 'package:knotes/features/journal/view_models/journal_actions_view_model.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/features/journal/models/journal_models.dart';
import 'package:knotes/features/journal/presentation/journal_sheets.dart';

class HabitDaysSheet extends StatefulWidget {
  final Habit habit;
  final DateTime initialDay;
  const HabitDaysSheet({
    super.key,
    required this.habit,
    required this.initialDay,
  });
  @override
  State<HabitDaysSheet> createState() => _HabitDaysSheetState();
}

class _HabitDaysSheetState
    extends ViewModelState<HabitDaysSheet, JournalActionsViewModel> {
  @override
  JournalActionsViewModel createViewModel(AppDependencies dependencies) =>
      dependencies.journalActions();
  late DateTime _month = DateTime(
    widget.initialDay.year,
    widget.initialDay.month,
  );
  late final Set<String> _selected = {dayKey(widget.initialDay)};
  bool _completed = true;
  bool get _saving => model.busy;
  String _mood = 'neutral';
  final _reason = TextEditingController();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await model.markDays(
      [widget.habit.id],
      _selected.map(DateTime.parse),
      completed: _completed,
      mood: _completed ? 'happy' : _mood,
      reason: _reason.text,
    );
    if (!mounted) return;
    if (saved) {
      HapticFeedback.lightImpact();
      Navigator.pop(context);
    } else {
      showFailure(context, model.error ?? 'No se pudieron guardar tus días.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final count = DateUtils.getDaysInMonth(_month.year, _month.month);
    final offset = _month.weekday - 1;
    return SheetBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.habit.title,
            style: KnotesTheme.fontTitle.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 8),
          Text(
            'Elige tus días',
            style: TextStyle(color: KnotesTheme.textSecondary),
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Mes anterior',
                onPressed: _saving
                    ? null
                    : () => setState(
                        () => _month = DateTime(_month.year, _month.month - 1),
                      ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy', 'es').format(_month),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                onPressed:
                    _saving ||
                        DateTime(_month.year, _month.month + 1).isAfter(today)
                    ? null
                    : () => setState(
                        () => _month = DateTime(_month.year, _month.month + 1),
                      ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              for (final label in ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: KnotesTheme.textSecondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: offset + count,
            itemBuilder: (_, index) {
              if (index < offset) return const SizedBox.shrink();
              final date = DateTime(
                _month.year,
                _month.month,
                index - offset + 1,
              );
              final key = dayKey(date);
              final selected = _selected.contains(key);
              final future = date.isAfter(today);
              final log = widget.habit.logFor(date);
              return Semantics(
                selected: selected,
                label: DateFormat('d MMMM', 'es').format(date),
                child: Material(
                  color: selected
                      ? KnotesTheme.accent
                      : KnotesTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
                    onTap: future || _saving
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (!_selected.add(key)) _selected.remove(key);
                            });
                          },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? KnotesTheme.onAccent
                                : future
                                ? KnotesTheme.textSecondary.withValues(
                                    alpha: .45,
                                  )
                                : KnotesTheme.textPrimary,
                          ),
                        ),
                        if (log != null)
                          Icon(
                            log.completed
                                ? Icons.check_rounded
                                : Icons.remove_rounded,
                            size: 12,
                            color: selected
                                ? KnotesTheme.onAccent
                                : KnotesTheme.accent,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Lo hice'),
                icon: Icon(Icons.check_rounded),
              ),
              ButtonSegment(
                value: false,
                label: Text('No pude'),
                icon: Icon(Icons.sentiment_neutral_outlined),
              ),
            ],
            selected: {_completed},
            onSelectionChanged: _saving
                ? null
                : (value) => setState(() => _completed = value.first),
          ),
          if (!_completed) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final mood in moodLabels.entries)
                  ChoiceChip(
                    label: Text(mood.value),
                    selected: _mood == mood.key,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _mood = mood.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: '¿Qué pasó? (opcional)',
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving || _selected.isEmpty ? null : _save,
            icon: const Icon(Icons.done_all_rounded),
            label: Text(
              _saving
                  ? 'Guardando…'
                  : 'Guardar ${_selected.length} ${_selected.length == 1 ? 'día' : 'días'}',
            ),
          ),
        ],
      ),
    );
  }
}
