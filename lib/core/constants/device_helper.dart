// device_helper.dart
// بيحدد الـ platform الحقيقي للموبايل (android/ios) ويولّد deviceId ثابت للجهاز.
// مفيش dependencies إضافية — بس flutter و shared_preferences.
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceHelper {
  /// 'ios' لو الجهاز iPhone/iPad، غير كده 'android'
  static String get platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// deviceId بيتولّد مرة واحدة ويتخزن، فنفس الجهاز يبعت نفس القيمة كل لوجين
  /// (الباك بيستخدمه عشان يفرّق بين جلسات الأجهزة).
  /// ملاحظة: بيتغير لو التطبيق اتمسح وانزّل تاني.
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(ApiConfig.deviceIdKey);
    if (cached != null && cached.isNotEmpty) return cached;

    final rnd = Random.secure();
    final random = List.generate(16, (_) => rnd.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final id = '$platform-$random';

    await prefs.setString(ApiConfig.deviceIdKey, id);
    return id;
  }
}