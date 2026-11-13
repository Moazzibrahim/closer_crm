// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/constants/main_shell.dart'; // عدّل المسار حسب مكان الملف
import 'package:flutter_application_1/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_application_1/features/auth/providers/auth_provider.dart';
import 'package:flutter_application_1/features/splash/closer_logo.dart';
import 'package:provider/provider.dart';

/// ============================================================
/// SPLASH SCREEN
/// ============================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro; // دخول العناصر بالتتابع
  late final AnimationController _pulse; // نبض الحلقات (بيتكرر)

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _tagFade;

  // حجم اللوجو في السبلاش
  static const double _logoSize = 110;
  static const Duration _splashDuration = Duration(milliseconds: 2500);

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // اللوجو الأول
    _logoFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );

    // بعده الاسم (بيطلع من تحت)
    _titleFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _intro,
            curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    // وآخر حاجة الـ tagline
    _tagFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );

    _intro.forward();

    Timer(_splashDuration, _goNext);
  }

  /// لو فيه session محفوظة (token + role) → ادخل على الشاشة الرئيسية مباشرة،
  /// غير كده → شاشة اللوجين.
  Future<void> _goNext() async {
    // استرجع بيانات اليوزر المحفوظة قبل أي تنقل
    await context.read<AuthProvider>().restore();

    final savedRole = await AuthProvider.savedRole();
    if (!mounted) return;

    final role = userRoleFromString(savedRole);
    final Widget next = role != null
        ? MainShell(role: role)
        : const LoginScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => next,
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        children: [
          // ── Background: gradient + dot grid ──
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  // 👈 كان Color(0xFF0E2A44) كحلي. بقى navyLight (رمادي غامق)
                  // عشان يفضل فيه تدرّج خفيف في النص بدل أسود مسطح
                  colors: [AppColors.navy, AppColors.navyLight, AppColors.navy],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _DotsPainter())),

          // ── Center content ──
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo + glow + pulsing rings
                SizedBox(
                  width: 260,
                  height: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // توهّج دهبي ناعم ورا اللوجو
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.gold.withOpacity(0.22),
                              AppColors.gold.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),

                      // حلقتين بينبضوا (الثانية متأخرة نص دورة)
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, _) => Stack(
                          alignment: Alignment.center,
                          children: [
                            _ring(_pulse.value),
                            _ring((_pulse.value + 0.5) % 1.0),
                          ],
                        ),
                      ),

                      // اللوجو
                      FadeTransition(
                        opacity: _logoFade,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                _logoSize * 0.24,
                              ),
                              border: Border.all(
                                color: AppColors.gold.withOpacity(0.35),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 30,
                                  offset: const Offset(0, 14),
                                ),
                                BoxShadow(
                                  color: AppColors.gold.withOpacity(0.18),
                                  blurRadius: 40,
                                ),
                              ],
                            ),
                            child: const CloserMark(size: _logoSize),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // اسم التطبيق: closer (أبيض) + crm (دهبي)
                FadeTransition(
                  opacity: _titleFade,
                  child: SlideTransition(
                    position: _titleSlide,
                    child: Text.rich(
                      const TextSpan(
                        children: [
                          TextSpan(
                            text: 'closer',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: 'crm',
                            style: TextStyle(color: AppColors.gold),
                          ),
                        ],
                      ),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Tagline بين خطين دهبي
                FadeTransition(
                  opacity: _tagFade,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _line(),
                      const SizedBox(width: 10),
                      Text(
                        'Manage. Connect. Grow.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _line(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom: loading bar + footer ──
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _tagFade,
              child: Column(
                children: [
                  // شريط تحميل بيتملى على مدة السبلاش
                  SizedBox(
                    width: 120,
                    height: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: _splashDuration,
                        curve: Curves.easeInOut,
                        builder: (_, v, _) => LinearProgressIndicator(
                          value: v,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.gold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'YOUR REAL ESTATE MANAGEMENT PLATFORM',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 9,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // حلقة نبض: بتكبر وبتختفي (t من 0 → 1)
  Widget _ring(double t) {
    final size = _logoSize + 20 + (t * 110);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.gold.withOpacity((1 - t) * 0.35),
          width: 1.2,
        ),
      ),
    );
  }

  Widget _line() =>
      Container(width: 22, height: 1, color: AppColors.gold.withOpacity(0.5));
}

/// نقاط خفيفة في الخلفية (dot grid)
class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.045);
    const gap = 28.0;
    for (double x = gap / 2; x < size.width; x += gap) {
      for (double y = gap / 2; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
