import 'package:flutter/material.dart';

/// Design tokens del Manual de Marca de Aprueba.
class AppColors {
  AppColors._();

  // Marca
  static const azul = Color(0xFF1A365D);
  static const oro = Color(0xFFF5B041);
  static const exito = Color(0xFF10B981);
  static const error = Color(0xFFEF4444);

  // Medallas
  static const bronze = Color(0xFFCD7F32);
  static const silver = Color(0xFF94A3B8);
  static const gold = Color(0xFFF5B041);
  static const diamond = Color(0xFF38BDF8);
  static const platinum = Color(0xFFA78BFA);

  static Color medalColor(String tier) {
    switch (tier) {
      case 'bronze':
        return bronze;
      case 'silver':
        return silver;
      case 'gold':
        return gold;
      case 'diamond':
        return diamond;
      case 'platinum':
        return platinum;
      default:
        return bronze;
    }
  }

  static const testColors = <String, Color>{
    'lectora': Color(0xFF1A365D),
    'm1': Color(0xFF10B981),
    'm2': Color(0xFF6366F1),
    'cien': Color(0xFFF5B041),
    'hist': Color(0xFFEF4444),
  };
}

/// Tokens dependientes del tema (claro/oscuro) expuestos vía extensión.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.soft,
    required this.brand,
    required this.cta,
    required this.ctaInk,
    required this.chip,
  });

  final Color bg;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color line;
  final Color soft;
  final Color brand;
  final Color cta;
  final Color ctaInk;
  final Color chip;

  static const light = AppTokens(
    bg: Color(0xFFF8FAFC),
    surface: Colors.white,
    ink: Color(0xFF1E293B),
    muted: Color(0xFF64748B),
    line: Color(0xFFCBD5E1),
    soft: Color(0xFFF1F5F9),
    brand: AppColors.azul,
    cta: AppColors.oro,
    ctaInk: AppColors.azul,
    chip: Color(0xFFEEF4FF),
  );

  static const dark = AppTokens(
    bg: Color(0xFF0B1220),
    surface: Color(0xFF131C2E),
    ink: Color(0xFFE2E8F0),
    muted: Color(0xFF94A3B8),
    line: Color(0xFF1E2D45),
    soft: Color(0xFF1A2540),
    brand: Color(0xFF2D5A9E),
    cta: AppColors.oro,
    ctaInk: AppColors.azul,
    chip: Color(0xFF1A2C4A),
  );

  @override
  AppTokens copyWith({
    Color? bg,
    Color? surface,
    Color? ink,
    Color? muted,
    Color? line,
    Color? soft,
    Color? brand,
    Color? cta,
    Color? ctaInk,
    Color? chip,
  }) {
    return AppTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      soft: soft ?? this.soft,
      brand: brand ?? this.brand,
      cta: cta ?? this.cta,
      ctaInk: ctaInk ?? this.ctaInk,
      chip: chip ?? this.chip,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      cta: Color.lerp(cta, other.cta, t)!,
      ctaInk: Color.lerp(ctaInk, other.ctaInk, t)!,
      chip: Color.lerp(chip, other.chip, t)!,
    );
  }
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}

/// Convierte los colores hex que devuelve la API ('#1A365D') en Color.
Color colorFromHex(String? hex, {Color fallback = AppColors.azul}) {
  var value = (hex ?? '').trim().replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return fallback;
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}
