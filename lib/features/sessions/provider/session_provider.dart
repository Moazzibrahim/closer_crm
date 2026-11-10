import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/features/crud/data/users_model.dart';
// ⚠️ عدّل المسار حسب مكان UserModel عندك
import 'package:shared_preferences/shared_preferences.dart';

// ═════════════════════════════════════════════
//  Models
// ═════════════════════════════════════════════
String? _str(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty || s == 'null') ? null : s;
}

class SessionUser {
  final String? id, firstName, lastName, email, role;
  const SessionUser({
    this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.role,
  });

  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();
  String get initial =>
      (firstName?.isNotEmpty ?? false) ? firstName![0].toUpperCase() : '?';

  factory SessionUser.fromJson(Map<String, dynamic> j) => SessionUser(
    id: _str(j['_id'] ?? j['id']),
    firstName: _str(j['firstName']),
    lastName: _str(j['lastName']),
    email: _str(j['email']),
    role: _str(j['role']),
  );
}

class SessionLocation {
  final String? country, city, region;
  const SessionLocation({this.country, this.city, this.region});

  /// "Sharjah, United Arab Emirates" أو null لو مفيش بيانات
  String? get label {
    final parts = [city, country].whereType<String>().toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  factory SessionLocation.fromJson(Map<String, dynamic> j) => SessionLocation(
    country: _str(j['country']),
    city: _str(j['city']),
    region: _str(j['region']),
  );
}

class SessionModel {
  final String id;
  final SessionUser user;
  final String? deviceName, ip, platform;
  final SessionLocation location;
  final DateTime? lastLoginAt;

  const SessionModel({
    required this.id,
    required this.user,
    required this.location,
    this.deviceName,
    this.ip,
    this.platform,
    this.lastLoginAt,
  });

  /// الـ deviceName أحياناً User-Agent طويل، نطلع منه اسم OS مفهوم
  String get deviceLabel {
    final d = deviceName ?? '';
    final l = d.toLowerCase();
    if (l.contains('iphone')) return 'iPhone';
    if (l.contains('ipad')) return 'iPad';
    if (l.contains('android')) return 'Android';
    if (l.contains('windows')) return 'Windows';
    if (l.contains('macintosh') || l.contains('mac os')) return 'Mac';
    if (l.contains('linux')) return 'Linux';
    return d.isEmpty ? 'Unknown device' : d;
  }

  factory SessionModel.fromJson(Map<String, dynamic> j) {
    final u = j['user'];
    final loc = j['location'];
    return SessionModel(
      id: _str(j['_id'] ?? j['id']) ?? '',
      user: u is Map
          ? SessionUser.fromJson(Map<String, dynamic>.from(u))
          : const SessionUser(),
      location: loc is Map
          ? SessionLocation.fromJson(Map<String, dynamic>.from(loc))
          : const SessionLocation(),
      deviceName: _str(j['deviceName']),
      ip: _str(j['ip']),
      platform: _str(j['platform']),
      lastLoginAt: DateTime.tryParse(
        j['lastLoginAt']?.toString() ?? '',
      )?.toLocal(),
    );
  }
}

class SessionPage {
  final List<SessionModel> items;
  final int currentPage, numberOfPages, totalItems;
  const SessionPage({
    required this.items,
    required this.currentPage,
    required this.numberOfPages,
    required this.totalItems,
  });
  bool get hasNext => currentPage < numberOfPages;
}

// ═════════════════════════════════════════════
//  Filters
// ═════════════════════════════════════════════
const _unset = Object(); // عشان copyWith يفرّق بين "ما اتغيرش" و "امسحه (null)"

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class SessionFilters {
  static const defaultSort = '-lastLoginAt';

  final String? keyword, userId, platform, ip;
  final DateTime? createdFrom, createdTo, lastLoginFrom;
  final String sort;

  const SessionFilters({
    this.keyword,
    this.userId,
    this.platform,
    this.ip,
    this.createdFrom,
    this.createdTo,
    this.lastLoginFrom,
    this.sort = defaultSort,
  });

  SessionFilters copyWith({
    Object? keyword = _unset,
    Object? userId = _unset,
    Object? platform = _unset,
    Object? ip = _unset,
    Object? createdFrom = _unset,
    Object? createdTo = _unset,
    Object? lastLoginFrom = _unset,
    String? sort,
  }) => SessionFilters(
    keyword: identical(keyword, _unset) ? this.keyword : keyword as String?,
    userId: identical(userId, _unset) ? this.userId : userId as String?,
    platform: identical(platform, _unset) ? this.platform : platform as String?,
    ip: identical(ip, _unset) ? this.ip : ip as String?,
    createdFrom: identical(createdFrom, _unset)
        ? this.createdFrom
        : createdFrom as DateTime?,
    createdTo: identical(createdTo, _unset)
        ? this.createdTo
        : createdTo as DateTime?,
    lastLoginFrom: identical(lastLoginFrom, _unset)
        ? this.lastLoginFrom
        : lastLoginFrom as DateTime?,
    sort: sort ?? this.sort,
  );

  /// عدد الفلاتر المفعّلة (للـ badge) — الـ keyword خارجها لأنه في خانة البحث
  int get activeCount =>
      (userId != null ? 1 : 0) +
      (platform != null ? 1 : 0) +
      (ip != null ? 1 : 0) +
      (createdFrom != null || createdTo != null ? 1 : 0) +
      (lastLoginFrom != null ? 1 : 0) +
      (sort != defaultSort ? 1 : 0);

  /// الـ query params زي الـ Postman بالظبط
  Map<String, dynamic> toQuery(int page, int limit) => {
    'page': page,
    'limit': limit,
    'sort': sort,
    'fields': 'user,deviceName,platform,ip,location,lastLoginAt',
    if (keyword != null) 'keyword': keyword,
    if (userId != null) 'user': userId,
    if (platform != null) 'platform': platform,
    if (ip != null) 'ip': ip,
    if (createdFrom != null) 'createdFrom': _ymd(createdFrom!),
    if (createdTo != null) 'createdTo': _ymd(createdTo!),
    if (lastLoginFrom != null) 'lastLoginAt[gte]': _ymd(lastLoginFrom!),
  };
}

// ═════════════════════════════════════════════
//  Service
//  لو عندك Dio client جاهز بيحط الـ token، مرّره في الـ constructor
// ═════════════════════════════════════════════
class SessionsService {
  final Dio? _client;
  SessionsService([this._client]);

  Future<Dio> _dio() async {
    if (_client != null) return _client;
    final token = (await SharedPreferences.getInstance()).getString(
      ApiConfig.tokenKey,
    );
    return Dio(
      BaseOptions(
        baseUrl: ApiConfig.api,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      ),
    );
  }

  Future<SessionPage> fetch(
    SessionFilters f,
    int page, {
    int limit = 20,
  }) async {
    final res = await (await _dio()).get(
      Endpoints.allSessions,
      queryParameters: f.toQuery(page, limit),
    );
    final body = res.data as Map;
    final pg = (body['paginationResult'] as Map?) ?? const {};
    final list = (body['data'] as List?) ?? const [];
    return SessionPage(
      items: list
          .whereType<Map>()
          .map((e) => SessionModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      currentPage: (pg['currentPage'] as num?)?.toInt() ?? page,
      numberOfPages: (pg['NumberOfPages'] as num?)?.toInt() ?? 1,
      totalItems: (pg['totalItems'] as num?)?.toInt() ?? list.length,
    );
  }

  /// بيجيب الـ users للـ dropdown بتاع الفلتر (GET /auth/All)
  /// بيتعامل مع data كـ List أو Map فيها users
  Future<List<UserModel>> fetchUsers() async {
    final res = await (await _dio()).get(
      Endpoints.allUsers,
      queryParameters: {'limit': 200},
    );
    dynamic d = res.data is Map ? (res.data as Map)['data'] : res.data;
    if (d is Map) d = d['users'] ?? d['data'] ?? const [];
    return (d as List)
        .whereType<Map>()
        .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

// ═════════════════════════════════════════════
//  Provider
// ═════════════════════════════════════════════
class SessionsProvider extends ChangeNotifier {
  final SessionsService _service;
  SessionsProvider([SessionsService? s]) : _service = s ?? SessionsService();

  final List<SessionModel> items = [];
  List<UserModel> users = [];
  SessionFilters filters = const SessionFilters();

  bool loading = false, loadingMore = false;
  String? error;
  int _page = 1, total = 0;
  bool hasNext = false;
  int _req = 0; // رقم الريكويست: بنتجاهل أي رد قديم وصل متأخر

  Future<void> init() async {
    loadUsers(); // من غير await، مش لازم نعطل الليست
    await refresh();
  }

  Future<void> loadUsers() async {
    try {
      users = await _service.fetchUsers();
      notifyListeners();
    } catch (_) {
      /* الفلتر هيشتغل من غير أسماء */
    }
  }

  String userName(String? id) {
    for (final u in users) {
      if (u.id == id) {
        return u.fullName.isEmpty ? (u.email ?? 'User') : u.fullName;
      }
    }
    return 'User';
  }

  Future<void> refresh() async {
    final my = ++_req;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final p = await _service.fetch(filters, 1);
      if (my != _req) return;
      items
        ..clear()
        ..addAll(p.items);
      _page = p.currentPage;
      total = p.totalItems;
      hasNext = p.hasNext;
    } on DioException catch (e) {
      if (my != _req) return;
      final data = e.response?.data;
      error = data is Map && data['message'] != null
          ? data['message'].toString()
          : (e.message ?? 'Network error');
    } catch (e) {
      if (my != _req) return;
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasNext) return;
    final my = _req;
    loadingMore = true;
    notifyListeners();
    try {
      final p = await _service.fetch(filters, _page + 1);
      if (my != _req) return;
      items.addAll(p.items);
      _page = p.currentPage;
      hasNext = p.hasNext;
    } catch (_) {
      /* نسيب الزرار يحاول تاني بالسكرول */
    }
    loadingMore = false;
    notifyListeners();
  }

  Future<void> apply(SessionFilters f) {
    filters = f;
    return refresh();
  }
}
