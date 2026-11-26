// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package

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
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_application_1/features/splash/splash_screen.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

/// ============================================================
/// Local notifications (top-level عشان الـ background isolate يشوفهم)
/// ============================================================

final FlutterLocalNotificationsPlugin _local =
    FlutterLocalNotificationsPlugin(); // 👈 اتنقل برّه الكلاس

// channel بـ importance عالية عشان يطلع heads-up
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'high_importance_channel',
  'Notifications',
  importance: Importance.high,
); // 👈 اتنقل برّه الكلاس

Future<void> _initLocalNotifications() async {
  await _local.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings(
        '@mipmap/ic_launcher', // لازم يكون موجود في mipmap
      ),
      iOS: DarwinInitializationSettings(),
    ),
  );
  await _local
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(_channel);
}

/// بتعرض الإشعار وانت جوه التطبيق (الأندرويد مش بيعرضه لوحده في الـ foreground)
void _showLocal(RemoteMessage m) {
  final n = m.notification;
  if (n == null) return;
  _local.show(
    id: n.hashCode,
    title: n.title,
    body: n.body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    ),
  );
}

/// ============================================================
/// بتطبع كل تفاصيل الرسالة اللي وصلت من FCM
/// ============================================================
void _logMessage(String source, RemoteMessage m) {
  debugPrint('══════════ [$source] ══════════');
  debugPrint('messageId : ${m.messageId}');
  debugPrint('sentTime  : ${m.sentTime}');
  debugPrint('received  : ${DateTime.now()}');
  debugPrint('from      : ${m.from}');
  debugPrint('title     : ${m.notification?.title}');
  debugPrint('body      : ${m.notification?.body}');
  debugPrint('data      : ${m.data}');
  debugPrint('hasNotificationPayload: ${m.notification != null}');
  debugPrint('═══════════════════════════════');
}

class AppBackObserver extends StatefulWidget {
  final Widget child;

  const AppBackObserver({super.key, required this.child});

  @override
  State<AppBackObserver> createState() => _AppBackObserverState();
}

class _AppBackObserverState extends State<AppBackObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  // 👇 جديد: كل ما التطبيق يرجع من الخلفية نشوف لو عدّى يوم
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // بتتجاهل نفسها لو لسه ماعدّاش 24 ساعة، فمفيش request زيادة
      context.read<AuthProvider>().syncFcmToken();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(canPop: false, child: widget.child);
  }
}

/// ============================================================
/// FIREBASE BACKGROUND MESSAGE
/// لازم يفضل top-level function + @pragma عشان يشتغل والتطبيق مقفول
/// ============================================================

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  _logMessage('BACKGROUND', message);
  // ⚠️ مش بنعرض local notification هنا: لو الرسالة فيها notification payload
  // النظام بيعرضها بنفسه، ولو عرضناها كمان هتظهر مرتين.
}

/// ============================================================
/// MAIN
/// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _initLocalNotifications(); // 👈 جديد: كان ناقص

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
  late final AuthProvider _authProvider = AuthProvider(AuthService());

  @override
  void initState() {
    super.initState();
    _initMessaging(); // مقصود من غير await: ما نعطّلش أول frame
  }

  Future<void> _initMessaging() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);
    if (!mounted) return;

    // التوكن بيتطبع في الـ debug بس
    if (kDebugMode) {
      final token = await messaging.getToken();
      debugPrint('====================================');
      debugPrint('FCM TOKEN: $token');
      debugPrint('====================================');
    }

    if (!mounted) return;

    _subs.add(
      messaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM TOKEN REFRESHED: $newToken');
        // التوكن اتغيّر فعلاً → ابعته فوراً بغض النظر عن الـ 24 ساعة
        _authProvider.syncFcmToken(token: newToken, force: true);
      }),
    );

    // 👇 جديد: عند فتح التطبيق، يبعت لو عدّى يوم أو التوكن اتغيّر وهو مقفول
    unawaited(_authProvider.syncFcmToken());
    // التطبيق مفتوح (foreground)
    _subs.add(
      FirebaseMessaging.onMessage.listen((message) {
        _logMessage('FOREGROUND', message);
        _showLocal(message); // 👈 جديد: كان ناقص، ده اللي بيظهر الإشعار
        NotificationBadge.refresh();
      }),
    );

    // التطبيق كان في الخلفية واليوزر داس على الإشعار
    _subs.add(
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _logMessage('OPENED_APP', message);
        NotificationBadge.refresh();
      }),
    );

    // التطبيق كان مقفول تماماً واتفتح من الإشعار
    final initial = await messaging.getInitialMessage();
    if (initial != null) _logMessage('TERMINATED_OPEN', initial);
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _authProvider.dispose(); // 👈 جديد
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider), // 👈 بدل create
        ChangeNotifierProvider(create: (_) => CrmSettingsProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Closer CRM ',
        theme: _theme,
        home: AppBackObserver(child: const SplashScreen()),
      ),
    );
  }
}

ThemeData _buildTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.gold),
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
