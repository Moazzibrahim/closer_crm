// lib/features/admin/providers/dashboard_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/admin/data/admin_dashboard_model.dart';
import 'package:flutter_application_1/features/admin/data/deals_dashboard_model.dart';
import 'package:flutter_application_1/features/admin/providers/admin_dashboard_service.dart';

class DashboardProvider extends ChangeNotifier {
  final DashboardService _service;
  DashboardProvider({DashboardService? service})
    : _service = service ?? DashboardService();

  DashboardStages? _data;
  bool _loading = false;
  String? _error;
  DateTimeRange? _range; // null = all time
  SalesOpt? _sales; // null = all sales

  // Follow-ups (depends on the sales filter only, not the date range)
  DashboardFollowUps? _followUps;
  bool _followUpsLoading = false;
  String? _followUpsError;
  int _followUpsRequestId = 0;

  List<SalesOpt> _salesOptions = [];
  bool _salesLoading = false;
  String? _salesError;
  bool _salesLoaded = false;

  int _requestId = 0;

  DashboardStages? get data => _data;
  bool get isLoading => _loading;
  String? get error => _error;
  DateTimeRange? get range => _range;
  SalesOpt? get sales => _sales;

  DashboardFollowUps? get followUps => _followUps;
  bool get followUpsLoading => _followUpsLoading;
  String? get followUpsError => _followUpsError;

  List<SalesOpt> get salesOptions => _salesOptions;
  bool get salesLoading => _salesLoading;
  String? get salesError => _salesError;

  /// Reloads everything (used by initial load + pull-to-refresh).
  Future<void> load() => Future.wait([_loadStages(), loadFollowUps()]);

  /// Pull-to-refresh: clears every filter (sales + date range), then reloads all.
  Future<void> resetAndLoad() {
    _sales = null;
    _range = null;
    return load();
  }

  Future<void> _loadStages() async {
    final id = ++_requestId;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.getStages(
        salesId: _sales?.id,
        createdFrom: _range?.start,
        createdTo: _range?.end,
      );
      if (id != _requestId) return;
      _data = result;
    } catch (e) {
      if (id != _requestId) return;
      _error = e.toString();
    } finally {
      if (id == _requestId) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadFollowUps() async {
    final id = ++_followUpsRequestId;
    _followUpsLoading = true;
    _followUpsError = null;
    notifyListeners();

    try {
      final result = await _service.getFollowUps(salesId: _sales?.id);
      if (id != _followUpsRequestId) return;
      _followUps = result;
    } catch (e) {
      if (id != _followUpsRequestId) return;
      _followUpsError = e.toString();
    } finally {
      if (id == _followUpsRequestId) {
        _followUpsLoading = false;
        notifyListeners();
      }
    }
  }

  // ── Date range (stages only) ──
  Future<void> setRange(DateTimeRange range) {
    _range = range;
    return _loadStages();
  }

  Future<void> clearRange() {
    _range = null;
    return _loadStages();
  }

  // ── Sales filter (stages + follow-ups) ──
  Future<void> setSales(SalesOpt sales) {
    _sales = sales;
    return load();
  }

  Future<void> clearSales() {
    _sales = null;
    return load();
  }

  Future<void> ensureSalesLoaded() async {
    if (_salesLoaded || _salesLoading) return;
    _salesLoading = true;
    _salesError = null;
    notifyListeners();
    try {
      _salesOptions = await _service.getSalesUsers();
      _salesLoaded = true;
    } catch (e) {
      _salesError = e.toString();
    } finally {
      _salesLoading = false;
      notifyListeners();
    }
  }
}

class DealsProvider extends ChangeNotifier {
  final DashboardService _service;
  DealsProvider({DashboardService? service})
    : _service = service ?? DashboardService() {
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _quarter = (now.month - 1) ~/ 3 + 1;
  }

  String _view = 'month';
  late int _year, _month, _quarter;
  final Set<String> _salesIds = {};

  DealsDashboard? _data;
  bool _loading = false;
  String? _error;
  int _req = 0;

  String get view => _view;
  int get year => _year;
  int get month => _month;
  int get quarter => _quarter;
  Set<String> get salesIds => _salesIds;
  DealsDashboard? get data => _data;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> load() async {
    final id = ++_req;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final r = await _service.getDeals(
        view: _view,
        year: _year,
        quarter: _quarter,
        month: _month,
        salesIds: _salesIds.toList(),
      );
      if (id != _req) return;
      _data = r;
    } catch (e) {
      if (id != _req) return;
      _error = e.toString();
    } finally {
      if (id == _req) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> setView(String v) {
    _view = v;
    return load();
  }

  Future<void> setYear(int y) {
    _year = y;
    return load();
  }

  Future<void> setQuarter(int q) {
    _quarter = q;
    return load();
  }

  Future<void> setMonth(int m) {
    _month = m;
    _quarter = (m - 1) ~/ 3 + 1; // نحافظ على التناسق بين الشهر والربع
    return load();
  }

  Future<void> toggleSales(String id) {
    _salesIds.contains(id) ? _salesIds.remove(id) : _salesIds.add(id);
    return load();
  }

  Future<void> clearSales() {
    _salesIds.clear();
    return load();
  }
}
