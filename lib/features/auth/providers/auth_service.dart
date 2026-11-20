// auth_service.dart
// Login + إدارة المستخدمين (Admin) + تغيير الباسورد + الجلسات.
// ignore_for_file: use_null_aware_elements, avoid_print

import 'package:dio/dio.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/utils/dio_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final Dio _dio = DioClient.instance.dio;

  /// Login: الباك محتاج deviceId و platform (الاتنين بييجوا من DeviceHelper عن طريق AuthProvider)
  /// ملاحظة: شكل رد الباك مش موجود في الـ collection (response فاضي)،
  /// فالـ token بقراه من data['token'] أو data['data']['token'] — عدّل لو مختلف.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String deviceId,
    String? fcmToken,
    required String
    platform, // 'android' | 'ios' — بييجي من DeviceHelper.platform
  }) async {
    try {
      final res = await _dio.post(
        Endpoints.login,
        data: {
          'email': email,
          'password': password,
          'deviceId': deviceId,
          'platform': platform,
          if (fcmToken != null) 'fcmToken': fcmToken,
        },
      );

      final body = Map<String, dynamic>.from(res.data as Map);
      final token =
          body['token'] ?? (body['data'] is Map ? body['data']['token'] : null);

      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(ApiConfig.tokenKey, token.toString());
      }
      return body;
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// best effort: لازم تتنادى قبل مسح الـ token (الـ interceptor بيقراه من SharedPreferences)
  Future<void> logoutRemote({
    String? fcmToken,
    required String deviceId,
  }) async {
    final opts = Options(
      sendTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    );
    if (fcmToken != null) {
      try {
        await _dio.delete(
          Endpoints.fcmToken,
          data: {'fcmToken': fcmToken},
          options: opts,
        );
      } catch (e) {
        print('delete fcm failed: $e');
      }
    }
    try {
      await _dio.delete(
        Endpoints.logout,
        data: {'deviceId': deviceId},
        options: opts,
      );
    } catch (e) {
      print('logout failed: $e');
    }
  }

  /// تحديث الـ FCM token للجلسة الحالية (بعد refresh أو بعد فتح التطبيق)
  Future<void> updateFcmToken({
    required String fcmToken,
    String? deviceId,
  }) async {
    try {
      await _dio.put(
        Endpoints.fcmToken,
        data: {
          'fcmToken': fcmToken,
          if (deviceId != null) 'deviceId': deviceId,
        },
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }
  // ---------------- Users ----------------

  Future<Map<String, dynamic>> addUser({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String role, // Admin | Manager | Team Leader | Sales | Marketer
    List<String>? channels, // للـ Marketer
  }) async {
    try {
      final res = await _dio.post(
        Endpoints.signup,
        data: {
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'phone': phone,
          'password': password,
          'role': role,
          'channels': ?channels,
        },
      );
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<Map<String, dynamic>> getAllUsers() async {
    try {
      final res = await _dio.get(Endpoints.allUsers);
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<Map<String, dynamic>> getUser(String id) async {
    try {
      final res = await _dio.get(Endpoints.user(id));
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<Map<String, dynamic>> updateUser(
    String id,
    Map<String, dynamic> fields,
  ) async {
    try {
      final res = await _dio.put(Endpoints.user(id), data: fields);
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// الأدمن بيغير باسورد يوزر تاني
  Future<void> adminChangePassword(String userId, String newPassword) async {
    try {
      await _dio.put(
        Endpoints.changePassword(userId),
        data: {'newPassword': newPassword},
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// اليوزر بيغير باسورده هو
  Future<void> changeMyPassword({
    required String myId,
    required String currentPassword,
    required String newPassword,
    required String deviceId,
  }) async {
    try {
      await _dio.put(
        Endpoints.changePassword(myId),
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
          'deviceId': deviceId,
        },
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<void> bulkSetActive(List<String> ids, {required bool active}) async {
    try {
      await _dio.put(
        active ? Endpoints.bulkActivateUsers : Endpoints.bulkDeactivateUsers,
        data: {'ids': ids},
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  // ---------------- Sessions ----------------

  Future<Map<String, dynamic>> mySessions({
    String? platform,
    String? keyword,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final res = await _dio.get(
        Endpoints.mySessions,
        queryParameters: {
          'platform': ?platform,
          'keyword': ?keyword,
          'page': page,
          'limit': limit,
          'sort': '-lastLoginAt',
        },
      );
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      throw DioClient.parse(e);
    }
  }
}
