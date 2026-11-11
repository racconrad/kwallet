import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/core/mvvm/view_model_state.dart';
import 'package:knotes/features/journal/view_models/journal_actions_view_model.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/features/journal/models/journal_models.dart';

const moodLabels = {
  'happy': 'Bien',
  'neutral': 'Neutral',
  'tired': 'Con cansancio',
  'sad': 'Triste',
  'stressed': 'Con estrés',
};
const moodIcons = {
  'happy': Icons.sentiment_satisfied_alt,
  'neutral': Icons.sentiment_neutral,
  'tired': Icons.bedtime_outlined,
  'sad': Icons.sentiment_dissatisfied,
  'stressed': Icons.bolt_outlined,
};

class MoodSheet extends StatefulWidget {
  final Habit habit;
  final DateTime day;
  const MoodSheet({super.key, required this.habit, required this.day});
  @override
  State<MoodSheet> createState() => _MoodSheetState();
}

class _MoodSheetState
    extends ViewModelState<MoodSheet, JournalActionsViewModel> {
  @override
  JournalActionsViewModel createViewModel(AppDependencies dependencies) =>
      dependencies.journalActions();
  late final _reason = TextEditingController(
    text: widget.habit.logFor(widget.day)?.reason ?? '',
  );
  late String _mood = widget.habit.logFor(widget.day)?.mood ?? 'neutral';
  bool get _saving => model.busy;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SheetBody(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Cada día cuenta',
          style: KnotesTheme.fontTitle.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.habit.title} · ${DateFormat('d MMM y', 'es').format(widget.day)}',
        ),
        const SizedBox(height: 18),
        const Text('¿Cómo te sientes?'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in moodLabels.entries)
              ChoiceChip(
                avatar: Icon(moodIcons[entry.key], size: 18),
                label: Text(entry.value),
                selected: _mood == entry.key,
                onSelected: (_) => setState(() => _mood = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _reason,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: '¿Qué se te hizo difícil? (opcional)',
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  final saved = await model.markDays(
                    [widget.habit.id],
                    [widget.day],
                    completed: false,
                    mood: _mood,
                    reason: _reason.text,
                  );
                  if (!context.mounted) return;
                  if (saved) {
                    Navigator.pop(context, true);
                  } else {
                    showFailure(
                      context,
                      model.error ?? 'No se pudo guardar cómo te fue.',
                    );
                  }
                },
          child: Text(_saving ? 'Guardando…' : 'Guardar cómo me fue'),
        ),
      ],
    ),
  );
}
