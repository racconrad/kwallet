import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';

/// Material component themes built from the active [KnotesTheme] tokens.
ThemeData buildKnotesTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: KnotesTheme.accent,
        brightness: KnotesTheme.isDark ? Brightness.dark : Brightness.light,
        dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
      ).copyWith(
        primary: KnotesTheme.accent,
        onPrimary: KnotesTheme.onAccent,
        primaryContainer: KnotesTheme.accentLight,
        onPrimaryContainer: KnotesTheme.textPrimary,
        secondary: KnotesTheme.pop,
        onSecondary: KnotesTheme.onPop,
        tertiary: KnotesTheme.pop,
        onTertiary: KnotesTheme.onPop,
        surface: KnotesTheme.surface,
        onSurface: KnotesTheme.textPrimary,
        surfaceContainer: KnotesTheme.surfaceContainer,
        surfaceContainerHighest: KnotesTheme.surfaceContainer,
        error: KnotesTheme.expenseRed,
        onError: KnotesTheme.isDark ? Colors.black : Colors.white,
        outline: KnotesTheme.border,
        outlineVariant: KnotesTheme.border.withValues(alpha: .3),
        onSurfaceVariant: KnotesTheme.textSecondary,
      );
  final edge = BorderSide(color: KnotesTheme.border, width: 1.5);
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(KnotesTheme.radiusMd),
    side: edge,
  );
  final pill = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
  );
  const buttonText = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w800,
    fontSize: 15,
    letterSpacing: .1,
  );
  final base =
      (KnotesTheme.isDark ? ThemeData.dark() : ThemeData.light()).textTheme;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: KnotesTheme.background,
    textTheme: base
        .copyWith(
          displaySmall: base.displaySmall?.merge(KnotesTheme.fontDisplay),
          headlineMedium: base.headlineMedium?.merge(KnotesTheme.fontDisplay),
          headlineSmall: base.headlineSmall?.merge(KnotesTheme.fontTitle),
          titleLarge: base.titleLarge?.merge(KnotesTheme.fontTitle),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        )
        .apply(
          fontFamily: 'Roboto',
          bodyColor: KnotesTheme.textPrimary,
          displayColor: KnotesTheme.textPrimary,
        ),
    cardTheme: CardThemeData(
      color: KnotesTheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: shape,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: KnotesTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KnotesTheme.radiusLg),
        side: edge,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: KnotesTheme.surface,
      modalBackgroundColor: KnotesTheme.surface,
      showDragHandle: true,
      dragHandleColor: KnotesTheme.border,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(KnotesTheme.radiusLg),
        ),
        side: edge,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: KnotesTheme.background,
      foregroundColor: KnotesTheme.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: KnotesTheme.fontDisplay.copyWith(
        fontSize: 26,
        letterSpacing: -.8,
        color: KnotesTheme.textPrimary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KnotesTheme.surfaceContainer,
      hintStyle: TextStyle(color: KnotesTheme.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
        borderSide: edge,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
        borderSide: BorderSide(
          color: KnotesTheme.border.withValues(alpha: .35),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KnotesTheme.radiusSm),
        borderSide: BorderSide(color: KnotesTheme.accent, width: 2.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        textStyle: buttonText,
        shape: pill,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        foregroundColor: KnotesTheme.textPrimary,
        textStyle: buttonText,
        side: edge,
        shape: pill,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: KnotesTheme.accent,
        textStyle: buttonText.copyWith(fontSize: 14),
        shape: pill,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: KnotesTheme.accent,
        selectedForegroundColor: KnotesTheme.onAccent,
        side: edge,
        textStyle: buttonText.copyWith(fontSize: 13),
        shape: pill,
      ),
    ),
    chipTheme: ChipThemeData(
      showCheckmark: false,
      labelStyle: TextStyle(
        fontFamily: 'Roboto',
        fontWeight: FontWeight.w700,
        color: KnotesTheme.textPrimary,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: 'Roboto',
        fontWeight: FontWeight.w800,
        color: KnotesTheme.onAccent,
      ),
      checkmarkColor: KnotesTheme.onAccent,
      iconTheme: IconThemeData(color: KnotesTheme.accent),
      selectedColor: KnotesTheme.accent,
      backgroundColor: KnotesTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: pill,
      side: WidgetStateBorderSide.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? BorderSide(color: KnotesTheme.accent, width: 1.5)
            : BorderSide(color: KnotesTheme.border.withValues(alpha: .4)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: KnotesTheme.surface,
      indicatorColor: KnotesTheme.accent,
      indicatorShape: pill,
      height: 72,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? KnotesTheme.onAccent
              : KnotesTheme.textSecondary,
        ),
      ),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w800, color: KnotesTheme.textPrimary),
      ),
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: KnotesTheme.pop,
      foregroundColor: KnotesTheme.onPop,
      elevation: 0,
      highlightElevation: 0,
      extendedTextStyle: buttonText,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KnotesTheme.radiusMd),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: KnotesTheme.accent,
      linearTrackColor: KnotesTheme.surfaceContainer,
      circularTrackColor: KnotesTheme.surfaceContainer,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? KnotesTheme.onAccent
            : KnotesTheme.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? KnotesTheme.accent
            : KnotesTheme.surfaceContainer,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: KnotesTheme.accent,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: KnotesTheme.textPrimary,
      ),
      shape: pill,
    ),
    canvasColor: KnotesTheme.surface,
    focusColor: KnotesTheme.accent.withValues(alpha: .14),
    popupMenuTheme: PopupMenuThemeData(
      color: KnotesTheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: KnotesTheme.border.withValues(alpha: .5),
      position: PopupMenuPosition.under,
      menuPadding: const EdgeInsets.all(6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KnotesTheme.radiusMd),
        side: edge,
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(KnotesTheme.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KnotesTheme.radiusMd),
            side: edge,
          ),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: KnotesTheme.textPrimary,
      contentTextStyle: TextStyle(
        color: KnotesTheme.surface,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: KnotesTheme.isDark
          ? KnotesTheme.accent
          : KnotesTheme.accentLight,
      behavior: SnackBarBehavior.floating,
      shape: pill,
    ),
    dividerTheme: DividerThemeData(
      color: KnotesTheme.border.withValues(alpha: .2),
      thickness: 1,
    ),
  );
}
