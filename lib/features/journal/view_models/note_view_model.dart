import 'package:uuid/uuid.dart';

import 'package:knotes/features/journal/models/journal_models.dart';
import 'package:knotes/features/journal/view_models/journal_actions_view_model.dart';

class NoteViewModel extends JournalActionsViewModel {
  final String noteId;
  PersonalNote? note;
  bool missing = false;

  NoteViewModel(super.repository, PersonalNote? original)
    : note = original,
      noteId = original?.id ?? const Uuid().v4() {
    observe(repository.changes, load);
    if (original != null) load();
  }

  Future<void> load() async {
    final request = beginRequest();
    try {
      final notes = await repository.getNotes();
      if (!isCurrent(request)) return;
      final latest = notes.where((n) => n.id == noteId).firstOrNull;
      missing = latest == null && note != null;
      if (latest != null) note = latest;
      changed();
    } catch (_) {
      if (isCurrent(request)) fail('No se pudo actualizar la nota. Reintenta.');
    }
  }

  PersonalNote get original =>
      note ?? PersonalNote(id: noteId, title: '', updatedAt: DateTime.now());
}
