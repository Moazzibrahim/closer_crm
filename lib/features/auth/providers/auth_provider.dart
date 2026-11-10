import 'dart:convert'; // 👈 جديد
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

  Future<bool> login({required String email, required String password}) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final deviceId = await DeviceHelper.getDeviceId();
      data = await _auth.login(
        email: email,
        password: password,
        deviceId: deviceId,
        platform: DeviceHelper.platform,
      );

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
      await _auth.logoutRemote();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConfig.tokenKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_userKey);

    user = null;
    data = null;
    error = null;
    notifyListeners();
  }
}
