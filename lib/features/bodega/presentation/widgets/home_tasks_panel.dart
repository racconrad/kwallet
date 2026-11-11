import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/core/widgets/finance_widgets.dart';
import 'package:knotes/features/bodega/view_models/home_view_model.dart';

class HomeTasksPanel extends StatelessWidget {
  final HomeViewModel controller;
  final VoidCallback onNewTask;
  final VoidCallback onOpenNotes;

  const HomeTasksPanel({
    super.key,
    required this.controller,
    required this.onNewTask,
    required this.onOpenNotes,
  });

  @override
  Widget build(BuildContext context) {
    final tasks = controller.pendingTasks;
    final hasLists = controller.notes.any((n) => n.items.isNotEmpty);

    return LedgerPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: KnotesTheme.accentLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.checklist_rounded,
                  color: KnotesTheme.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tareas pendientes',
                      style: KnotesTheme.fontTitle.copyWith(fontSize: 18),
                    ),
                    Text(
                      tasks.isEmpty
                          ? (hasLists
                                ? '¡Todo completado!'
                                : 'Sin tareas pendientes')
                          : '${tasks.length} ${tasks.length == 1 ? "tarea pendiente" : "tareas pendientes"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: KnotesTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Nueva lista o tarea',
                onPressed: onNewTask,
                icon: const Icon(Icons.add_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: KnotesTheme.incomeGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hasLists
                          ? '¡Excelente! No tienes tareas pendientes hoy.'
                          : 'Crea una lista de compras o pendientes para organizarte.',
                      style: TextStyle(
                        fontSize: 13,
                        color: KnotesTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            for (final item in tasks.take(5)) ...[
              InkWell(
                borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
                onTap: () {
                  HapticFeedback.selectionClick();
                  controller.checkNote(item.note, item.index, true);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: KnotesTheme.accent,
                            width: 2,
                          ),
                        ),
                        child: const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.item.text,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.note.title.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.list_alt_rounded,
                                    size: 13,
                                    color: KnotesTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      item.note.title,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: KnotesTheme.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 12),
            ],
            if (tasks.length > 5)
              TextButton.icon(
                onPressed: onOpenNotes,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text('Ver todas las tareas (${tasks.length})'),
              ),
          ],
        ],
      ),
    );
  }
}
