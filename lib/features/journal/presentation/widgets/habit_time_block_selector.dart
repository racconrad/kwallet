import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';

class HabitTimeBlockSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const HabitTimeBlockSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const blocks = [
    ('anytime', 'Todo el día', Icons.all_inclusive_rounded),
    ('morning', 'Mañana', Icons.wb_sunny_rounded),
    ('afternoon', 'Tarde', Icons.wb_twilight_rounded),
    ('evening', 'Noche', Icons.nights_stay_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Momento del día',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: KnotesTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (key, label, icon) in blocks)
              ChoiceChip(
                selected: selected == key,
                onSelected: (val) {
                  if (val) onChanged(key);
                },
                avatar: Icon(
                  icon,
                  size: 16,
                  color: selected == key
                      ? KnotesTheme.onAccent
                      : KnotesTheme.accent,
                ),
                label: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected == key
                        ? KnotesTheme.onAccent
                        : KnotesTheme.textPrimary,
                  ),
                ),
                selectedColor: KnotesTheme.accent,
                backgroundColor: KnotesTheme.surfaceContainer.withValues(
                  alpha: 0.5,
                ),
                side: BorderSide(
                  color: selected == key
                      ? KnotesTheme.accent
                      : KnotesTheme.border.withValues(alpha: 0.4),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
