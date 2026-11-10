// lib/features/sales/provider/sales_dashboard_provider.dart
// Service (Dio) + Provider للداشبورد بتاع السيلز.
// مفيش فلتر سيلز: الـ salesId ثابت = اليوزر الحالي.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/utils/dio_client.dart';
import 'package:flutter_application_1/features/sales/model/sales_dashboard_model.dart';

// ─────────────────────────────────────────────
//  Service
// ─────────────────────────────────────────────
class SalesDashboardService {
  final Dio _dio = DioClient.instance.dio;

  Future<Map<String, dynamic>> _get(String path, Map<String, dynamic> q) async {
    try {
      final res = await _dio.get(path, queryParameters: q);
      final body = Map<String, dynamic>.from(res.data as Map);
      return Map<String, dynamic>.from(body['data'] as Map);
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// range = null -> All time (من غير createdFrom/createdTo)
  Future<StagesData> stages(String salesId, DateTimeRange? range) async {
    final j = await _get(Endpoints.dashboardStages, {
      'scope': 'sales',
      'sales': salesId,
      if (range != null) 'createdFrom': _ymd(range.start),
      if (range != null) 'createdTo': _ymd(range.end),
    });
    return StagesData.fromJson(j);
  }

  Future<FollowUpsData> followUps(String salesId) async {
    // بداية النهارده بتوقيت دبي (UTC+4) محوّلة لـ UTC
    final dubai = DateTime.now().toUtc().add(const Duration(hours: 4));
    final todayStart = DateTime.utc(
      dubai.year,
      dubai.month,
      dubai.day,
    ).subtract(const Duration(hours: 4));
    final j = await _get(Endpoints.dashboardFollowUps, {
      'scope': 'sales',
      'sales': salesId,
      'todayStart': todayStart.toIso8601String(),
    });
    return FollowUpsData.fromJson(j);
  }

  Future<DealsData> deals(
    String salesId, {
    required String view, // month | quarter | year
    required int year,
    required int quarter,
    required int month,
  }) async {
    final j = await _get(Endpoints.dashboardDeals, {
      'view': view, // ⚠️ لو الباك مش بيقراه شيل السطر ده
      'year': year,
      'quarter': quarter,
      'month': month,
      'sales': salesId,
      'scope': 'sales',
      'tz': 'Asia/Dubai',
    });
    return DealsData.fromJson(j);
  }
}

// ─────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────
class SalesDashboardProvider extends ChangeNotifier {
  final String salesId; // اليوزر الحالي
  final _service = SalesDashboardService();

  SalesDashboardProvider(this.salesId) {
    final now = DateTime.now();
    // الافتراضي: الشهر الحالي
    range = null;
    dealsYear = now.year;
    dealsMonth = now.month;
    dealsQuarter = (now.month - 1) ~/ 3 + 1;
  }

  // ── Stages ──
  DateTimeRange? range; // null = All time
  StagesData? stages;
  bool stagesLoading = false;
  String? stagesError;

  // ── Follow-ups ──
  FollowUpsData? followUps;
  bool followUpsLoading = false;
  String? followUpsError;

  // ── Deals ──
  DealsData? deals;
  bool dealsLoading = false;
  String? dealsError;
  String dealsView = 'month';
  late int dealsYear, dealsQuarter, dealsMonth;

  String _err(Object e) => e is ApiException ? e.message : '$e';

  /// تحميل كل حاجة بالتوازي (للـ pull-to-refresh)
  Future<void> load() =>
      Future.wait([loadStages(), loadFollowUps(), loadDeals()]);

  Future<void> loadStages() async {
    stagesLoading = true;
    stagesError = null;
    notifyListeners();
    try {
      stages = await _service.stages(salesId, range);
    } catch (e) {
      stagesError = _err(e);
    }
    stagesLoading = false;
    notifyListeners();
  }

  Future<void> loadFollowUps() async {
    followUpsLoading = true;
    followUpsError = null;
    notifyListeners();
    try {
      followUps = await _service.followUps(salesId);
    } catch (e) {
      followUpsError = _err(e);
    }
    followUpsLoading = false;
    notifyListeners();
  }

  Future<void> loadDeals() async {
    dealsLoading = true;
    dealsError = null;
    notifyListeners();
    try {
      deals = await _service.deals(
        salesId,
        view: dealsView,
        year: dealsYear,
        quarter: dealsQuarter,
        month: dealsMonth,
      );
    } catch (e) {
      dealsError = _err(e);
    }
    dealsLoading = false;
    notifyListeners();
  }

  // ── فلتر التاريخ (stages) ──
  void setRange(DateTimeRange r) {
    range = r;
    loadStages();
  }

  void clearRange() {
    range = null; // All time
    loadStages();
  }

  // ── فلاتر الـ deals ──
  void setView(String v) {
    dealsView = v;
    loadDeals();
  }

  void setYear(int y) {
    dealsYear = y;
    loadDeals();
  }

  void setQuarter(int q) {
    dealsQuarter = q;
    loadDeals();
  }

  void setMonth(int m) {
    dealsMonth = m;
    loadDeals();
  }
}
