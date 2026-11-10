import 'package:dio/dio.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/utils/dio_client.dart';
import 'package:flutter_application_1/features/auth/data/models/my_sessions_model.dart';

class SessionsFilter {
  final Set<String> platforms; // android / ios / web / windows
  final DateTime? lastLoginFrom; // lastLoginAt[gte]
  final DateTime? lastLoginTo; // lastLoginAt[lte]
  final String keyword;

  const SessionsFilter({
    this.platforms = const {},
    this.lastLoginFrom,
    this.lastLoginTo,
    this.keyword = '',
  });

  bool get isActive =>
      platforms.isNotEmpty ||
      lastLoginFrom != null ||
      lastLoginTo != null ||
      keyword.trim().isNotEmpty;

  SessionsFilter copyWith({
    Set<String>? platforms,
    DateTime? lastLoginFrom,
    DateTime? lastLoginTo,
    String? keyword,
    bool clearFrom = false,
    bool clearTo = false,
  }) => SessionsFilter(
    platforms: platforms ?? this.platforms,
    lastLoginFrom: clearFrom ? null : (lastLoginFrom ?? this.lastLoginFrom),
    lastLoginTo: clearTo ? null : (lastLoginTo ?? this.lastLoginTo),
    keyword: keyword ?? this.keyword,
  );
}

class SessionsService {
  final Dio _dio = DioClient.instance.dio;

  static String _d(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// أجهزة اليوزر الحالي
  Future<DeviceSessionsPage> getMySessions({
    int page = 1,
    int limit = 10,
    SessionsFilter filter = const SessionsFilter(),
  }) => _fetch(Endpoints.mySessions, page, limit, filter);

  /// أجهزة أي يوزر (للأدمن بس)
  Future<DeviceSessionsPage> getUserSessions(
    String userId, {
    int page = 1,
    int limit = 10,
    SessionsFilter filter = const SessionsFilter(),
  }) => _fetch(Endpoints.userSessions(userId), page, limit, filter);

  Future<DeviceSessionsPage> _fetch(
    String path,
    int page,
    int limit,
    SessionsFilter filter,
  ) async {
    try {
      final res = await _dio.get(
        path,
        queryParameters: {
          'page': page,
          'limit': limit,
          'sort': '-lastLoginAt',
          'fields':
              'deviceName,userAgent,platform,ip,location,lastLoginAt,user',
          if (filter.platforms.isNotEmpty)
            'platform': filter.platforms.toList(),
          if (filter.lastLoginFrom != null)
            'lastLoginAt[gte]': _d(filter.lastLoginFrom!),
          if (filter.lastLoginTo != null)
            'lastLoginAt[lte]': _d(filter.lastLoginTo!),
          if (filter.keyword.trim().isNotEmpty)
            'keyword': filter.keyword.trim(),
        },
      );
      return DeviceSessionsPage.fromJson(
        Map<String, dynamic>.from(res.data as Map),
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }
}
