// lib/features/marketer/provider/marketing_dashboard_provider.dart
// Provider (ChangeNotifier) للداشبورد: فلتر التاريخ + فلتر الـ channel.
// ملاحظة: بيستخدم package:http + التوكن من SharedPreferences.
// لو عندك ApiClient/CrudService جاهز، بدّل جوه _fetch() بس.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/features/marketer/data/marketer_dashboard_model.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      data = await _fetch();
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(ApiConfig.tokenKey);

    final qp = <String, String>{
      'tz': _tz,
      if (range != null) 'from': _iso(range!.start),
      if (range != null) 'to': _iso(range!.end, endOfDay: true),
      if (channelId != null) 'channel': channelId!,
    };
    // replace(queryParameters) بيعمل encode للـ + في الـ offset تلقائي
    final uri = Uri.parse(
      '${ApiConfig.api}${Endpoints.dashboardMarketing}',
    ).replace(queryParameters: qp);

    final res = await http
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        )
        .timeout(ApiConfig.receiveTimeout);

    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && body['data'] != null) {
      return MarketingData.fromJson(body['data'] as Map<String, dynamic>);
    }
    throw Exception(
      body is Map ? (body['message'] ?? 'Failed to load') : 'Failed to load',
    );
  }
}
