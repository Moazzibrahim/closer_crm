// dio_client.dart
// A single Dio instance for the whole project: automatically adds the Bearer token,
// and normalizes errors into ApiException so Providers can handle them easily.
import 'package:dio/dio.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class DioClient {
  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // The baseUrl is read on every request (supports changing the domain)
          options.baseUrl = ApiConfig.api;

          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString(ApiConfig.tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) {
          // 401 = token expired; you could log the user out here (e.g. via a stream/callback)
          handler.next(e);
        },
      ),
    );
  }

  static final DioClient instance = DioClient._internal();
  late final Dio dio;

  /// Converts a DioException into a readable message from the backend response (message/error)
  static ApiException parse(Object e) {
    if (e is DioException) {
      print(
        'FAILED: ${e.requestOptions.method} ${e.requestOptions.path} → ${e.response?.statusCode}',
      );
      final data = e.response?.data;
      String? msg;
      if (data is Map) {
        msg = (data['message'] ?? data['error'])?.toString();
      }
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          msg ??= 'Connection timed out, please try again';
          break;
        case DioExceptionType.connectionError:
          msg ??= 'No internet connection';
          break;
        default:
          msg ??= e.message ?? 'An unexpected error occurred';
      }
      return ApiException(msg, statusCode: e.response?.statusCode);
    }
    return ApiException(e.toString());
  }
}
