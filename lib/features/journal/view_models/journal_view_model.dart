import 'package:knotes/core/contracts/app_repositories.dart';
import 'package:knotes/features/journal/models/journal_models.dart';
import 'package:knotes/features/journal/view_models/journal_actions_view_model.dart';

class JournalViewModel extends JournalActionsViewModel {
  final SettingsRepository preferences;
  List<PersonalNote> notes = const [];
  List<Habit> habits = const [];
  List<Goal> goals = const [];
  Map<String, String> settings = const {};
  int xp = 0;
  bool loading = true;
  JournalViewModel(super.repository, this.preferences) {
    for (final source in {repository.changes, preferences.changes}) {
      observe(source, load);
    }
  }
  Future<void> load() async {
    final request = beginRequest();
    try {
      final nextNotes = await repository.getNotes();
      final nextHabits = await repository.getHabits();
      final nextSettings = await preferences.getSettings();
      final nextXp = await repository.getExperience();
      final nextGoals = await repository.getGoals();
      if (!isCurrent(request)) return;
      notes = List.unmodifiable(nextNotes);
      habits = List.unmodifiable(nextHabits);
      goals = List.unmodifiable(nextGoals);
      settings = Map.unmodifiable(nextSettings);
      xp = nextXp;
      loading = false;
      error = null;
      changed();
    } catch (_) {
      if (isCurrent(request)) {
        loading = false;
        fail('No se pudo abrir tu espacio. Reintenta.');
      }
    }
  }
}
