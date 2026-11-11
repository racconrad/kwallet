import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/core/mvvm/view_model_state.dart';
import 'package:knotes/features/journal/view_models/journal_actions_view_model.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/core/widgets/kitty_companion.dart';
import 'package:knotes/features/journal/models/journal_models.dart';

class HabitDaySummary extends StatefulWidget {
  final List<Habit> habits;
  final DateTime day;
  final Map<String, String> settings;
  final int reward;
  const HabitDaySummary({
    super.key,
    required this.habits,
    required this.day,
    this.settings = const {},
    this.reward = 0,
  });
  @override
  State<HabitDaySummary> createState() => _HabitDaySummaryState();
}

class _HabitDaySummaryState
    extends ViewModelState<HabitDaySummary, JournalActionsViewModel> {
  @override
  JournalActionsViewModel createViewModel(AppDependencies dependencies) =>
      dependencies.journalActions();
  bool get _busy => model.busy;
  Future<void> _complete() async {
    final pending = widget.habits
        .where((h) => h.logFor(widget.day) == null)
        .toList();
    if (pending.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Completaste tus pendientes?'),
        content: Text(
          '${pending.length} hábitos · ${DateFormat('d MMM y', 'es').format(widget.day)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Marcar todos'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (await model.completePending(widget.habits, widget.day)) {
      HapticFeedback.lightImpact();
    } else if (mounted) {
      showFailure(
        context,
        model.error ?? 'No se pudieron marcar tus pendientes.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = widget.habits
        .where((h) => h.logFor(widget.day)?.completed == true)
        .length;
    final pending = widget.habits
        .where((h) => h.logFor(widget.day) == null)
        .length;
    final allDone =
        widget.habits.isNotEmpty && completed == widget.habits.length;
    return Row(
      children: [
        KittyCompanionWidget(
          settings: widget.settings,
          reward: widget.reward,
          size: 60,
          activity: allDone ? PetActivity.relax : PetActivity.idle,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                allDone
                    ? '¡Día completo!'
                    : '$completed de ${widget.habits.length}',
                style: KnotesTheme.fontTitle.copyWith(fontSize: 18),
              ),
              if (pending > 0)
                TextButton.icon(
                  onPressed: _busy ? null : _complete,
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('Marcar pendientes'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
