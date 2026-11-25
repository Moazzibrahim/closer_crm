// Resolves a company code via the Hub, then saves and applies the server URL to ApiConfig
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/utils/dio_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Company {
  final String slug, name, apiUrl;
  const Company(this.slug, this.name, this.apiUrl);
}

/// Error with a message that is ready to show to the user
class CompanyException implements Exception {
  final String message;
  const CompanyException(this.message);
  @override
  String toString() => message;
}

class CompanyStore {
  static const _hub = 'https://closer-hub.onrender.com/api/resolve';
  static const _kSlug = 'company_slug';
  static const _kName = 'company_name';
  static const _kApi = 'company_api_url';

  static Company? current;

  // Separate Dio (no token interceptors).
  // The Hub is on Render and can take up to a minute to wake up, so timeout is 70s.
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 70),
      receiveTimeout: const Duration(seconds: 70),
    ),
  );

  /// Sets the baseUrl for the whole app
  static void _apply(Company c) {
    current = c;
    ApiConfig.baseUrl = c.apiUrl;
    // If DioClient fixes the baseUrl once, update it here
    try {
      DioClient.instance.dio.options.baseUrl = ApiConfig.api;
    } catch (_) {}
  }

  /// Returns the saved company (and applies it), or null on first launch
  static Future<Company?> restore() async {
    final p = await SharedPreferences.getInstance();
    final slug = p.getString(_kSlug), api = p.getString(_kApi);
    if (slug == null || api == null || api.isEmpty) return null;
    final c = Company(slug, p.getString(_kName) ?? slug, api);
    _apply(c);
    return c;
  }

  /// Asks the Hub for the company by code. Throws CompanyException with a display-ready message
  static Future<Company> resolve(String code) async {
    final slug = code.trim().toLowerCase(); // trim + lowercase
    if (slug.isEmpty) throw const CompanyException('Enter the company code');
    debugPrint('hub slug sent: "$slug"');

    try {
      final res = await _dio.get(_hub, queryParameters: {'slug': slug});
      debugPrint('hub slug sent: "$slug"');
      // 👈 اطبع الرد الخام عشان نشوف شكله
      debugPrint('hub status: ${res.statusCode}');
      debugPrint('hub body: ${res.data}');

      final data = (res.data as Map)['data'] as Map;
      final apiUrl = '${data['apiUrl']}'.replaceAll(RegExp(r'/+$'), '');
      if (apiUrl.isEmpty || apiUrl == 'null') {
        throw const CompanyException('Unexpected response from the server');
      }
      return Company(
        '${data['slug'] ?? slug}',
        '${data['name'] ?? slug}',
        apiUrl,
      );
    } on DioException catch (e) {
      // 👈 نوع الخطأ + الـ status + الرد + الرسالة الأصلية
      debugPrint('hub DioException type: ${e.type}');
      debugPrint('hub status: ${e.response?.statusCode}');
      debugPrint('hub response: ${e.response?.data}');
      debugPrint('hub message: ${e.message}');
      debugPrint('hub error: ${e.error}');

      if (e.response?.statusCode == 404) {
        throw const CompanyException('Company not found, check the code');
      }
      throw const CompanyException("Can't reach the server, please try again");
    } on CompanyException {
      rethrow;
    } catch (e, st) {
      // 👈 أي خطأ تاني (مثلاً الـ parsing)
      debugPrint('hub unexpected error: $e\n$st');
      throw const CompanyException("Can't reach the server, please try again");
    }
  }

  /// Saves and applies the company (call after a successful resolve)
  static Future<void> save(Company c) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSlug, c.slug);
    await p.setString(_kName, c.name);
    await p.setString(_kApi, c.apiUrl);
    _apply(c);
  }

  /// Re-checks with the Hub in the background; if the link changed, saves it for next launch
  /// (does not change the current baseUrl during the session)
  static Future<void> refreshInBackground() async {
    final c = current;
    if (c == null) return;
    try {
      final fresh = await resolve(c.slug);
      if (fresh.apiUrl != c.apiUrl || fresh.name != c.name) {
        final p = await SharedPreferences.getInstance();
        await p.setString(_kName, fresh.name);
        await p.setString(_kApi, fresh.apiUrl);
      }
    } catch (e) {
      debugPrint('company refresh skipped: $e'); // not important if it fails
    }
  }

  /// "Change company": clears the company and the token
  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kSlug);
    await p.remove(_kName);
    await p.remove(_kApi);
    await p.remove(ApiConfig.tokenKey);
    current = null;
    ApiConfig.baseUrl = ApiConfig.defaultBaseUrl;
  }
}
