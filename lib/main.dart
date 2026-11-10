// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/features/auth/providers/auth_provider.dart';
import 'package:flutter_application_1/features/auth/providers/auth_service.dart';
import 'package:flutter_application_1/features/auth/providers/crm_settings.dart';
import 'package:flutter_application_1/features/notifications/provider/notifications_provider.dart';
import 'package:flutter_application_1/features/splash/splash_screen.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

/// ============================================================
/// FIREBASE BACKGROUND MESSAGE
/// لازم يفضل top-level function + @pragma عشان يشتغل والتطبيق مقفول
/// ============================================================

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint('BACKGROUND NOTIFICATION');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
  debugPrint('Data: ${message.data}');
}

/// ============================================================
/// MAIN
/// بس الحاجات اللي لازم تخلص قبل أول frame (Firebase init + background handler).
/// الباقي (permission, token, listeners) اتنقل لجوه الـ State تحت
/// عشان ما يعطّلش فتح التطبيق وعشان الـ subscriptions تتقفل صح.
/// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const CRMRealEstateApp());
}

/// ============================================================
/// APP
/// ============================================================

class CRMRealEstateApp extends StatefulWidget {
  const CRMRealEstateApp({super.key});

  @override
  State<CRMRealEstateApp> createState() => _CRMRealEstateAppState();
}

class _CRMRealEstateAppState extends State<CRMRealEstateApp> {
  // كل الـ subscriptions هنا عشان نقفلها كلها في dispose
  final List<StreamSubscription<dynamic>> _subs = [];

  // الـ theme بيتبني مرة واحدة بدل ما يتبني مع كل build
  final ThemeData _theme = _buildTheme();

  @override
  void initState() {
    super.initState();
    _initMessaging(); // مقصود من غير await: ما نعطّلش أول frame
  }

  Future<void> _initMessaging() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);
    if (!mounted) return;

    // التوكن بيتطبع في الـ debug بس (مش بنسيّب توكن في logs الـ release)
    if (kDebugMode) {
      final token = await messaging.getToken();
      debugPrint('====================================');
      debugPrint('FCM TOKEN: $token');
      debugPrint('====================================');
    }

    // لو الـ State اتقفل أثناء الـ await فوق، ما نضيفش subscriptions جديدة
    if (!mounted) return;

    _subs.add(
      messaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM TOKEN REFRESHED: $newToken');
      }),
    );

    _subs.add(
      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('FOREGROUND NOTIFICATION');
        debugPrint('Title: ${message.notification?.title}');
        debugPrint('Body: ${message.notification?.body}');
        debugPrint('Data: ${message.data}');
        NotificationBadge.refresh(); // 👈 حدّث رقم الجرس فوراً
      }),
    );
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // الـ create form: الـ provider بيعمل dispose للـ instance لوحده.
        // lazy افتراضياً: مش بيتعمل غير أول ما حد يقراه (LoginScreen).
        // ما تستخدمش .value مع instance جديد (new) — ده بيعمل leak لأن محدش بيعمل له dispose.
        ChangeNotifierProvider(create: (_) => AuthProvider(AuthService())),
        ChangeNotifierProvider(create: (_) => CrmSettingsProvider()), // 👈 جديد
        // providers الـ features (Leads, Users, ...) مكانها MainShell مش هنا،
        // عشان تتقفل تلقائي مع الـ logout.
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'CRM Real Estate',
        theme: _theme,
        home: const SplashScreen(),
      ),
    );
  }
}

ThemeData _buildTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.navy),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
      ),
    ),
  );
}
