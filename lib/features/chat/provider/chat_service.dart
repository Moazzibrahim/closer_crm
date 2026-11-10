// lib/features/ai_chat/data/ai_chat_service.dart
// Service الخاص بالـ AI Chat — بيستخدم ApiConfig و Endpoints الموجودين عندك.
// محتاج package: dio

// ignore_for_file: avoid_print

import 'package:dio/dio.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/utils/dio_client.dart';

// ───────────── Models ─────────────

/// رسالة واحدة في المحادثة
class ChatMessage {
  final String role; // 'user' أو 'assistant'
  final String content;
  final DateTime createdAt;
  final bool isError; // رسالة خطأ تتعرض في الـ UI بس، ما بتتبعتش في الـ history

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? createdAt,
    this.isError = false,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isUser => role == 'user';

  /// الشكل اللي بيتبعت للباك جوه history
  // مؤقتاً بنبعت النص تحت كل الأسماء المحتملة لأن الباك بيرفض 'content' لوحده
  // (Gemini رجّع parts[0] فاضي). لما تعرف الاسم الصح، سيب واحد بس.
  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'text': content,
    'message': content,
    'parts': [
      {'text': content},
    ],
  };
}

/// استهلاك يوزر واحد (اليومي)
/// الأسماء مرنة عشان شكل الـ response ممكن يختلف شوية — عدّلها لو الباك بيرجع أسماء تانية
class AiUsage {
  final String? userId;
  final String? userName;
  final int used;
  final int limit;
  final int? _remaining;
  final bool allowed; // في رد الشات بس، وغير كده بتتحسب من reachedLimit
  final String? role;
  final bool isActive;
  final bool unlimited; // يوزر من غير حد
  final String? limitSource; // 'custom' أو 'default'
  final int? customLimit;
  final bool reachedLimit;

  const AiUsage({
    this.userId,
    this.userName,
    this.used = 0,
    this.limit = 0,
    int? remaining,
    this.allowed = true,
    this.role,
    this.isActive = true,
    this.unlimited = false,
    this.limitSource,
    this.customLimit,
    this.reachedLimit = false,
  }) : _remaining = remaining;

  int get remaining => _remaining ?? (limit - used).clamp(0, limit);
  bool get isCustomLimit => limitSource == 'custom';

  // يغطي 3 أشكال: /usage (used, remaining, limit)
  // /usage/all و PUT limit (userId, name, role, ... كاملة)
  // ورد الشات (allowed, used, remaining, limit)
  factory AiUsage.fromJson(Map<String, dynamic> j) {
    int toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    final reached = j['reachedLimit'] == true;
    return AiUsage(
      userId: j['userId']?.toString(),
      userName: j['name']?.toString(),
      used: toInt(j['used']),
      limit: toInt(j['limit']), // null (unlimited) → 0
      remaining: j['remaining'] == null ? null : toInt(j['remaining']),
      allowed: j['allowed'] is bool ? j['allowed'] as bool : !reached,
      role: j['role']?.toString(),
      isActive: j['isActive'] is bool ? j['isActive'] as bool : true,
      unlimited: j['unlimited'] == true,
      limitSource: j['limitSource']?.toString(),
      customLimit: j['customLimit'] == null ? null : toInt(j['customLimit']),
      reachedLimit: reached,
    );
  }
}

/// رد الـ AI الكامل (data جوه الـ response)
class ChatReply {
  final String reply;
  final AiUsage? usage; // العداد المحدّث بعد الرسالة دي
  final bool aiSummaryUnavailable;
  final List<Map<String, dynamic>>
  usedQueries; // الاستعلامات اللي الـ AI نفذها (للـ debug أو عرض متقدم)
  final List<dynamic> voiceNotes;

  const ChatReply({
    required this.reply,
    this.usage,
    this.aiSummaryUnavailable = false,
    this.usedQueries = const [],
    this.voiceNotes = const [],
  });

  factory ChatReply.fromJson(Map<String, dynamic> d) => ChatReply(
    reply: (d['reply'] ?? '').toString(),
    usage: d['usage'] is Map<String, dynamic>
        ? AiUsage.fromJson(d['usage'] as Map<String, dynamic>)
        : null,
    aiSummaryUnavailable: d['aiSummaryUnavailable'] == true,
    usedQueries: (d['usedQueries'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList(),
    voiceNotes: d['voiceNotes'] as List? ?? const [],
  );
}

/// نتيجة paginated لاستهلاك كل اليوزرز (Admin)
class AiUsagePage {
  final List<AiUsage> items;
  final int page;
  final int totalPages;
  const AiUsagePage({
    required this.items,
    required this.page,
    required this.totalPages,
  });
}

/// Exception موحد بيتعرض رسالته للمستخدم
class AiChatException implements Exception {
  final String message;
  final int? statusCode;
  AiChatException(this.message, {this.statusCode});

  /// 429 غالباً = خلص الحد اليومي
  bool get isLimitReached => statusCode == 429;

  @override
  String toString() => message;
}

// ───────────── Service ─────────────

class AiChatService {
  // Dio instance المشترك: الـ baseUrl والـ Authorization بيتضافوا
  // تلقائياً من الـ interceptor في DioClient مع كل request
  final Dio _dio = DioClient.instance.dio;

  /// بيفك الـ response ويرمي AiChatException لو status مش 2xx
  /// (Dio بيرمي DioException لوحده على أي status مش 2xx، فبنحوّله في _send)
  Map<String, dynamic> _handle(Response res) {
    Map<String, dynamic> body = {};
    final decoded = res.data;
    if (decoded is Map) body = Map<String, dynamic>.from(decoded);

    final code = res.statusCode ?? 0;
    if (code >= 200 && code < 300) return body;

    final msg = (body['message'] ?? body['error'] ?? 'Something went wrong')
        .toString();
    print('AI ${res.requestOptions.uri} → $code\n${res.data}');
    throw AiChatException(msg, statusCode: code);
  }

  /// نفّذ request مع معالجة أخطاء الشبكة والـ timeout
  /// (الـ timeout بييجي من BaseOptions في DioClient: connectTimeout/receiveTimeout)
  Future<Map<String, dynamic>> _send(Future<Response> Function() call) async {
    try {
      final res = await call();
      return _handle(res);
    } on AiChatException {
      rethrow;
    } on DioException catch (e) {
      // timeout
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw AiChatException('Request timed out, please try again');
      }

      // السيرفر رد بـ status مش 2xx → نفس معالجة _handle
      final res = e.response;
      if (res != null) {
        Map<String, dynamic> body = {};
        if (res.data is Map) body = Map<String, dynamic>.from(res.data as Map);
        final msg = (body['message'] ?? body['error'] ?? 'Something went wrong')
            .toString();
        print('AI ${res.requestOptions.uri} → ${res.statusCode}\n${res.data}');
        throw AiChatException(msg, statusCode: res.statusCode);
      }

      print('AI request failed: $e');
      throw AiChatException('No internet connection');
    } catch (e) {
      print('AI request failed: $e');
      throw AiChatException('No internet connection');
    }
  }

  /// POST /aichat/chat — يبعت الرسالة + الـ history ويرجع رد الـ AI
  Future<ChatReply> chat({
    required String message,
    List<ChatMessage> history = const [],
  }) async {
    final data = await _send(
      () => _dio.post(
        Endpoints.aiChat,
        data: {
          'message': message,
          'history': history.map((m) => m.toJson()).toList(),
        },
      ),
    );

    // الرد الفعلي: { status, data: { reply, usedQueries, voiceNotes, usage, ... } }
    final inner = data['data'];
    if (inner is! Map) {
      throw AiChatException('Unexpected response from server');
    }
    return ChatReply.fromJson(Map<String, dynamic>.from(inner));
  }

  /// GET /aichat/usage — استهلاكي أنا
  Future<AiUsage> myUsage() async {
    final data = await _send(() => _dio.get(Endpoints.aiUsage));
    final inner = data['data'];
    return AiUsage.fromJson(
      inner is Map ? Map<String, dynamic>.from(inner) : data,
    );
  }

  /// GET /aichat/usage/all — Admin بس
  Future<AiUsagePage> allUsage({
    int page = 1,
    int limit = 10,
    String? keyword,
    List<String>? userIds,
  }) async {
    final data = await _send(
      () => _dio.get(
        Endpoints.aiUsageAll,
        queryParameters: {
          'page': '$page',
          'limit': '$limit',
          if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
          if (userIds != null && userIds.isNotEmpty)
            'userIds': userIds.join(','),
        },
      ),
    );

    // الرد: { data: [...], paginationResult: { currentPage, NumberOfPages, totalItems } }
    final list = data['data'];
    final pagination = data['paginationResult'];
    return AiUsagePage(
      items: (list is List ? list : [])
          .whereType<Map>()
          .map((e) => AiUsage.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      page: page,
      totalPages: (pagination is Map ? pagination['NumberOfPages'] : null) ?? 1,
    );
  }

  /// PUT /aichat/usage/:userId/limit — Admin بس: يعدّل الحد اليومي ليوزر
  /// بيرجع بيانات اليوزر المحدّثة (used / limit / remaining ...)
  Future<AiUsage> setUserLimit(String userId, int limit) async {
    final data = await _send(
      () => _dio.put(Endpoints.aiUsageLimit(userId), data: {'limit': limit}),
    );
    return AiUsage.fromJson(Map<String, dynamic>.from(data['data'] as Map));
  }
}
