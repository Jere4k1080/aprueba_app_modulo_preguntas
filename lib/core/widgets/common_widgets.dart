import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Tarjeta con el estilo del prototipo (relleno soft, borde line).
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.onTap, this.padding, this.borderColor, this.background});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final Color? borderColor;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: background ?? t.soft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor ?? t.line, width: 1.5),
        ),
        child: child,
      ),
    );
  }
}

/// Barra de progreso fina.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.color, this.height = 8});
  final double value; // 0..1
  final Color? color;
  final double height;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: t.line,
        valueColor: AlwaysStoppedAnimation(color ?? t.brand),
      ),
    );
  }
}

/// Botón primario (oro) a ancho completo.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ]),
    );
  }
}

/// Chip seleccionable (pruebas, materia).
class SelectChip extends StatelessWidget {
  const SelectChip({super.key, required this.label, required this.selected, this.color, this.onTap});
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? t.brand : t.chip,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? t.brand : Colors.transparent, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (color != null) ...[
            Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : t.ink)),
        ]),
      ),
    );
  }
}

/// Etiqueta pequeña (tag) con variantes de color.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.variant = 'n'});
  final String text;
  final String variant; // n | g | w | d
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    late Color bg, fg;
    switch (variant) {
      case 'g':
        bg = AppColors.exito.withOpacity(.13);
        fg = const Color(0xFF059669);
        break;
      case 'w':
        bg = AppColors.oro.withOpacity(.18);
        fg = const Color(0xFFB45309);
        break;
      case 'd':
        bg = AppColors.error.withOpacity(.13);
        fg = const Color(0xFFDC2626);
        break;
      default:
        bg = t.chip;
        fg = t.muted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
