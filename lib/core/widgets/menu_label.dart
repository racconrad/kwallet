import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';

/// Icon + text row used by every popup menu and dropdown option.
class MenuLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool danger;
  final Color? color;
  const MenuLabel(
    this.icon,
    this.text, {
    super.key,
    this.danger = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tone = danger ? KnotesTheme.expenseRed : color ?? KnotesTheme.accent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              tone.withValues(alpha: .16),
              KnotesTheme.surface,
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: tone),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: danger ? KnotesTheme.expenseRed : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Popup menu option rendered as a [MenuLabel].
PopupMenuItem<T> menuItem<T>(
  T value,
  IconData icon,
  String text, {
  bool danger = false,
}) => PopupMenuItem<T>(
  value: value,
  child: MenuLabel(icon, text, danger: danger),
);

/// Shared shape for dropdown menus, which the theme cannot set.
final dropdownRadius = BorderRadius.circular(KnotesTheme.radiusMd);
