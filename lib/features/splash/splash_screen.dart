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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // حجم اللوجو في السبلاش
  static const double _logoSize = 110;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    Timer(const Duration(milliseconds: 2500), _goNext);
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        children: [
          // Decorative circle
          Positioned(
            top: -120,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.navyLight.withOpacity(0.5),
              ),
            ),
          ),

          // Decorative circle
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.navyLight.withOpacity(0.35),
              ),
            ),
          ),

          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// LOGO (الأيقونة الجديدة)
                    // الـ Container هنا بس عشان الظل، لأن الأيقونة نفسها
                    // خلفيتها navy ومش هتبان على خلفية السبلاش من غير ظل
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_logoSize * 0.24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: const CloserMark(size: _logoSize),
                    ),

                    const SizedBox(height: 28),

                    /// اسم التطبيق: closer (أبيض) + crm (دهبي)
                    // السبلاش دايماً navy فاللون الأبيض ثابت (مش بيعتمد على الثيم)
                    Text.rich(
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
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Manage. Connect. Grow.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 35,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'YOUR REAL ESTATE MANAGEMENT PLATFORM',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 9,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
