import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BrandMark extends StatelessWidget {
  final double size;
  final bool onDark;

  const BrandMark({
    super.key,
    this.size = 56,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : AppColors.brand;
    final bg = onDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.brandSoft;
    final ringColor = onDark
        ? Colors.white.withValues(alpha: 0.18)
        : AppColors.brand.withValues(alpha: 0.18);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BrandMarkPainter(
          background: bg,
          foreground: fg,
          ring: ringColor,
        ),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  final Color background;
  final Color foreground;
  final Color ring;

  _BrandMarkPainter({
    required this.background,
    required this.foreground,
    required this.ring,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    final bgPaint = Paint()..color = background;
    canvas.drawCircle(center, radius, bgPaint);

    final ringPaint = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.03;
    canvas.drawCircle(center, radius - ringPaint.strokeWidth, ringPaint);

    final boltPaint = Paint()
      ..color = foreground
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.56, h * 0.18)
      ..lineTo(w * 0.30, h * 0.55)
      ..lineTo(w * 0.46, h * 0.55)
      ..lineTo(w * 0.40, h * 0.82)
      ..lineTo(w * 0.70, h * 0.42)
      ..lineTo(w * 0.54, h * 0.42)
      ..close();

    canvas.drawPath(path, boltPaint);
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter oldDelegate) =>
      background != oldDelegate.background ||
      foreground != oldDelegate.foreground ||
      ring != oldDelegate.ring;
}
