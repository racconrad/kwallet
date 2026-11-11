import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:knotes/app/app_dependencies.dart';
import 'package:knotes/core/mvvm/view_model_state.dart';
import 'package:knotes/features/journal/view_models/journal_actions_view_model.dart';
import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/features/journal/models/journal_models.dart';
import 'package:knotes/features/journal/presentation/journal_sheets.dart';

class NotePreview extends StatefulWidget {
  final PersonalNote note;
  const NotePreview({super.key, required this.note});
  @override
  State<NotePreview> createState() => _NotePreviewState();
}

class _NotePreviewState
    extends ViewModelState<NotePreview, JournalActionsViewModel> {
  @override
  JournalActionsViewModel createViewModel(AppDependencies dependencies) =>
      dependencies.journalActions();
  bool get _busy => model.busy;
  Future<void> _check(int index, bool done) async {
    if (await model.checkNote(widget.note, index, done)) {
      HapticFeedback.selectionClick();
    } else if (mounted) {
      showFailure(context, model.error ?? 'No se pudo actualizar la lista.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final noteColor = widget.note.colorValue != 0
        ? Color(widget.note.colorValue)
        : KnotesTheme.accent;
    final bgTint = widget.note.colorValue != 0
        ? noteColor.withValues(alpha: 0.08)
        : KnotesTheme.surface;
    final borderTint = widget.note.colorValue != 0
        ? noteColor.withValues(alpha: 0.35)
        : KnotesTheme.border.withValues(alpha: 0.65);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: bgTint,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KnotesTheme.radiusMd),
          side: BorderSide(
            color: borderTint,
            width: widget.note.colorValue != 0 ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: noteColor.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    getNoteIcon(widget.note.iconKey),
                    color: noteColor,
                    size: 18,
                  ),
                ),
                title: Text(
                  widget.note.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KnotesTheme.fontTitle,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => openNote(context, note: widget.note),
              ),
              if (widget.note.body.isNotEmpty)
                Text(
                  widget.note.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              for (var i = 0; i < widget.note.items.length && i < 3; i++)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: widget.note.items[i].done,
                  title: Text(
                    widget.note.items[i].text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      decoration: widget.note.items[i].done
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  onChanged: _busy ? null : (value) => _check(i, value!),
                ),
              if (widget.note.items.length > 3)
                Text(
                  '+${widget.note.items.length - 3} en la lista',
                  style: TextStyle(
                    color: KnotesTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
