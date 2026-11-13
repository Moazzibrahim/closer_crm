// reshuffle_service.dart
// كل نداءات /stage-reshuffle-rules. بيستخدم Dio مباشرة بنفس هيدرز الـ API:
// Authorization (Bearer) + x-device-id، مقروءين من SharedPreferences بنفس مفاتيح ApiConfig.
// ⚠️ لو عندك Dio client مشترك (interceptors جاهزة)، بدّل _dio() بيه وباقي الملف يفضل زي ما هو.
import 'package:dio/dio.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/features/reshuffle/data/reshuffle_rule_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// رسالة خطأ جاهزة للعرض (toString بيرجّع الرسالة بس)
class ReshuffleException implements Exception {
  final String message;
  ReshuffleException(this.message);
  @override
  String toString() => message;
}

class ReshuffleService {
  Dio _dio() {
    final d = Dio(
      BaseOptions(
        baseUrl: ApiConfig.api, // getter: بيتقري مع كل service جديدة
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        contentType: Headers.jsonContentType,
      ),
    );
    d.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) async {
          final p = await SharedPreferences.getInstance();
          final t = p.getString(ApiConfig.tokenKey);
          final dev = p.getString(ApiConfig.deviceIdKey);
          if (t != null && t.isNotEmpty) o.headers['Authorization'] = 'Bearer $t';
          if (dev != null && dev.isNotEmpty) o.headers['x-device-id'] = dev;
          h.next(o);
        },
      ),
    );
    return d;
  }

  Future<T> _run<T>(Future<T> Function(Dio d) call) async {
    try {
      return await call(_dio());
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map ? (data['message'] ?? data['error']) : null;
      throw ReshuffleException('${msg ?? e.message ?? 'Network error'}');
    }
  }

  // الـ API بيرجّع { status, data } فنفكّ الـ data لو موجودة
  dynamic _unwrap(Response r) {
    final b = r.data;
    return b is Map && b.containsKey('data') ? b['data'] : b;
  }

  RsRule _rule(Response r) =>
      RsRule.fromJson(Map<String, dynamic>.from(_unwrap(r) as Map));

  /// GET /stage-reshuffle-rules (مترتبة بالـ priority، من غير pagination)
  Future<List<RsRule>> list() => _run((d) async {
    final r = await d.get(Endpoints.reshuffleRules);
    return (_unwrap(r) as List? ?? const [])
        .whereType<Map>()
        .map((e) => RsRule.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  });

  /// GET /stage-reshuffle-rules/:id
  Future<RsRule> get(String id) =>
      _run((d) async => _rule(await d.get(Endpoints.reshuffleRule(id))));

  /// POST — بيتعمل دايمًا isActive = false
  Future<RsRule> create(RsRule rule) => _run(
    (d) async =>
        _rule(await d.post(Endpoints.reshuffleRules, data: rule.toJson())),
  );

  /// PATCH /:id
  Future<RsRule> update(String id, RsRule rule) => _run(
    (d) async =>
        _rule(await d.patch(Endpoints.reshuffleRule(id), data: rule.toJson())),
  );

  /// DELETE /:id (204)
  Future<void> delete(String id) =>
      _run((d) async => d.delete(Endpoints.reshuffleRule(id)));

  /// PATCH /:id/toggle — بيحدد isActive صراحةً (لو اتبعتش بيتعطّل)
  Future<RsRule> toggle(String id, bool active) => _run(
    (d) async => _rule(
      await d.patch(Endpoints.reshuffleToggle(id), data: {'isActive': active}),
    ),
  );
}
