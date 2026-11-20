// lib/features/marketer/provider/marketing_dashboard_provider.dart
// Provider (ChangeNotifier) للداشبورد: فلتر التاريخ + فلتر الـ channel.
// بيستخدم DioClient (التوكن والـ baseUrl بيتضافوا تلقائي من الـ interceptor).

// ignore_for_file: use_null_aware_elements

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/utils/dio_client.dart';
import 'package:flutter_application_1/features/marketer/data/marketer_dashboard_model.dart';

const _tz = 'Asia/Dubai';

/// ISO بـ offset الجهاز (مثال 2026-10-01T00:00:00+04:00)
String _iso(DateTime d, {bool endOfDay = false}) {
  final x = endOfDay
      ? DateTime(d.year, d.month, d.day, 23, 59, 59)
      : DateTime(d.year, d.month, d.day);
  String two(int n) => n.toString().padLeft(2, '0');
  final off = x.timeZoneOffset;
  final sign = off.isNegative ? '-' : '+';
  final oh = two(off.inHours.abs());
  final om = two(off.inMinutes.abs() % 60);
  return '${x.year}-${two(x.month)}-${two(x.day)}'
      'T${two(x.hour)}:${two(x.minute)}:${two(x.second)}$sign$oh:$om';
}

class MarketingDashboardProvider extends ChangeNotifier {
  DateTimeRange? range; // null = الافتراضي بتاع الباك (آخر 30 يوم)
  String? channelId; // null = كل الـ channels

  MarketingData? data;
  bool loading = false;
  String? error;

  // بنحتفظ بـ token للطلب الحالي عشان نتجاهل الردود القديمة (race condition)
  int _requestId = 0;

  Future<void> load() async {
    final myId = ++_requestId;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _fetch();
      if (myId != _requestId) return; // اتبعت طلب أحدث، تجاهل ده
      data = result;
    } on ApiException catch (e) {
      if (myId != _requestId) return;
      error = e.message;
    } catch (e) {
      if (myId != _requestId) return;
      error = e.toString();
    } finally {
      if (myId == _requestId) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void setRange(DateTimeRange r) {
    range = r;
    load();
  }

  void clearRange() {
    range = null;
    load();
  }

  void setChannel(String? id) {
    if (id == channelId) return;
    channelId = id;
    load();
  }

  Future<MarketingData> _fetch() async {
    final qp = <String, dynamic>{
      'tz': _tz,
      if (range != null) 'from': _iso(range!.start),
      if (range != null) 'to': _iso(range!.end, endOfDay: true),
      if (channelId != null) 'channel': channelId!,
    };

    try {
      // Dio بيعمل encode للـ + في الـ offset تلقائي
      final res = await DioClient.instance.dio.get(
        Endpoints.dashboardMarketing,
        queryParameters: qp,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      final body = res.data;
      if (body is Map && body['data'] != null) {
        return MarketingData.fromJson(body['data'] as Map<String, dynamic>);
      }
      throw ApiException(
        body is Map
            ? (body['message'] ?? 'Failed to load').toString()
            : 'Failed to load',
        statusCode: res.statusCode,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw DioClient.parse(e);
    }
  }
}
