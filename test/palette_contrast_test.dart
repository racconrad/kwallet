import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knotes/core/theme/knotes_palette.dart';
import 'package:knotes/core/theme/knotes_theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + .05) / (min(la, lb) + .05);
}

void main() {
  for (final key in KnotesPalette.all.keys) {
    for (final dark in [false, true]) {
      test('$key ${dark ? 'dark' : 'light'} keeps readable contrast', () {
        KnotesTheme.configure({
          'palette': key,
          'theme_mode': dark ? 'dark' : 'light',
        }, Brightness.light);
        final bg = KnotesTheme.surface;
        expect(_contrast(KnotesTheme.textPrimary, bg), greaterThan(7));
        expect(_contrast(KnotesTheme.textSecondary, bg), greaterThan(4.5));
        expect(_contrast(KnotesTheme.accent, bg), greaterThan(4.5));
        expect(
          _contrast(KnotesTheme.onAccent, KnotesTheme.accent),
          greaterThan(4.5),
        );
        expect(_contrast(KnotesTheme.onPop, KnotesTheme.pop), greaterThan(4.5));
      });
    }
  }
}
