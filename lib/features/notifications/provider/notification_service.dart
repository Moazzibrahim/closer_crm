// lib/features/notifications/data/notification_service.dart
// POST /notifications/test — يبعت إشعار تجريبي لكل أجهزة اليوزر المسجلة

// ignore_for_file: avoid_print

import 'package:dio/dio.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/utils/dio_client.dart';

// ───────────── Models ─────────────

/// جهاز مسجل لليوزر
class NotificationDevice {
  final String deviceId;
  final String deviceName;
  final String platform; // android / ios / web
  final bool hasToken; // false = الجهاز ده مش هيستلم إشعارات
  final DateTime? lastLoginAt;

  const NotificationDevice({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.hasToken,
    this.lastLoginAt,
  });

  factory NotificationDevice.fromJson(Map<String, dynamic> j) =>
      NotificationDevice(
        deviceId: (j['deviceId'] ?? '').toString(),
        deviceName: (j['deviceName'] ?? '').toString(),
        platform: (j['platform'] ?? '').toString(),
        hasToken: j['hasToken'] == true,
        lastLoginAt: DateTime.tryParse((j['lastLoginAt'] ?? '').toString()),
      );
}

/// خطأ في إرسال إشعار لتوكن واحد (مثلاً الجهاز اتشال)
class NotificationSendError {
  final String code; // زي messaging/registration-token-not-registered
  final String message;
  const NotificationSendError({required this.code, required this.message});

  factory NotificationSendError.fromJson(Map<String, dynamic> j) =>
      NotificationSendError(
        code: (j['code'] ?? '').toString(),
        message: (j['message'] ?? '').toString(),
      );
}

/// نتيجة الإشعار التجريبي
class NotificationTestResult {
  final int sent;
  final int failed;
  final int removedTokens; // توكنات ميتة السيرفر مسحها تلقائياً
  final List<NotificationSendError> errors;
  final List<NotificationDevice> devices;

  const NotificationTestResult({
    required this.sent,
    required this.failed,
    required this.removedTokens,
    required this.errors,
    required this.devices,
  });

  /// عدد الأجهزة اللي عندها FCM token (يعني تقدر تستلم)
  int get devicesWithToken => devices.where((d) => d.hasToken).length;

  factory NotificationTestResult.fromJson(Map<String, dynamic> j) {
    int toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    List<T> list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
        (v is List ? v : const [])
            .whereType<Map<String, dynamic>>()
            .map(f)
            .toList();

    return NotificationTestResult(
      sent: toInt(j['sent']),
      failed: toInt(j['failed']),
      removedTokens: toInt(j['removedTokens']),
      errors: list(j['errors'], NotificationSendError.fromJson),
      devices: list(j['devices'], NotificationDevice.fromJson),
    );
  }
}

class NotificationException implements Exception {
  final String message;
  final int? statusCode;
  NotificationException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

// ───────────── Service ─────────────

class NotificationService {
  // Dio instance المشترك: الـ baseUrl والـ Authorization بيتضافوا
  // تلقائياً من الـ interceptor في DioClient
  final Dio _dio = DioClient.instance.dio;

  /// POST /notifications/test — من غير body
  Future<NotificationTestResult> sendTest() async {
    try {
      final res = await _dio.post(Endpoints.notificationTest);

      Map<String, dynamic> body = {};
      final decoded = res.data;
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);

      final code = res.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        // التفاصيل في الكونسول بس
        print('Notification test → $code\n${res.data}');
        throw NotificationException(
          (body['message'] ?? 'Request failed').toString(),
          statusCode: code,
        );
      }

      // الرد ممكن يكون مباشرة، أو جوه data
      final data = body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : body;
      return NotificationTestResult.fromJson(data);
    } on NotificationException {
      rethrow;
    } on DioException catch (e) {
      // timeout
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw NotificationException('Request timed out');
      }

      // السيرفر رد بـ status مش 2xx
      final res = e.response;
      if (res != null) {
        Map<String, dynamic> body = {};
        if (res.data is Map) body = Map<String, dynamic>.from(res.data as Map);
        // التفاصيل في الكونسول بس
        print('Notification test → ${res.statusCode}\n${res.data}');
        throw NotificationException(
          (body['message'] ?? 'Request failed').toString(),
          statusCode: res.statusCode,
        );
      }

      print('Notification test failed: $e');
      throw NotificationException('No internet connection');
    } catch (e) {
      print('Notification test failed: $e');
      throw NotificationException('No internet connection');
    }
  }
}
