// ignore_for_file: unnecessary_null_comparison

import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/features/auth/data/models/activity_log_model.dart';
import 'package:flutter_application_1/features/auth/providers/activity_log_service.dart';

class ActivityProvider extends ChangeNotifier {
  final _service = ActivityService();

  // بيتحدد من AuthProvider (role == 'Admin')
  bool isAdmin = false;
  // ID اليوزر الحالي: فلتر أمان إضافي على الـ client
  String myId = '';

  final List<ActivityLog> items = [];
  bool loading = false;
  bool hasMore = true;
  String? error;
  int _page = 1;

  // الفلاتر
  String userName = '';
  List<String> actions = [];
  List<String> modules = [];
  String? from, to;

  Future<void> refresh() async {
    _page = 1;
    hasMore = true;
    items.clear();
    await loadMore();
  }

  Future<void> loadMore() async {
    if (loading || !hasMore) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _service.fetch(
        isAdmin: isAdmin,
        page: _page,
        userName: userName,
        actions: actions,
        modules: modules,
        createdFrom: from,
        createdTo: to,
      );

      // اليوزر العادي: فلتر أمان إضافي على الـ client،
      // بس لو الـ id معروف. لو null بنسيب اعتمادنا على /profile/activity
      final list = (isAdmin || myId == null)
          ? res.items
          : res.items.where((l) => l.userId == myId).toList();

      items.addAll(list);
      hasMore = res.hasMore;
      _page++;
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  void applyFilters({
    String? name,
    List<String>? acts,
    List<String>? mods,
    String? f,
    String? t,
  }) {
    userName = name ?? userName;
    actions = acts ?? actions;
    modules = mods ?? modules;
    from = f;
    to = t;
    refresh();
  }
}
