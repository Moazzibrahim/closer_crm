// messaging_provider.dart
// بيتعمل مرة واحدة في الـ MainShell (من غير marketer).
// بيحمّل صلاحيات الـ inbox + قايمة المحادثات + عدّاد الـ unread،
// وبيسمع على socket.io (wa:update / wa:revoke) عشان كله لحظي.
// يحتاج في pubspec:  socket_io_client: ^2.0.3+1   و  file_picker

// ignore_for_file: unused_element

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/constants/device_helper.dart';
import 'package:flutter_application_1/features/messaging/data/messaging_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'messaging_service.dart';

class MessagingProvider extends ChangeNotifier {
  final MessagingService service = MessagingService();

  InboxMe? me;
  String? error;
  bool loading = false, loadingMore = false, hasMore = true;
  List<WaConversation> conversations = [];
  List<SalesOption> salesOptions = [];
  // int totalUnread = 0;  👈 امسحها
  int unreadUnifonic = 0, unreadUnisent = 0;
  int get totalUnread => unreadUnifonic + unreadUnisent;
  // فلاتر القايمة
  String query = '';
  String? salesFilter;
  bool unreadOnly = false;
  bool archivedView = false;
  int _page = 1;
  static const _limit = 30;
  String? interestFilter;

  /// رسائل جديدة/متحدّثة جاية من الـ socket — الشات المفتوح بيسمع عليه
  final _msgCtrl = StreamController<WaMessage>.broadcast();
  Stream<WaMessage> get messageStream => _msgCtrl.stream;

  io.Socket? _socket;
  Timer? _unreadDebounce;
  bool _disposed = false;

  bool get ready => me != null;

  bool get isUnisent => service.prefix == 'unisent';
  String get _providerName => isUnisent ? 'unisent' : 'unifonic';

  /// يبدّل بين Unifonic (messaging) و Unisent. الـ InboxScreen هو اللي بيعمل load.
  void switchProvider(String prefix) {
    if (service.prefix == prefix) return;
    service.prefix = prefix;
    query = '';
    salesFilter = null;
    unreadOnly = false;
    archivedView = false;
    conversations = [];
    salesOptions = [];
    // totalUnread = 0;
    hasMore = true;
    error = null;
    _page = 1;
    notifyListeners();
    _loadSales();
  }

  // ─────────────── init ───────────────
  Future<void> init() async {
    try {
      me = await service.me();
      service.prefix = me!.isUnisent ? 'unisent' : 'messaging';
      error = null;
      notifyListeners();
      await Future.wait([load(), refreshUnread(), _loadSales()]);
      _connectSocket();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> _loadSales() async {
    if (me?.canFilter != true && me?.canAssign != true) return;
    try {
      salesOptions = await service.salesOptions();
      notifyListeners();
    } catch (_) {}
  }

  // ─────────────── list ───────────────
  /// القايمة بعد فلتر الـ interest (client-side)
  List<WaConversation> get visible => interestFilter == null
      ? conversations
      : conversations.where((c) => c.interest == interestFilter).toList();

  Future<void> load() async {
    if (me == null) return;
    loading = true;
    _page = 1;
    notifyListeners();
    try {
      final rows = await service.conversations(
        q: query,
        salesId: salesFilter,
        interest: interestFilter,
        unreadOnly: unreadOnly,
        archived: archivedView,
        page: 1,
        limit: _limit,
      );
      conversations = rows;
      hasMore = rows.length >= _limit;
      error = null;
      await _fillForInterest(); // 👈 كمّل تحميل لو الفلتر شغال والنتايج قليلة
      _sort();
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  /// لو الفلتر client-side والنتايج قليلة، نجيب كام صفحة زيادة (حد أقصى 5)
  Future<void> _fillForInterest() async {
    var guard = 0;
    while (interestFilter != null &&
        hasMore &&
        visible.length < 15 &&
        guard++ < 5) {
      final rows = await service.conversations(
        q: query,
        salesId: salesFilter,
        interest: interestFilter,
        unreadOnly: unreadOnly,
        archived: archivedView,
        page: ++_page,
        limit: _limit,
      );
      final ids = conversations.map((c) => c.id).toSet();
      conversations = [
        ...conversations,
        ...rows.where((r) => !ids.contains(r.id)),
      ];
      hasMore = rows.length >= _limit;
    }
  }

  Future<void> loadMore() async {
    if (loadingMore || loading || !hasMore) return;
    loadingMore = true;
    notifyListeners();
    try {
      final rows = await service.conversations(
        q: query,
        salesId: salesFilter,
        interest: interestFilter,
        unreadOnly: unreadOnly,
        archived: archivedView,
        page: ++_page,
        limit: _limit,
      );
      final ids = conversations.map((c) => c.id).toSet();
      conversations = [
        ...conversations,
        ...rows.where((r) => !ids.contains(r.id)),
      ];
      hasMore = rows.length >= _limit;
      _sort();
    } catch (_) {
      _page--;
    }
    loadingMore = false;
    notifyListeners();
  }

  void setFilters({
    String? q,
    String? sales,
    String? interest,
    bool? unread,
    bool? archived,
    bool clearSales = false,
    bool clearInterest = false, // 👈
  }) {
    if (q != null) query = q;
    if (clearSales) salesFilter = null;
    if (sales != null) salesFilter = sales;
    if (clearInterest) interestFilter = null;
    if (interest != null) interestFilter = interest;
    if (unread != null) unreadOnly = unread;
    if (archived != null) archivedView = archived;
    load();
  }

  /// assign جماعي ثم تحديث القايمة
  Future<
    ({int assigned, int already, int noLead, int notAllowed, String salesName})
  >
  assignMany(List<String> ids, String salesId) async {
    final r = await service.assign(ids, salesId);
    await load();
    return r;
  }

  Future<int> _unreadFor(String prefix) async {
    try {
      final rows = await service.conversations(
        provider: prefix,
        unreadOnly: true,
        limit: 100,
      );
      return rows.fold<int>(0, (s, c) => s + c.unread);
    } catch (_) {
      return 0; // مفيش صلاحية على الـ provider ده أو فشل → 0
    }
  }

  Future<void> refreshUnread() async {
    if (me == null) return;
    final r = await Future.wait([
      _unreadFor('messaging'),
      _unreadFor('unisent'),
    ]);
    unreadUnifonic = r[0];
    unreadUnisent = r[1];
    notifyListeners();
  }

  void _scheduleUnreadRefresh() {
    _unreadDebounce?.cancel();
    _unreadDebounce = Timer(const Duration(seconds: 2), refreshUnread);
  }

  void _sort() {
    conversations.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final x = a.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final y = b.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return y.compareTo(x);
    });
  }

  void upsert(WaConversation c) {
    final i = conversations.indexWhere((e) => e.id == c.id);
    // لو الفلتر الحالي أرشيف/مش أرشيف ومحادثة اتغيّرت حالتها → نشيلها من القايمة
    final belongs = c.archived == archivedView;
    if (i >= 0) {
      belongs ? conversations[i] = c : conversations.removeAt(i);
    } else if (belongs && query.isEmpty && !unreadOnly && salesFilter == null) {
      conversations.insert(0, c);
    }
    _sort();
    notifyListeners();
  }

  // ─────────────── actions ───────────────
  Future<void> markRead(String id) async {
    final i = conversations.indexWhere((c) => c.id == id);
    if (i >= 0 && conversations[i].unread > 0) {
      final n = conversations[i].unread;
      if (isUnisent) {
        unreadUnisent = (unreadUnisent - n).clamp(0, 1 << 30);
      } else {
        unreadUnifonic = (unreadUnifonic - n).clamp(0, 1 << 30);
      }
      await service.markRead(id).catchError((_) {});
      upsert(
        await service.conversation(id).catchError((_) => conversations[i]),
      );
    } else {
      await service.markRead(id).catchError((_) {});
    }
  }

  Future<void> togglePin(WaConversation c) async =>
      upsert(await service.pin(c.id, !c.pinned));

  Future<void> toggleArchive(WaConversation c) async =>
      upsert(await service.archive(c.id, !c.archived));

  Future<void> setInterest(WaConversation c, String? v) async =>
      upsert(await service.setInterest(c.id, v));

  // ─────────────── socket.io ───────────────
  Future<void> _connectSocket() async {
    if (_socket != null || _disposed) return;
    final socket = io.io(
      ApiConfig.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;

    Future<void> join() async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConfig.tokenKey);
      String? deviceId;
      try {
        deviceId = await DeviceHelper.getDeviceId();
      } catch (_) {}
      if (token == null) return;
      socket.emit('wa:join', {
        'token': token,
        if (deviceId != null) 'deviceId': deviceId,
      });
    }

    // بنعمل join مع كل connect/reconnect
    socket.onConnect((_) => join());

    socket.on('wa:update', (data) {
      if (data is! Map) return;
      final convJson = data['conversation'];
      final msgJson = data['message'];
      if (convJson is Map) {
        upsert(WaConversation.fromJson(Map<String, dynamic>.from(convJson)));
      }
      if (msgJson is Map) {
        final m = WaMessage.fromJson(Map<String, dynamic>.from(msgJson));
        _msgCtrl.add(m);
        if (!m.isOut) _scheduleUnreadRefresh();
      }
    });

    // المحادثة راحت لسيلز تاني → تتشال من عندي
    socket.on('wa:revoke', (data) {
      final id = data is Map ? data['conversationId']?.toString() : null;
      if (id == null) return;
      conversations.removeWhere((c) => c.id == id);
      notifyListeners();
      _scheduleUnreadRefresh();
    });

    socket.connect();
  }

  @override
  void dispose() {
    _disposed = true;
    _unreadDebounce?.cancel();
    _socket?.dispose();
    _msgCtrl.close();
    super.dispose();
  }
}
