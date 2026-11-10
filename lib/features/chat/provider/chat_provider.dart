// lib/features/ai_chat/presentation/providers/ai_chat_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/features/chat/provider/chat_service.dart';

class AiChatProvider extends ChangeNotifier {
  final AiChatService _service;
  AiChatProvider({AiChatService? service})
    : _service = service ?? AiChatService();

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool _sending = false; // بيستنى رد الـ AI (للـ typing indicator)
  bool get sending => _sending;

  AiUsage? usage;
  // unlimited = مفيش حد خالص
  bool get limitReached =>
      usage != null &&
      !usage!.unlimited &&
      (!usage!.allowed || usage!.remaining == 0);

  /// استهلاكي — نادي عليها لما الشاشة تفتح
  Future<void> loadUsage() async {
    try {
      usage = await _service.myUsage();
      notifyListeners();
    } catch (_) {
      /* مش حرجة، نتجاهلها */
    }
  }

  /// ابعت رسالة
  // الـ history: بنستبعد رسايل الخطأ + رسالة اليوزر اللي الرد عليها فشل،
  // عشان ما تتبعتش للباك كأنها سؤال متجاوب عليه
  List<ChatMessage> _buildHistory() {
    final out = <ChatMessage>[];
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      if (m.isError) continue;
      final failed =
          m.isUser && i + 1 < _messages.length && _messages[i + 1].isError;
      if (!failed) out.add(m);
    }
    return out;
  }

  /// ابعت رسالة
  Future<void> send(String text) async {
    text = text.trim();
    if (text.isEmpty || _sending) return;

    final history = _buildHistory(); // قبل ما نضيف الرسالة الجديدة

    _messages.add(ChatMessage(role: 'user', content: text));
    _sending = true;
    notifyListeners();

    try {
      final res = await _service.chat(message: text, history: history);
      _messages.add(ChatMessage(role: 'assistant', content: res.reply));
      if (res.usage != null) usage = res.usage;
    } on AiChatException catch (e) {
      // التفاصيل التقنية في الكونسول بس
      debugPrint('AI chat error [${e.statusCode}]: ${e.message}');
      if (e.isLimitReached) loadUsage();
      // المستخدم بيشوف رسالة عامة بس
      _messages.add(
        ChatMessage(
          role: 'assistant',
          content: e.isLimitReached
              ? 'You reached your daily AI limit.'
              : 'Something went wrong. Please try again.',
          isError: true,
        ),
      );
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  /// أعد إرسال آخر رسالة فشلت
  Future<void> retry() async {
    if (_sending || _messages.length < 2 || !_messages.last.isError) return;
    _messages.removeLast(); // رسالة الخطأ
    final failed = _messages.removeLast(); // سؤال اليوزر اللي فشل
    await send(failed.content); // send هتضيفه تاني من جديد
  }

  void clear() {
    _messages.clear();
    notifyListeners();
  }
}

// ───────────── Admin: استهلاك كل اليوزرز ─────────────
class AiUsageAdminProvider extends ChangeNotifier {
  final AiChatService _service;
  AiUsageAdminProvider({AiChatService? service})
    : _service = service ?? AiChatService();

  final List<AiUsage> items = [];
  bool loading = false;
  String? error;
  int _page = 1;
  int _totalPages = 1;
  String _keyword = '';
  bool get hasMore => _page < _totalPages;

  /// refresh=true يبدأ من الأول (بحث جديد أو سحب للتحديث)
  Future<void> load({bool refresh = false, String? keyword}) async {
    if (loading) return;
    if (refresh) {
      _page = 1;
      items.clear();
      if (keyword != null) _keyword = keyword;
    } else if (!hasMore && items.isNotEmpty) {
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _service.allUsage(page: _page, keyword: _keyword);
      items.addAll(res.items);
      _totalPages = res.totalPages;
      _page++;
    } on AiChatException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// تعديل الحد اليومي ليوزر
  Future<bool> setLimit(String userId, int limit) async {
    try {
      // الباك بيرجع اليوزر كامل بعد التعديل، فبنستبدله في الليستة
      final updated = await _service.setUserLimit(userId, limit);
      final i = items.indexWhere((u) => u.userId == userId);
      if (i != -1) {
        items[i] = updated;
        notifyListeners();
      }
      return true;
    } on AiChatException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
  }
}
