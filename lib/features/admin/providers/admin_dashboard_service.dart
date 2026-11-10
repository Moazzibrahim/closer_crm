// lib/features/admin/providers/admin_dashboard_service.dart
import 'package:dio/dio.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/utils/dio_client.dart';
import 'package:flutter_application_1/features/admin/data/admin_dashboard_model.dart';
import 'package:flutter_application_1/features/admin/data/deals_dashboard_model.dart';

class DashboardService {
  final Dio _dio = DioClient.instance.dio;

  /// GET /dashboard/stages
  ///  - بدون salesId:  ?scope=full
  ///  - مع salesId:    ?scope=sales&sales=<id>
  /// التواريخ اختيارية (createdFrom / createdTo بصيغة yyyy-MM-dd).
  Future<DashboardStages> getStages({
    String? salesId,
    DateTime? createdFrom,
    DateTime? createdTo,
  }) async {
    try {
      final res = await _dio.get(
        Endpoints.dashboardStages,
        queryParameters: {
          'scope': salesId == null ? 'full' : 'sales',
          'sales': ?salesId,
          if (createdFrom != null) 'createdFrom': ymd(createdFrom),
          if (createdTo != null) 'createdTo': ymd(createdTo),
        },
      );
      final body = Map<String, dynamic>.from(res.data as Map);
      // Response shape: { status: "success", data: {...} }
      return DashboardStages.fromJson(
        Map<String, dynamic>.from(body['data'] as Map),
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// GET /dashboard/follow-ups
  ///  - no salesId: ?scope=full&todayStart=...
  ///  - salesId:    ?scope=sales&sales=<id>&todayStart=...
  /// todayStart = start of the user's local day, sent as UTC ISO.
  Future<DashboardFollowUps> getFollowUps({String? salesId}) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toUtc();

      final res = await _dio.get(
        Endpoints.dashboardFollowUps,
        queryParameters: {
          'scope': salesId == null ? 'full' : 'sales',
          'sales': ?salesId,
          'todayStart': todayStart.toIso8601String(),
        },
      );
      final body = Map<String, dynamic>.from(res.data as Map);
      return DashboardFollowUps.fromJson(
        Map<String, dynamic>.from(body['data'] as Map),
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// اليوزرز اللي رولهم Sales بس (للفلتر).
  /// الفلترة بتتم عندنا لأن /auth/All مفيهوش فلتر رول معروف.
  Future<List<SalesOpt>> getSalesUsers() async {
    try {
      final res = await _dio.get(
        Endpoints.allUsers,
        queryParameters: {'limit': 1000},
      );
      final body = Map<String, dynamic>.from(res.data as Map);

      final list = (body['data'] as List? ?? [])
          .whereType<Map>()
          .where(
            (e) => _roleOf(e) == 'sales',
          ) // Sales بس (مش TeamLeader/Manager)
          .map((e) {
            final name =
                '${e['name'] ?? e['fullName'] ?? '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'}'
                    .trim();
            return SalesOpt('${e['_id'] ?? e['id']}', name);
          })
          .where((o) => o.name.isNotEmpty)
          .toList();

      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  // role ممكن يجي String أو Map ({name/slug/title}) — بنوحّده: "Team Leader" → "teamleader"
  String _roleOf(Map e) {
    final r = e['role'];
    final raw = r is Map
        ? (r['name'] ?? r['slug'] ?? r['title'] ?? '')
        : (r ?? '');
    return '$raw'.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
  }
  // import 'package:flutter_application_1/features/admin/data/deals_model.dart';

  /// GET /dashboard/deals?year=&quarter=&month=&sales=id1,id2&tz=
  Future<DealsDashboard> getDeals({
    required String view, // 'year' | 'quarter' | 'month'
    required int year,
    int? quarter,
    int? month,
    List<String> salesIds = const [],
  }) async {
    try {
      final res = await _dio.get(
        Endpoints.dashboardDeals,
        queryParameters: {
          'scope': salesIds.isEmpty ? 'full' : 'sales',
          'view': view,
          'year': year,
          if (view != 'year' && quarter != null) 'quarter': quarter,
          if (view == 'month' && month != null) 'month': month,
          if (salesIds.isNotEmpty) 'sales': salesIds.join(','),
          'tz': 'Asia/Dubai',
        },
      );
      final body = Map<String, dynamic>.from(res.data as Map);
      return DealsDashboard.fromJson(
        Map<String, dynamic>.from(body['data'] as Map),
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }
}
