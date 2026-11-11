import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/features/journal/models/journal_models.dart';

import 'package:knotes/features/journal/presentation/components/goal_sheet.dart';
import 'package:knotes/features/journal/presentation/components/goal_kinds.dart';

export 'components/goal_sheet.dart' show GoalSheet;
export 'components/goal_kinds.dart' show goalKinds;

Future<void> editGoal(
  BuildContext context, {
  Goal? goal,
  required List<Habit> habits,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => GoalSheet(goal: goal, habits: habits),
);

class GoalsSection extends StatelessWidget {
  final List<Goal> goals;
  final List<Habit> habits;
  final Future<bool> Function(Goal goal) onMark;
  final int? limit;
  const GoalsSection({
    super.key,
    required this.goals,
    required this.habits,
    required this.onMark,
    this.limit,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final active = goals.where((g) => !g.isExpired(now)).toList();
    final past = goals.where((g) => g.isExpired(now)).toList();
    final shown = limit == null ? active : active.take(limit!).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Metas',
                style: KnotesTheme.fontTitle.copyWith(fontSize: 20),
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Nueva meta',
              onPressed: () => editGoal(context, habits: habits),
              icon: const Icon(Icons.flag_outlined),
            ),
          ],
        ),
        if (active.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Ponte un reto con plazo: «10 tareas esta semana» o «20 días de lectura este mes».',
              style: TextStyle(color: KnotesTheme.textSecondary),
            ),
          ),
        for (final goal in shown)
          _GoalTile(
            key: ValueKey(goal.id),
            goal: goal,
            habit: habits.where((h) => h.id == goal.habitId).firstOrNull,
            onMark: onMark,
            onEdit: () => editGoal(context, goal: goal, habits: habits),
          ),
        if (past.isNotEmpty && limit == null)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Historial de metas'),
            subtitle: Text(
              'Logradas: ${past.where((g) => g.reached).length} · '
              'Vencidas: ${past.where((g) => !g.reached).length}',
            ),
            children: [
              for (final goal in past)
                _GoalTile(
                  key: ValueKey(goal.id),
                  goal: goal,
                  habit: habits.where((h) => h.id == goal.habitId).firstOrNull,
                  onMark: onMark,
                  onEdit: () => editGoal(context, goal: goal, habits: habits),
                ),
            ],
          ),
      ],
    );
  }
}

class _GoalTile extends StatelessWidget {
  final Goal goal;
  final Habit? habit;
  final Future<bool> Function(Goal goal) onMark;
  final VoidCallback onEdit;
  const _GoalTile({
    super.key,
    required this.goal,
    required this.habit,
    required this.onMark,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final left = goal.daysLeft(DateTime.now());
    final expired = goal.isExpired(DateTime.now());
    final source = goal.kind == 'habits'
        ? habit?.title ?? 'Cualquier hábito'
        : goalKinds[goal.kind]!.$2;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(KnotesTheme.radiusMd),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    goal.reached
                        ? Icons.emoji_events_rounded
                        : goalKinds[goal.kind]!.$1,
                    color: KnotesTheme.accent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '$source · ${goal.reached
                              ? '¡Lograda!'
                              : expired
                              ? 'Vencida'
                              : left <= 1
                              ? 'último día'
                              : 'quedan $left días'}'
                          '${goal.reminderTime == null ? '' : ' · ${goal.reminderTime}'}',
                          style: TextStyle(
                            color: KnotesTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${goal.progress}/${goal.target}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (goal.kind == 'manual' && !expired)
                    IconButton(
                      tooltip: 'Marcar uno más',
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        final ok = await onMark(goal);
                        if (!ok && context.mounted) {
                          showFailure(context, 'No se pudo marcar la meta.');
                        }
                      },
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    )
                  else
                    const SizedBox(width: 12),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: goal.ratio),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
