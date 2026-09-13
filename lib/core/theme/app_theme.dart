import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // Si no añades las fuentes, Flutter usará la fuente del sistema sin romperse.
  static const _heading = 'Montserrat';
  static const _body = 'Inter';

  static ThemeData light() => _base(AppTokens.light, Brightness.light);
  static ThemeData dark() => _base(AppTokens.dark, Brightness.dark);

  static ThemeData _base(AppTokens t, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.azul,
      brightness: brightness,
      primary: t.brand,
      secondary: AppColors.oro,
      error: AppColors.error,
      surface: t.surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.bg,
      fontFamily: _body,
      extensions: [t],
      textTheme: _textTheme(t.ink),
      appBarTheme: AppBarTheme(
        backgroundColor: t.surface,
        foregroundColor: t.brand,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _heading,
          fontWeight: FontWeight.w800,
          fontSize: 16,
          color: t.brand,
        ),
      ),
      cardTheme: CardThemeData(
        color: t.soft,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: t.line, width: 1.5),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.soft,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: t.line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: t.line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: t.brand, width: 1.5),
        ),
        hintStyle: TextStyle(color: t.muted, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.cta,
          foregroundColor: t.ctaInk,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: _heading,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: t.line, thickness: 1, space: 1),
    );
  }

  static TextTheme _textTheme(Color ink) {
    return TextTheme(
      headlineMedium: TextStyle(
          fontFamily: _heading, fontWeight: FontWeight.w800, color: ink),
      titleLarge: TextStyle(
          fontFamily: _heading,
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: ink),
      titleMedium: TextStyle(
          fontFamily: _heading,
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: ink),
      bodyMedium: TextStyle(fontFamily: _body, fontSize: 14, color: ink),
      bodySmall: TextStyle(fontFamily: _body, fontSize: 12, color: ink),
    );
  }
}
