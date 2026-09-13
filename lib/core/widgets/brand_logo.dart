import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Isotipo "Aprueba" reproducido con CustomPaint (mismas formas del wireframe).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 26, this.showName = false});
  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter()),
    );
    if (!showName) return mark;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      mark,
      const SizedBox(width: 8),
      Text('Aprueba',
          style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w800,
              fontSize: size * 0.62,
              color: AppColors.azul)),
    ]);
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width / 30, h = s.height / 30;
    final azul = Paint()..color = AppColors.azul;
    final oro = Paint()..color = AppColors.oro;
    Path poly(List<Offset> pts) {
      final p = Path()..moveTo(pts.first.dx * w, pts.first.dy * h);
      for (final pt in pts.skip(1)) {
        p.lineTo(pt.dx * w, pt.dy * h);
      }
      return p..close();
    }

    canvas.drawPath(poly([const Offset(3, 27), const Offset(9, 6), const Offset(13, 6), const Offset(8, 27)]), azul);
    canvas.drawPath(poly([const Offset(27, 27), const Offset(21, 6), const Offset(17, 6), const Offset(22, 27)]), azul);
    canvas.drawRect(Rect.fromLTWH(7 * w, 14 * h, 16 * w, 4 * h), azul);
    canvas.drawRect(Rect.fromLTWH(12 * w, 14 * h, 6 * w, 10 * h), oro);
    canvas.drawPath(poly([const Offset(15, 5), const Offset(12, 10), const Offset(18, 10)]), oro);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
