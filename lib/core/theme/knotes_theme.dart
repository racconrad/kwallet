import 'package:knotes/core/models/currency_conversion.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:knotes/core/theme/knotes_palette.dart';
import 'package:knotes/core/theme/knotes_theme_data.dart';

class KnotesTheme {
  static final revision = ValueNotifier<int>(0);
  static String palette = KnotesPalette.fallback;
  static String mode = 'system';
  static bool isDark = false;

  static const radiusSm = 14.0;
  static const radiusMd = 20.0;
  static const radiusLg = 28.0;

  static void configure(Map<String, String> settings, Brightness brightness) {
    final nextPalette = KnotesPalette.all.containsKey(settings['palette'])
        ? settings['palette']!
        : KnotesPalette.fallback;
    final nextMode =
        ['light', 'dark', 'system'].contains(settings['theme_mode'])
        ? settings['theme_mode']!
        : 'system';
    final dark =
        nextMode == 'dark' ||
        (nextMode == 'system' && brightness == Brightness.dark);
    final hide = settings['hide_amounts'] == 'true';
    if (palette == nextPalette &&
        mode == nextMode &&
        isDark == dark &&
        hideAmounts == hide) {
      return;
    }
    palette = nextPalette;
    mode = nextMode;
    isDark = dark;
    hideAmounts = hide;
    revision.value++;
  }

  static KnotesPalette get _palette => KnotesPalette.all[palette]!;

  // Neutrals share the accent hue so every palette changes the whole mood.
  static Color _tone(double saturation, double lightness) => HSLColor.fromAHSL(
    1,
    HSLColor.fromColor(_palette.accent).hue,
    saturation,
    lightness,
  ).toColor();

  static Color get background => isDark ? _tone(.22, .08) : _tone(.4, .95);
  static Color get surface => isDark ? _tone(.2, .12) : _tone(.5, .99);
  static Color get surfaceContainer => isDark ? _tone(.2, .18) : _tone(.36, .9);
  static Color get surfaceElevated => surfaceContainer;
  static Color get border => isDark ? _tone(.16, .62) : _tone(.22, .28);
  static Color paletteColor(String name, {bool dark = false}) {
    final p =
        KnotesPalette.all[name] ?? KnotesPalette.all[KnotesPalette.fallback]!;
    return dark ? p.accentDark : p.accent;
  }

  static Color get accent => paletteColor(palette, dark: isDark);
  static Color get accentLight =>
      Color.alphaBlend(accent.withValues(alpha: isDark ? .22 : .16), surface);
  static Color get onAccent => isDark ? _tone(.35, .1) : Colors.white;
  static Color get pop => isDark ? _palette.popDark : _palette.pop;
  static Color get onPop => onAccent;
  static Color get expenseRed => Color(isDark ? 0xFFFFB4AC : 0xFFA42C39);
  static Color get incomeGreen => Color(isDark ? 0xFFB5D49F : 0xFF2F6B3A);
  static Color get info => accent;
  static Color get warningAmber => Color(isDark ? 0xFFE7C879 : 0xFF7C590A);
  static Color get textPrimary => isDark ? _tone(.25, .95) : _tone(.3, .11);
  static Color get textSecondary => isDark ? _tone(.14, .76) : _tone(.14, .36);
  static Color get textMuted => textSecondary;

  /// Hard offset shadow that gives panels their printed, sticker-like edge.
  static List<BoxShadow> get hardShadow => [
    BoxShadow(
      color: isDark ? Colors.black.withValues(alpha: .55) : border,
      offset: const Offset(0, 4),
    ),
  ];
  static TextStyle get fontTitle => const TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w800,
    letterSpacing: -.2,
  );
  static TextStyle get fontBody => const TextStyle(fontFamily: 'Roboto');
  static TextStyle get fontDisplay => const TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w900,
    letterSpacing: -1.2,
    height: 1.05,
  );

  static ThemeData get expressiveTheme => buildKnotesTheme();

  static Color displayColor(int value) {
    final hsl = HSLColor.fromColor(Color(value));
    if (hsl.hue >= 170 && hsl.hue <= 270) return accent;
    return hsl
        .withLightness(isDark ? .75 : hsl.lightness.clamp(0, .36))
        .toColor();
  }

  /// Discreet mode: every formatted amount on screen becomes a mask.
  static bool hideAmounts = false;

  static String formatCurrency(double amount, [String currency = '\$']) {
    if (hideAmounts) return '${CurrencyConversion.symbol(currency)} •••';
    return '${amount < 0 ? '-' : ''}${CurrencyConversion.symbol(currency)}${NumberFormat('#,##0.00', 'en_US').format(amount.abs())}';
  }
}
