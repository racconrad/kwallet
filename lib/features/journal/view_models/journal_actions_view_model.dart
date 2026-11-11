import 'package:uuid/uuid.dart';

import 'package:knotes/core/contracts/app_repositories.dart';
import 'package:knotes/core/mvvm/view_model.dart';
import 'package:knotes/features/journal/models/journal_models.dart';

class JournalActionsViewModel extends ViewModel {
  final JournalRepository repository;
  JournalActionsViewModel(this.repository);

  Future<bool> saveHabit(
    String title, {
    Habit? habit,
    String iconKey = 'spa_rounded',
    int colorValue = 0xFF4CAF50,
    String timeBlock = 'anytime',
    String? reminderTime,
    String? reminderDays,
  }) {
    if (title.trim().isEmpty) return Future.value(fail('Escribe un hábito.'));
    return perform(
      () => repository.saveHabit(
        habit?.id ?? const Uuid().v4(),
        title.trim(),
        iconKey: iconKey,
        colorValue: colorValue,
        timeBlock: timeBlock,
        reminderTime: reminderTime,
        reminderDays: reminderDays,
      ),
    );
  }

  Future<bool> saveGoal({
    Goal? original,
    required String title,
    required String kind,
    String? habitId,
    required int target,
    required DateTime startDay,
    required DateTime endDay,
    String? reminderTime,
  }) {
    if (title.trim().isEmpty) {
      return Future.value(fail('Ponle un nombre a tu meta.'));
    }
    if (target <= 0) {
      return Future.value(fail('Elige una cantidad mayor que cero.'));
    }
    return perform(
      () => repository.saveGoal(
        Goal(
          id: original?.id ?? const Uuid().v4(),
          title: title.trim(),
          kind: kind,
          habitId: kind == 'habits' ? habitId : null,
          target: target,
          progress: original?.progress ?? 0,
          startDay: startDay,
          endDay: endDay,
          reminderTime: reminderTime,
          createdAt: original?.createdAt ?? DateTime.now(),
        ),
      ),
    );
  }

  Future<bool> deleteGoal(Goal goal) =>
      perform(() => repository.deleteGoal(goal.id));
  Future<bool> markGoal(Goal goal, [int delta = 1]) =>
      perform(() => repository.markGoal(goal.id, delta: delta));

  Future<bool> quickNote(String text) {
    final note = parseQuickNote(
      text,
      id: const Uuid().v4(),
      newItemId: () => const Uuid().v4(),
    );
    if (note == null) return Future.value(fail('Escribe algo primero.'));
    return perform(() => repository.saveNote(note));
  }

  Future<bool> deleteHabit(Habit habit) =>
      perform(() => repository.deleteHabit(habit.id));
  Future<bool> deleteNote(PersonalNote note) =>
      perform(() => repository.deleteNote(note.id));
  Future<bool> checkNote(PersonalNote note, int index, bool done) => perform(
    () => repository.setNoteItem(
      note.id,
      index,
      done,
      expectedText: note.items[index].text,
    ),
  );
  Future<bool> saveNote({
    PersonalNote? original,
    required String title,
    required String body,
    required String kind,
    required Iterable<NoteItem> items,
    String? iconKey,
    int? colorValue,
  }) {
    if (title.trim().isEmpty) return Future.value(fail('Ponle un título.'));
    final note = PersonalNote(
      id: original?.id ?? const Uuid().v4(),
      title: title.trim(),
      body: body.trim(),
      kind: kind,
      items: items
          .where((i) => i.text.trim().isNotEmpty)
          .map(
            (i) => NoteItem(
              i.text.trim(),
              id: i.id,
              done: i.done,
              dueDate: i.dueDate,
            ),
          )
          .toList(),
      iconKey: iconKey ?? original?.iconKey ?? 'note',
      colorValue: colorValue ?? original?.colorValue ?? 0,
      updatedAt: DateTime.now(),
    );
    return perform(() => repository.saveNote(note));
  }

  Future<bool> markDays(
    Iterable<String> ids,
    Iterable<DateTime> dates, {
    required bool completed,
    String mood = 'neutral',
    String reason = '',
  }) => perform(
    () => repository.logHabitDays(
      ids,
      dates,
      completed: completed,
      mood: mood,
      reason: reason,
    ),
  );
  Future<bool> completeHabit(Habit habit, DateTime date) =>
      markDays([habit.id], [date], completed: true, mood: 'happy');
  Future<bool> completePending(List<Habit> habits, DateTime day) => markDays(
    habits.where((h) => h.logFor(day) == null).map((h) => h.id),
    [day],
    completed: true,
    mood: 'happy',
  );
}
