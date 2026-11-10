// lib/features/notifications/presentation/providers/notification_provider.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/notifications/provider/notification_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/utils/dio_client.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service;
  NotificationProvider({NotificationService? service})
    : _service = service ?? NotificationService();

  bool sending = false;
  NotificationTestResult? result; // آخر نتيجة
  String? error; // رسالة عامة للمستخدم (التفاصيل في الكونسول)

  /// ابعت إشعار تجريبي
  Future<bool> sendTest() async {
    if (sending) return false;
    sending = true;
    error = null;
    notifyListeners();

    try {
      result = await _service.sendTest();
      // لو فيه أخطاء، اطبعها في الكونسول
      for (final e in result!.errors) {
        debugPrint('Push error: ${e.code} - ${e.message}');
      }
      return result!.sent > 0;
    } on NotificationException catch (e) {
      debugPrint('Notification test error [${e.statusCode}]: ${e.message}');
      error = 'Could not send the test notification. Please try again.';
      return false;
    } finally {
      sending = false;
      notifyListeners();
    }
  }
}

// lib/features/notifications/provider/notification_feed_service.dart

class BellNotification {
  final String id, eventId, type, title, body;
  final String? leadId, actorName, forName;
  final bool mine, canOpen, isNew;
  final int count;
  final DateTime createdAt;
  bool read;

  BellNotification({
    required this.id,
    required this.eventId,
    required this.type,
    required this.title,
    required this.body,
    required this.leadId,
    required this.actorName,
    required this.forName,
    required this.mine,
    required this.canOpen,
    required this.isNew,
    required this.count,
    required this.createdAt,
    required this.read,
  });

  factory BellNotification.fromJson(Map<String, dynamic> j) {
    final actor = j['actor'] is Map ? j['actor'] as Map : const {};
    return BellNotification(
      id: '${j['id'] ?? ''}',
      eventId: '${j['eventId'] ?? ''}',
      type: '${j['type'] ?? 'system'}',
      title: '${j['title'] ?? ''}',
      body: '${j['body'] ?? ''}',
      leadId: j['leadId'] as String?,
      actorName: actor['name'] as String?,
      forName: j['forName'] as String?,
      mine: j['mine'] == true,
      canOpen: j['canOpen'] != false,
      isNew: j['isNew'] == true,
      count: (j['count'] as num?)?.toInt() ?? 1,
      createdAt:
          DateTime.tryParse('${j['createdAt']}')?.toLocal() ?? DateTime.now(),
      read: j['read'] == true,
    );
  }
}

class NotificationPage {
  final List<BellNotification> items;
  final int mineUnread;
  final String scope;
  final bool hasMore;
  final String? nextBefore;
  const NotificationPage({
    required this.items,
    required this.mineUnread,
    required this.scope,
    required this.hasMore,
    required this.nextBefore,
  });
}

class NotificationAccess {
  final bool allowed;
  final String? leadId, reason;
  const NotificationAccess(this.allowed, this.leadId, this.reason);
}

class NotificationFeedService {
  final Dio _dio = DioClient.instance.dio;

  Map<String, dynamic> _data(Response r) {
    final m = Map<String, dynamic>.from(r.data as Map);
    return m['data'] is Map ? Map<String, dynamic>.from(m['data']) : m;
  }

  /// GET /notifications  (cursor: before = nextBefore)
  Future<NotificationPage> list({
    int limit = 15,
    String? before,
    bool unreadOnly = false,
  }) async {
    try {
      final d = _data(
        await _dio.get(
          Endpoints.notifications,
          queryParameters: {
            'limit': limit,
            'before': ?before,
            if (unreadOnly) 'unread': true,
          },
        ),
      );
      return NotificationPage(
        items: ((d['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => BellNotification.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        mineUnread: (d['mineUnread'] as num?)?.toInt() ?? 0,
        scope: '${d['scope'] ?? ''}',
        hasMore: d['hasMore'] == true,
        nextBefore: d['nextBefore'] as String?,
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// GET /notifications/unread-count → رقم الجرس (unread)
  Future<int> bellCount() async {
    try {
      final d = _data(await _dio.get(Endpoints.notifUnread));
      return (d['unread'] as num?)?.toInt() ?? 0;
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// POST /notifications/seen → بيصفّر رقم الجرس (مش بيعلّم مقروء)
  Future<void> markSeen() async {
    try {
      await _dio.post(Endpoints.notifSeen);
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// PATCH /notifications/:id/read → بيرجّع عدد الغير مقروء
  Future<int> markRead(String id) async {
    try {
      final d = _data(await _dio.patch(Endpoints.notifRead(id)));
      return (d['unread'] as num?)?.toInt() ?? 0;
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// PATCH /notifications/read-all
  Future<void> markAllRead() async {
    try {
      await _dio.patch(Endpoints.notifReadAll);
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// DELETE /notifications/:id → بيرجّع عدد الغير مقروء
  Future<int> delete(String id) async {
    try {
      final d = _data(await _dio.delete(Endpoints.notif(id)));
      return (d['unread'] as num?)?.toInt() ?? 0;
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// GET /notifications/:id/access → قبل ما نفتح الليد
  Future<NotificationAccess> access(String id) async {
    try {
      final d = _data(await _dio.get(Endpoints.notifAccess(id)));
      return NotificationAccess(
        d['allowed'] == true,
        d['leadId'] as String?,
        d['reason'] as String?,
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }
}

/// رقم الجرس (singleton): بيتحدّث لوحده كل 30 ثانية، ولما التطبيق يرجع من الخلفية
class NotificationBadge {
  static final ValueNotifier<int> count = ValueNotifier(0);
  static final _svc = NotificationFeedService();
  static final _observer = _LifecycleObserver();
  static Timer? _timer;
  static bool _started = false;

  /// ناديها مرة واحدة (آمنة لو اتنادت أكتر)
  static void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(_observer);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    refresh();
  }

  /// ناديها عند الـ logout
  static void stop() {
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(_observer);
    _started = false;
    count.value = 0;
  }

  static Future<void> refresh() async {
    try {
      count.value = await _svc.bellCount();
    } catch (e) {
      debugPrint('Badge refresh failed: $e'); // كان بيتبلع بصمت
    }
  }
}

class _LifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) NotificationBadge.refresh();
  }
}

class NotificationsFeedProvider extends ChangeNotifier {
  final NotificationFeedService _svc;
  NotificationsFeedProvider({NotificationFeedService? service})
    : _svc = service ?? NotificationFeedService();

  final List<BellNotification> items = [];
  bool loading = false, loadingMore = false, hasMore = false;
  bool unreadOnly = false;
  String? error, scope, _nextBefore;
  int mineUnread = 0;
  int _req = 0;

  Future<void> load() => _fetch(reset: true);

  Future<void> loadMore() {
    if (loading || loadingMore || !hasMore) return Future.value();
    return _fetch(reset: false);
  }

  Future<void> setUnreadOnly(bool v) {
    if (unreadOnly == v) return Future.value();
    unreadOnly = v;
    return load();
  }

  Future<void> _fetch({required bool reset}) async {
    final id = ++_req;
    if (reset) {
      loading = true;
      error = null;
    } else {
      loadingMore = true;
    }
    notifyListeners();

    try {
      final page = await _svc.list(
        before: reset ? null : _nextBefore,
        unreadOnly: unreadOnly,
      );
      if (id != _req) return;
      if (reset) items.clear();
      items.addAll(page.items);
      mineUnread = page.mineUnread;
      scope = page.scope;
      hasMore = page.hasMore;
      _nextBefore = page.nextBefore;
      error = null;
    } catch (e) {
      if (id != _req) return;
      error = e.toString();
    }
    loading = false;
    loadingMore = false;
    notifyListeners();
  }

  /// لما الشاشة تتفتح: صفّر رقم الجرس
  Future<void> markSeen() async {
    try {
      await _svc.markSeen();
      NotificationBadge.count.value = 0;
    } catch (_) {}
  }

  Future<void> markRead(BellNotification n) async {
    if (!n.mine || n.read) return;
    n.read = true;
    mineUnread = (mineUnread - 1).clamp(0, 1 << 30);
    notifyListeners();
    try {
      mineUnread = await _svc.markRead(n.id);
    } catch (_) {
      n.read = false;
      mineUnread++;
    }
    notifyListeners();
  }

  Future<void> markAllRead() async {
    final before = items.where((n) => n.mine && !n.read).toList();
    for (final n in before) {
      n.read = true;
    }
    final oldCount = mineUnread;
    mineUnread = 0;
    notifyListeners();
    try {
      await _svc.markAllRead();
      if (unreadOnly) await load();
    } catch (_) {
      for (final n in before) {
        n.read = false;
      }
      mineUnread = oldCount;
      notifyListeners();
    }
  }

  Future<void> remove(BellNotification n) async {
    final i = items.indexOf(n);
    if (i < 0) return;
    items.removeAt(i);
    notifyListeners();
    try {
      mineUnread = await _svc.delete(n.id);
    } catch (_) {
      items.insert(i, n);
    }
    notifyListeners();
  }

  /// قبل فتح الليد: null = مسموح، غير كده رسالة السبب
  Future<({bool ok, String? leadId, String? reason})> checkAccess(
    BellNotification n,
  ) async {
    try {
      final a = await _svc.access(n.id);
      return (ok: a.allowed, leadId: a.leadId ?? n.leadId, reason: a.reason);
    } catch (e) {
      return (ok: false, leadId: null, reason: e.toString());
    }
  }
}
