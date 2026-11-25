// lib/features/splash/closer_logo.dart
// لوجو Closer CRM: خلفية كحلي gradient + حرف C تيل gradient + نقطة برتقالي
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';

// ألوان اللوجو من الدوكيومنت
const _logoBgA = Color(0xFF0E3D58);
const _logoBgB = Color(0xFF061D2D);
const _logoCA = Color(0xFF31D8C8);
const _logoCB = Color(0xFF0590AB);
const _logoDot = Color(0xFFFF7A59);

/// الأيقونة لوحدها (Header / Splash / Login)
class CloserMark extends StatelessWidget {
  final double size;
  const CloserMark({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _MarkPainter()),
  );
}

/// الأيقونة + الاسم: Closer (أبيض/غامق حسب الخلفية) + CRM (لون خفيف)
class CloserLogo extends StatelessWidget {
  final double size;
  final bool wordmark;
  final Color background; // لون الخلفية اللي اللوجو فوقها
  const CloserLogo({
    super.key,
    this.size = 48,
    this.wordmark = true,
    this.background = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final onDark =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CloserMark(size: size),
        if (wordmark) ...[
          SizedBox(width: size * 0.25),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Closer',
                  style: TextStyle(
                    color: onDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: ' CRM',
                  // CRM بلون أهدى، زي اللوجو في الـ PDF
                  style: TextStyle(
                    color: onDark ? Colors.white60 : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: size * 0.46,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100);
    const box = Rect.fromLTWH(0, 0, 100, 100);
    final rrect = RRect.fromRectAndRadius(box, const Radius.circular(24));

    // الخلفية: gradient كحلي
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          colors: [_logoBgA, _logoBgB],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(box),
    );
    // حد خفيف
    canvas.drawRRect(
      rrect.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withOpacity(0.10),
    );

    // حرف C: قوس 280° والفتحة ناحية اليمين، بـ gradient تيل
    final arcRect = Rect.fromCircle(center: const Offset(48, 50), radius: 24);
    canvas.drawArc(
      arcRect,
      0.698, // 40°
      4.887, // 280°
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: [_logoCA, _logoCB],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(arcRect),
    );

    // النقطة البرتقاني اللي في الفتحة
    canvas.drawCircle(const Offset(76, 50), 8, Paint()..color = _logoDot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
