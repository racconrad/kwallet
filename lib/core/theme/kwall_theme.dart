import '../models/currency_conversion.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class KwallTheme {
  static final revision = ValueNotifier<int>(0);
  static String palette = 'forest';
  static String mode = 'system';
  static bool isDark = false;
  static const palettes = {
    'forest': 'Bosque',
    'plum': 'Ciruela',
    'rose': 'Rosa',
    'gold': 'Miel',
  };

  static void configure(Map<String, String> settings, Brightness brightness) {
    final nextPalette = palettes.containsKey(settings['palette'])
        ? settings['palette']!
        : 'forest';
    final nextMode =
        ['light', 'dark', 'system'].contains(settings['theme_mode'])
        ? settings['theme_mode']!
        : 'system';
    final dark =
        nextMode == 'dark' ||
        (nextMode == 'system' && brightness == Brightness.dark);
    if (palette == nextPalette && mode == nextMode && isDark == dark) return;
    palette = nextPalette;
    mode = nextMode;
    isDark = dark;
    revision.value++;
  }

  static Color get background => Color(isDark ? 0xFF1D211E : 0xFFF5F5EE);
  static Color get surface => Color(isDark ? 0xFF272D28 : 0xFFFFFEF9);
  static Color get surfaceContainer => Color(isDark ? 0xFF353E36 : 0xFFE9EBDF);
  static Color get surfaceElevated => surfaceContainer;
  static Color get border => Color(isDark ? 0xFF8D9C8F : 0xFF555E50);
  static Color paletteColor(String name, {bool dark = false}) => switch (name) {
    'plum' => Color(dark ? 0xFFD9B7ED : 0xFF735085),
    'rose' => Color(dark ? 0xFFF1B3C7 : 0xFFA14665),
    'gold' => Color(dark ? 0xFFE9CB81 : 0xFF806015),
    _ => Color(dark ? 0xFFB2D39C : 0xFF466539),
  };
  static Color get accent => paletteColor(palette, dark: isDark);
  static Color get accentLight =>
      Color.alphaBlend(accent.withValues(alpha: isDark ? .2 : .14), surface);
  static Color get onAccent => isDark ? const Color(0xFF20231E) : Colors.white;
  static Color get expenseRed => Color(isDark ? 0xFFFFB4AC : 0xFFA42C39);
  static Color get incomeGreen => Color(isDark ? 0xFFB5D49F : 0xFF39613E);
  static Color get info => accent;
  static Color get warningAmber => Color(isDark ? 0xFFE7C879 : 0xFF7C590A);
  static Color get textPrimary => Color(isDark ? 0xFFF1F3E9 : 0xFF292E27);
  static Color get textSecondary => Color(isDark ? 0xFFC4CDBF : 0xFF565F50);
  static Color get textMuted => textSecondary;
  static TextStyle get fontTitle =>
      const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700);
  static TextStyle get fontBody => const TextStyle(fontFamily: 'Roboto');
  static TextStyle get fontDisplay => const TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w800,
    letterSpacing: -.5,
  );

  static ThemeData get expressiveTheme {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: isDark ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: accent,
          onPrimary: onAccent,
          secondary: incomeGreen,
          onSecondary: onAccent,
          surface: surface,
          onSurface: textPrimary,
          surfaceContainer: surfaceContainer,
          error: expenseRed,
          onError: isDark ? Colors.black : Colors.white,
          outline: border,
          onSurfaceVariant: textSecondary,
        );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: border),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: background,
      textTheme: (isDark ? ThemeData.dark() : ThemeData.light()).textTheme
          .apply(
            fontFamily: 'Roboto',
            bodyColor: textPrimary,
            displayColor: textPrimary,
          ),
      cardTheme: CardThemeData(color: surface, elevation: 0, shape: shape),
      dialogTheme: DialogThemeData(backgroundColor: surface, shape: shape),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        showDragHandle: true,
        dragHandleColor: border,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: fontTitle.copyWith(fontSize: 23, color: textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainer,
        hintStyle: TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border.withValues(alpha: .5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        showCheckmark: false,
        labelStyle: TextStyle(fontFamily: 'Roboto', color: textPrimary),
        secondaryLabelStyle: TextStyle(
          fontFamily: 'Roboto',
          color: textPrimary,
        ),
        checkmarkColor: accent,
        iconTheme: IconThemeData(color: accent),
        selectedColor: accentLight,
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accentLight,
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: textPrimary)),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: TextStyle(color: surface),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(
        color: border.withValues(alpha: .25),
        thickness: 1,
      ),
    );
  }

  static Color displayColor(int value) {
    final hsl = HSLColor.fromColor(Color(value));
    if (hsl.hue >= 170 && hsl.hue <= 270) return accent;
    return hsl
        .withLightness(isDark ? .75 : hsl.lightness.clamp(0, .36))
        .toColor();
  }

  static String formatCurrency(double amount, [String currency = '\$']) {
    return '${amount < 0 ? '-' : ''}${CurrencyConversion.symbol(currency)}${NumberFormat('#,##0.00', 'en_US').format(amount.abs())}';
  }
}
