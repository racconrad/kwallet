import 'package:flutter/material.dart';

/// A selectable base palette: a primary accent plus a contrasting "pop"
/// colour, each tuned separately for light and dark backgrounds.
class KnotesPalette {
  final String label;
  final Color accent;
  final Color accentDark;
  final Color pop;
  final Color popDark;
  const KnotesPalette(
    this.label,
    this.accent,
    this.accentDark,
    this.pop,
    this.popDark,
  );

  static const fallback = 'iris';

  // Keys are persisted in settings and mirrored by the Android widget.
  static const all = {
    'iris': KnotesPalette(
      'Iris',
      Color(0xFF5B3FD6),
      Color(0xFFC7B8FF),
      Color(0xFFC2410C),
      Color(0xFFFFB38A),
    ),
    'ember': KnotesPalette(
      'Brasa',
      Color(0xFFC2410C),
      Color(0xFFFFB59A),
      Color(0xFF1D4ED8),
      Color(0xFFA9C4FF),
    ),
    'ocean': KnotesPalette(
      'Océano',
      Color(0xFF0B57D0),
      Color(0xFFAAC7FF),
      Color(0xFFBE185D),
      Color(0xFFFFB0CB),
    ),
    'plum': KnotesPalette(
      'Ciruela',
      Color(0xFF735085),
      Color(0xFFD9B7ED),
      Color(0xFF0F766E),
      Color(0xFF8EE0D4),
    ),
    'rose': KnotesPalette(
      'Rosa',
      Color(0xFFA14665),
      Color(0xFFF1B3C7),
      Color(0xFF1E40AF),
      Color(0xFFB4C6FF),
    ),
    'gold': KnotesPalette(
      'Miel',
      Color(0xFF806015),
      Color(0xFFE9CB81),
      Color(0xFF6D28D9),
      Color(0xFFD2BBFF),
    ),
    'forest': KnotesPalette(
      'Bosque',
      Color(0xFF466539),
      Color(0xFFB2D39C),
      Color(0xFF9A3412),
      Color(0xFFFFB59A),
    ),
  };
}
