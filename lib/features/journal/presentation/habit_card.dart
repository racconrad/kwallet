import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/core/mvvm/view_model_state.dart';
import 'package:knotes/features/journal/view_models/journal_actions_view_model.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/core/widgets/pet_visual_toast.dart';
import 'package:knotes/features/journal/models/journal_models.dart';
import 'package:knotes/features/journal/presentation/journal_sheets.dart';

import 'package:knotes/features/journal/presentation/habit_actions.dart';
import 'package:knotes/features/journal/presentation/habit_days_sheet.dart';
import 'package:knotes/core/widgets/menu_label.dart';

class HabitCard extends StatefulWidget {
  final Habit habit;
  final DateTime day;
  final VoidCallback? onEdit;
  final bool compact;
  final bool hideStreak;
  const HabitCard({
    super.key,
    required this.habit,
    required this.day,
    this.onEdit,
    this.compact = false,
    this.hideStreak = false,
  });
  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState
    extends ViewModelState<HabitCard, JournalActionsViewModel> {
  @override
  JournalActionsViewModel createViewModel(AppDependencies dependencies) =>
      dependencies.journalActions();
  bool get _busy => model.busy;
  Future<void> _complete() async {
    if (await model.completeHabit(widget.habit, widget.day)) {
      HapticFeedback.lightImpact();
      if (mounted) {
        PetVisualToast.show(
          context,
          type: PetVisualToastType.habitDone,
          badgeValue: '+10 XP',
        );
      }
    } else if (mounted) {
      showFailure(context, model.error ?? 'No se pudo marcar el hábito.');
    }
  }

  void _days() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => HabitDaysSheet(habit: widget.habit, initialDay: widget.day),
  );
  void _missed() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => MoodSheet(habit: widget.habit, day: widget.day),
  );

  @override
  Widget build(BuildContext context) {
    final log = widget.habit.logFor(widget.day);
    final done = log?.completed == true;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final habitColor = Color(widget.habit.colorValue);
    final bgTint = habitColor.withValues(alpha: 0.08);
    final borderTint = habitColor.withValues(alpha: 0.35);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: bgTint,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KnotesTheme.radiusMd),
          side: BorderSide(color: borderTint, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Semantics(
                    checked: done,
                    label: 'Marcar ${widget.habit.title}',
                    child: IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: habitColor.withValues(
                          alpha: done ? 0.25 : 0.12,
                        ),
                      ),
                      tooltip: done ? 'Completado' : 'Marcar como hecho',
                      onPressed: _busy || done ? null : _complete,
                      icon: AnimatedSwitcher(
                        duration: Duration(milliseconds: reduced ? 0 : 180),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: _busy
                            ? const SizedBox.square(
                                key: ValueKey('busy'),
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                done
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                key: ValueKey(done),
                                color: habitColor,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: habitColor.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      getHabitIcon(widget.habit.iconKey),
                      color: habitColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.habit.title,
                          style: KnotesTheme.fontTitle.copyWith(fontSize: 17),
                        ),
                        if (!widget.hideStreak) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.local_fire_department_outlined,
                                size: 16,
                                color: habitColor,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${widget.habit.streak(widget.day)} días · mejor ${widget.habit.bestStreak}'
                                  '${widget.habit.reminderTime == null ? '' : ' · ${widget.habit.reminderTime}'}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: KnotesTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Opciones de ${widget.habit.title}',
                    onSelected: (value) async {
                      if (value == 'days') {
                        _days();
                      } else if (value == 'edit') {
                        if (widget.onEdit != null) {
                          widget.onEdit!();
                        } else {
                          editHabit(context, habit: widget.habit);
                        }
                      } else {
                        final remove = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('¿Eliminar hábito?'),
                            content: const Text(
                              'También se borrarán sus días registrados.',
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
                        if (remove == true) {
                          if (!await model.deleteHabit(widget.habit) &&
                              context.mounted) {
                            showFailure(
                              context,
                              model.error ?? 'No se pudo eliminar el hábito.',
                            );
                          }
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      menuItem(
                        'days',
                        Icons.event_available_outlined,
                        'Marcar varios días',
                      ),
                      menuItem('edit', Icons.edit_outlined, 'Editar'),
                      menuItem(
                        'delete',
                        Icons.delete_outline_rounded,
                        'Eliminar',
                        danger: true,
                      ),
                    ],
                  ),
                ],
              ),
              if (!widget.compact || log?.completed != true)
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: _busy ? null : _missed,
                      icon: const Icon(
                        Icons.sentiment_neutral_outlined,
                        size: 18,
                      ),
                      label: const Text('No pude'),
                    ),
                    TextButton.icon(
                      onPressed: _busy ? null : _days,
                      icon: const Icon(Icons.date_range_outlined, size: 18),
                      label: const Text('Varios días'),
                    ),
                  ],
                ),
              if (log != null && !done)
                Text(
                  '${moodLabels[log.mood] ?? 'Neutral'}${log.reason.isEmpty ? '' : ' · ${log.reason}'}',
                  style: TextStyle(color: KnotesTheme.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
