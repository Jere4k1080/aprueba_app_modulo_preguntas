import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';

/// Estrellas de valoración (medias estrellas incluidas).
class StarRating extends StatelessWidget {
  const StarRating(this.value, {super.key, this.size = 13, this.color = AppColors.oro});
  final double value;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          value >= i
              ? Icons.star_rounded
              : (value >= i - 0.5 ? Icons.star_half_rounded : Icons.star_border_rounded),
          size: size,
          color: color,
        ),
    ]);
  }
}

/// Selector de estrellas 1..5 (pantalla de reseña).
class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.value, required this.onChanged, this.size = 30});
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 1; i <= 5; i++)
        IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          constraints: const BoxConstraints(),
          onPressed: () => onChanged(i),
          icon: Icon(
            i <= value ? Icons.star_rounded : Icons.star_border_rounded,
            size: size,
            color: AppColors.oro,
          ),
        ),
    ]);
  }
}

/// Avatar circular con iniciales, con los colores que envía la API.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.initials,
    this.background = '#1A365D',
    this.foreground = '#FFFFFF',
    this.size = 44,
  });
  final String initials;
  final String background;
  final String foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colorFromHex(background), shape: BoxShape.circle),
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          color: colorFromHex(foreground, fallback: Colors.white),
          fontWeight: FontWeight.w700,
          fontFamily: 'Montserrat',
          fontSize: size * .32,
        ),
      ),
    );
  }
}

/// Iniciales seguras para nombres vacíos o de una sola letra.
String initialsFrom(String? name, {String fallback = 'AL'}) {
  final clean = (name ?? '').trim();
  if (clean.isEmpty) return fallback;
  final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
}

/// Precio por hora formateado según la moneda que informa el tutor.
String tutorPrice(Tutor tutor, String localeCode) {
  final format = NumberFormat.currency(
    locale: localeCode == 'en' ? 'en_GB' : 'es_CL',
    symbol: tutor.currency == 'GBP' ? '£' : '\$',
    decimalDigits: tutor.currency == 'GBP' ? 2 : 0,
  );
  return format.format(tutor.pricePerHour);
}

/// Etiqueta relativa simple para las fechas del chat y las reseñas.
String relativeDate(DateTime? date, String localeCode) {
  if (date == null) return '';
  final en = localeCode == 'en';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return en ? 'now' : 'ahora';
  if (diff.inMinutes < 60) return en ? '${diff.inMinutes}m ago' : 'hace ${diff.inMinutes}m';
  if (diff.inHours < 24) return en ? '${diff.inHours}h ago' : 'hace ${diff.inHours}h';
  if (diff.inDays < 30) return en ? '${diff.inDays}d ago' : 'hace ${diff.inDays}d';
  final months = (diff.inDays / 30).floor();
  return en ? '${months}mo ago' : 'hace ${months}m';
}

/// Banner de "requiere plan de pago" con acceso al paywall.
class PremiumNotice extends StatelessWidget {
  const PremiumNotice({super.key, required this.message, required this.onUpgrade, this.cta});
  final String message;
  final VoidCallback onUpgrade;
  final String? cta;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onUpgrade,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.brand.withOpacity(.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.brand, width: 1.5),
        ),
        child: Row(children: [
          const Text('🔓', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.ink)),
          ),
          if (cta != null) ...[
            const SizedBox(width: 8),
            Text(cta!,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: t.brand, fontFamily: 'Montserrat')),
          ],
        ]),
      ),
    );
  }
}
