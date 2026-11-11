import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_palette.dart';
import 'package:knotes/core/theme/knotes_theme.dart';

/// Light/dark mode and colour palette, applied as soon as they change.
class AppearanceSection extends StatelessWidget {
  final Future<void> Function(String key, String value) onChanged;
  const AppearanceSection({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SegmentedButton<String>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: 'light',
            icon: Icon(Icons.light_mode_outlined),
            label: Text('Claro'),
          ),
          ButtonSegment(
            value: 'dark',
            icon: Icon(Icons.dark_mode_outlined),
            label: Text('Oscuro'),
          ),
          ButtonSegment(
            value: 'system',
            icon: Icon(Icons.brightness_auto_outlined),
            label: Text('Auto'),
          ),
        ],
        selected: {KnotesTheme.mode},
        onSelectionChanged: (value) => onChanged('theme_mode', value.first),
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final entry in KnotesPalette.all.entries)
            ChoiceChip(
              avatar: _Swatch(entry.value),
              label: Text(entry.value.label),
              selected: KnotesTheme.palette == entry.key,
              onSelected: (_) => onChanged('palette', entry.key),
            ),
        ],
      ),
    ],
  );
}

/// Split circle previewing a palette's accent and pop colours.
class _Swatch extends StatelessWidget {
  final KnotesPalette palette;
  const _Swatch(this.palette);

  @override
  Widget build(BuildContext context) {
    final dark = KnotesTheme.isDark;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: KnotesTheme.surface, width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [.5, .5],
          colors: [
            dark ? palette.accentDark : palette.accent,
            dark ? palette.popDark : palette.pop,
          ],
        ),
      ),
    );
  }
}
