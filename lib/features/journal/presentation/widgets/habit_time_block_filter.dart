import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/features/journal/models/journal_models.dart';

class HabitTimeBlockFilter extends StatelessWidget {
  final String activeBlock;
  final ValueChanged<String> onChanged;

  const HabitTimeBlockFilter({
    super.key,
    required this.activeBlock,
    required this.onChanged,
  });

  static String defaultCurrentBlock() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 19) return 'afternoon';
    return 'evening';
  }

  static List<Habit> filter(List<Habit> habits, String block) {
    if (block == 'all') return habits;
    return habits.where((h) {
      if (h.timeBlock == 'anytime') return true;
      return h.timeBlock == block;
    }).toList();
  }

  static const _filters = [
    ('all', 'Todos', Icons.grid_view_rounded),
    ('morning', 'Mañana', Icons.wb_sunny_rounded),
    ('afternoon', 'Tarde', Icons.wb_twilight_rounded),
    ('evening', 'Noche', Icons.nights_stay_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (key, label, icon) in _filters) ...[
            FilterChip(
              selected: activeBlock == key,
              onSelected: (_) => onChanged(key),
              avatar: Icon(
                icon,
                size: 15,
                color: activeBlock == key
                    ? KnotesTheme.onAccent
                    : KnotesTheme.accent,
              ),
              label: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: activeBlock == key
                      ? KnotesTheme.onAccent
                      : KnotesTheme.textPrimary,
                ),
              ),
              selectedColor: KnotesTheme.accent,
              backgroundColor: KnotesTheme.surfaceContainer.withValues(
                alpha: 0.6,
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              side: BorderSide(
                color: activeBlock == key
                    ? KnotesTheme.accent
                    : KnotesTheme.border.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}
