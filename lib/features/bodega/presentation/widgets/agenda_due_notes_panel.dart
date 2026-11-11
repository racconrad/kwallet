import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/features/bodega/view_models/planning_view_model.dart';

class AgendaDueNotesPanel extends StatelessWidget {
  final PlanningViewModel model;

  const AgendaDueNotesPanel({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    final dueItems = model.dueNoteItems;
    if (dueItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LedgerPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event_note_rounded,
                  size: 18,
                  color: KnotesTheme.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pendientes programados',
                    style: KnotesTheme.fontTitle.copyWith(fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: KnotesTheme.accentLight,
                    borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
                  ),
                  child: Text(
                    '${dueItems.where((i) => i.item.done).length}/${dueItems.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: KnotesTheme.accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final entry in dueItems)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Checkbox(
                      value: entry.item.done,
                      onChanged: (val) {
                        if (val != null) {
                          model.toggleNoteItem(
                            entry.note,
                            entry.itemIndex,
                            val,
                          );
                        }
                      },
                    ),
                    Expanded(
                      child: Text(
                        entry.item.text,
                        style: TextStyle(
                          fontSize: 13,
                          decoration: entry.item.done
                              ? TextDecoration.lineThrough
                              : null,
                          color: entry.item.done
                              ? KnotesTheme.textSecondary
                              : KnotesTheme.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: KnotesTheme.surfaceContainer.withValues(
                          alpha: 0.6,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        entry.note.title,
                        style: TextStyle(
                          fontSize: 10,
                          color: KnotesTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
