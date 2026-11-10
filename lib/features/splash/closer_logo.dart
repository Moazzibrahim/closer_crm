// lib/core/widgets/closer_logo.dart
// لوجو closercrm: حرف C دهبي مفتوح + نقطة بتقرّب من الفتحة (= "closer" / قفل الصفقة)
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';

/// الأيقونة لوحدها (للـ Header / Splash / Login)
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

/// الأيقونة + اسم التطبيق (closer أبيض/كحلي + crm دهبي)
class CloserLogo extends StatelessWidget {
  final double size;
  final bool wordmark;
  const CloserLogo({super.key, this.size = 48, this.wordmark = true});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
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
                  text: 'closer',
                  style: TextStyle(color: dark ? Colors.white : AppColors.navy),
                ),
                const TextSpan(
                  text: 'crm',
                  style: TextStyle(color: AppColors.gold),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: size * 0.46,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
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

    // الخلفية
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          colors: [AppColors.navy, AppColors.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(box),
    );
    canvas.drawRRect(
      rrect.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.gold.withOpacity(0.5),
    );

    // حرف C (قوس 280° والفتحة ناحية اليمين)
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(48, 50), radius: 24),
      0.698, // 40°
      4.887, // 280°
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = AppColors.gold,
    );

    // النقطة اللي بتقفل الفتحة
    canvas.drawCircle(
      const Offset(76, 50),
      9,
      Paint()..color = AppColors.gold.withOpacity(0.18),
    );
    canvas.drawCircle(
      const Offset(76, 50),
      5,
      Paint()..color = AppColors.goldLight,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}