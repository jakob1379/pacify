import 'package:flutter/material.dart';
import 'package:pacify/features/cadence_detector/presentation/pages/cadence_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pacify',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _pacifyTheme(Brightness.light),
      darkTheme: _pacifyTheme(Brightness.dark),
      home: const CadencePage(),
    );
  }
}

ThemeData _pacifyTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final background = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF0891B2),
        brightness: brightness,
      ).copyWith(
        primary: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0E7490),
        onPrimary: isDark ? const Color(0xFF083344) : Colors.white,
        primaryContainer: isDark
            ? const Color(0xFF164E63)
            : const Color(0xFFCFFAFE),
        onPrimaryContainer: isDark
            ? const Color(0xFFCFFAFE)
            : const Color(0xFF164E63),
        secondary: isDark ? const Color(0xFFFBBF24) : const Color(0xFFA16207),
        onSecondary: isDark ? const Color(0xFF422006) : Colors.white,
        secondaryContainer: isDark
            ? const Color(0xFF78350F)
            : const Color(0xFFFEF3C7),
        onSecondaryContainer: isDark
            ? const Color(0xFFFEF3C7)
            : const Color(0xFF78350F),
        tertiary: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
        onTertiary: isDark ? const Color(0xFF052E16) : Colors.white,
        tertiaryContainer: isDark
            ? const Color(0xFF14532D)
            : const Color(0xFFDCFCE7),
        onTertiaryContainer: isDark
            ? const Color(0xFFDCFCE7)
            : const Color(0xFF14532D),
        surface: isDark ? const Color(0xFF111827) : Colors.white,
        onSurface: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
        onSurfaceVariant: isDark
            ? const Color(0xFFCBD5E1)
            : const Color(0xFF475569),
        surfaceContainerLowest: isDark ? const Color(0xFF0B1220) : Colors.white,
        surfaceContainerLow: isDark
            ? const Color(0xFF111827)
            : const Color(0xFFF8FAFC),
        surfaceContainer: isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFFE2E8F0),
        surfaceContainerHigh: isDark
            ? const Color(0xFF334155)
            : const Color(0xFFCBD5E1),
        surfaceContainerHighest: isDark
            ? const Color(0xFF475569)
            : const Color(0xFF94A3B8),
        outline: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        outlineVariant: isDark
            ? const Color(0xFF334155)
            : const Color(0xFFCBD5E1),
        error: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
        onError: isDark ? const Color(0xFF450A0A) : Colors.white,
        errorContainer: isDark
            ? const Color(0xFF7F1D1D)
            : const Color(0xFFFEE2E2),
        onErrorContainer: isDark
            ? const Color(0xFFFEE2E2)
            : const Color(0xFF7F1D1D),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: scheme.surface,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(48, 48),
      ),
    ),
  );
}
