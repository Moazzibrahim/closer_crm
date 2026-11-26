import 'dart:convert'; // 👈 جديد
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/constants/device_helper.dart';
import 'package:flutter_application_1/core/utils/dio_client.dart';
import 'package:flutter_application_1/features/auth/providers/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _auth;
  AuthProvider(this._auth);

  static const String _roleKey = 'role';
  static const String _userKey = 'user'; // 👈 بيانات اليوزر JSON

  bool isLoading = false;
  String? error;
  Map<String, dynamic>? data; // رد الـ login كامل
  Map<String, dynamic>? user; // 👈 بيانات اليوزر لوحدها

  // بندور على اليوزر في أكتر من مكان لأن شكل الرد مش موثّق
  static Map<String, dynamic>? _findUser(Map<String, dynamic> d) {
    final inner = d['data'] is Map ? d['data'] as Map : null;
    for (final c in [d['user'], inner?['user'], inner, d]) {
      if (c is Map && (c.containsKey('email') || c.containsKey('role'))) {
        return Map<String, dynamic>.from(c);
      }
    }
    return null;
  }

  // id اليوزر الحالي (الـ login/restore بيملوا user)
  // بندور على id وبعدين _id عشان شكل الرد مش موثّق
  String? get userId {
    final id = user?['id'] ?? user?['_id'];
    final s = id?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  // ── Getters للـ UI ──
  String get name {
    final u = user;
    if (u == null) return '';
    final full =
        (u['fullName'] ??
                u['name'] ??
                '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}')
            .toString()
            .trim();
    return full;
  }

  String get email => user?['email']?.toString() ?? '';
  String get phone => user?['phone']?.toString() ?? '';

  // ⚠️ اسم حقل الصورة مش مؤكد، عدّله لو الباك بيسميه حاجة تانية
  // الصورة جاية مسار نسبي (/uploads/...) فنركّب عليها الـ base URL
  // الصورة جاية مسار نسبي (/uploads/...) فنركّب عليها الـ host من ApiConfig
  String? get photoUrl {
    final s = user?['avatar']?.toString();
    if (s == null || s.isEmpty) return null;
    if (s.startsWith('http')) return s; // لو جاية كاملة

    final host = ApiConfig.baseUrl; // من غير /api/v1
    return s.startsWith('/') ? '$host$s' : '$host/$s';
  }

  /// الـ role: من اليوزر المحفوظ الأول، وبعدين من رد الـ login
  String? get role {
    dynamic r = user?['role'];
    if (r == null) {
      final d = data;
      if (d != null) {
        dynamic find(Map m) =>
            m['role'] ?? (m['user'] is Map ? m['user']['role'] : null);
        r = find(d) ?? (d['data'] is Map ? find(d['data'] as Map) : null);
      }
    }
    if (r is Map) r = r['name'] ?? r['title'];
    return r?.toString();
  }

  Future<String?> _getFcmToken() async {
    final m = FirebaseMessaging.instance;
    // أحياناً أول مرة بيرجع null (خصوصاً iOS لحد ما APNs يجهز) فبنحاول كام مرة
    for (var i = 0; i < 3; i++) {
      try {
        final t = await m.getToken();
        if (t != null && t.isNotEmpty) return t;
      } catch (e) {
        debugPrint('getToken failed: $e');
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    return null;
  }

  String? _lastSentFcmToken; // عشان ما نبعتش نفس التوكن مرتين

  /// بتبعت التوكن للباك لو اليوزر عامل login.
  /// نادها: بعد restore، وعلى كل onTokenRefresh.
  // ── مفاتيح مزامنة الـ FCM ──
  static const String _kFcmLastToken = 'fcm_last_token'; // آخر توكن اتبعت للباك
  static const String _kFcmLastSyncAt =
      'fcm_last_sync_at'; // وقت آخر مزامنة (ms)
  static const Duration _fcmSyncInterval = Duration(
    hours: 24,
  ); // الفترة بين كل مزامنة

  bool _syncingFcm =
      false; // يمنع تشغيلين بالتوازي (resume + onTokenRefresh مثلاً)

  /// بتبعت التوكن للباك لو اليوزر عامل login، وبس لو:
  ///  - force = true، أو
  ///  - التوكن اتغيّر عن آخر واحد اتبعت، أو
  ///  - عدّى 24 ساعة من آخر مزامنة.
  /// نادها: عند فتح التطبيق، وعند الـ resume، وعلى كل onTokenRefresh.
  Future<void> syncFcmToken({String? token, bool force = false}) async {
    if (_syncingFcm) return;
    _syncingFcm = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString(ApiConfig.tokenKey);
      if (jwt == null || jwt.isEmpty) return; // مش عامل login

      final t = token ?? await _getFcmToken();
      if (t == null || t.isEmpty) return;

      final lastToken = prefs.getString(_kFcmLastToken);
      final lastAt = prefs.getInt(_kFcmLastSyncAt) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - lastAt;
      final due = age >= _fcmSyncInterval.inMilliseconds;

      // لا اتغيّر ولا عدّى يوم → مفيش داعي نكلم الباك
      if (!force && t == lastToken && !due) return;

      final deviceId = await DeviceHelper.getDeviceId();
      await _auth.updateFcmToken(fcmToken: t, deviceId: deviceId);

      _lastSentFcmToken = t;
      await _markFcmSynced(prefs, t); // نحفظ إنها نجحت
      debugPrint('FCM token synced');
    } catch (e) {
      // مش بنحفظ الوقت هنا، فهيتعاد المحاولة في الـ resume الجاي
      debugPrint('syncFcmToken failed: $e');
    } finally {
      _syncingFcm = false;
    }
  }

  Future<void> _markFcmSynced(SharedPreferences prefs, String token) async {
    await prefs.setString(_kFcmLastToken, token);
    await prefs.setInt(_kFcmLastSyncAt, DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> login({required String email, required String password}) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final deviceId = await DeviceHelper.getDeviceId();
      final fcmToken = await _getFcmToken(); // 👈 جديد
      debugPrint('Login with fcmToken: ${fcmToken != null}'); // للتأكد
      data = await _auth.login(
        email: email,
        password: password,
        deviceId: deviceId,
        platform: DeviceHelper.platform,
        fcmToken: fcmToken, // 👈 جديد
      );
      _lastSentFcmToken = fcmToken;
      // 👇 جديد: اللوجين بعت التوكن فعلاً، فنسجّل الوقت عشان ما نبعتهوش تاني فوراً
      if (fcmToken != null) {
        final p = await SharedPreferences.getInstance();
        await _markFcmSynced(p, fcmToken);
      }
      user = _findUser(data!); // 👈
      final prefs = await SharedPreferences.getInstance();
      final r = role;
      if (r != null) await prefs.setString(_roleKey, r);
      if (user != null) await prefs.setString(_userKey, jsonEncode(user)); // 👈
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// 👈 جديد: استرجاع اليوزر المحفوظ بعد ما التطبيق يتفتح (نادها من الـ Splash)
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_userKey);
    if (s == null) return;
    try {
      user = Map<String, dynamic>.from(jsonDecode(s) as Map);
      notifyListeners();
    } catch (_) {}
  }

  static Future<String?> savedRole() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(ApiConfig.tokenKey);
    final role = prefs.getString(_roleKey);
    if (token == null || token.isEmpty || role == null || role.isEmpty) {
      return null;
    }
    return role;
  }

  Future<void> logout() async {
    // الريكويستات الأول (محتاجة الـ token)، والفشل ما يمنعش الخروج
    try {
      final deviceId = await DeviceHelper.getDeviceId();
      final fcm =
          _lastSentFcmToken ?? await FirebaseMessaging.instance.getToken();

      await _auth.logoutRemote(fcmToken: fcm, deviceId: deviceId);
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConfig.tokenKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_userKey);
    await prefs.remove(
      _kFcmLastToken,
    ); // 👈 جديد: اللوجين الجاي لازم يبعت من الأول
    await prefs.remove(_kFcmLastSyncAt);
    _lastSentFcmToken = null;

    user = null;
    data = null;
    error = null;
    notifyListeners();
  }
}
