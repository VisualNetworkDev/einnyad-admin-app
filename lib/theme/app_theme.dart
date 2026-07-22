import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const brand = Color(0xFFA84D70);
  static const brandDark = Color(0xFF7D3F58);
  static const ink = Color(0xFF2D131E);
  static const soft = Color(0xFFF8E8EF);

  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: brightness,
      primary: dark ? const Color(0xFFF2A9C5) : brandDark,
      secondary: dark ? const Color(0xFFFFC1D8) : brand,
      surface: dark ? const Color(0xFF251B20) : const Color(0xFFFFFDFB),
      error: dark ? const Color(0xFFFFB4AB) : const Color(0xFFB42345),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF181216)
          : const Color(0xFFFFF7FA),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: dark ? const Color(0xFF251B20) : Colors.white,
        foregroundColor: dark ? Colors.white : ink,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: dark ? const Color(0xFF251B20) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF30252B) : Colors.white,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: dark ? const Color(0xFF20171B) : Colors.white,
        indicatorColor: dark ? const Color(0xFF513343) : soft,
        indicatorSize: const Size(250, 56),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }
}
