// messaging_service.dart
// كل الـ calls بتاعة الـ inbox. الـ prefix بيتبدل بين Unifonic و Unisent:
//   unifonic → /messaging/inbox      unisent → /unisent/inbox
// الـ responses هنا plain JSON (مش {status,data}) والأخطاء {"error": "..."}.

// ignore_for_file: avoid_print

import 'package:dio/dio.dart';
import 'package:flutter_application_1/core/utils/dio_client.dart';
import 'package:flutter_application_1/features/messaging/data/messaging_model.dart';

class MessagingService {
  final Dio _dio = DioClient.instance.dio;

  /// 'messaging' (Unifonic) أو 'unisent'
  String prefix = 'messaging';
  String get _inbox => '/$prefix/inbox';

  Future<T> _run<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      // 🔍 مؤقت: يطبع status + رد الباك الفعلي
      if (e is DioException) {
        print(
          'API ERR ${e.requestOptions.method} ${e.requestOptions.path} '
          '→ ${e.response?.statusCode} ${e.response?.data}',
        );
      } else {
        print('NON-DIO ERR: $e'); // لو ده اللي ظهر → مشكلة parsing مش مشكلة باك
      }
      throw DioClient.parse(e);
    }
  }

  Map<String, dynamic> _map(Response r) =>
      Map<String, dynamic>.from(r.data as Map);

  // دايماً من /messaging/inbox/me الأول (بيرجّع provider)
  Future<InboxMe> me() => _run(() async {
    final r = await _dio.get('/messaging/inbox/me');
    return InboxMe.fromJson(_map(r));
  });

  Future<List<SalesOption>> salesOptions() => _run(() async {
    final r = await _dio.get('$_inbox/sales');
    return [
      for (final e in (r.data as List))
        SalesOption.fromJson(Map<String, dynamic>.from(e)),
    ];
  });

  Future<List<WaConversation>> conversations({
    String?
    provider, // 👈 جديد: 'messaging' | 'unisent' (الافتراضي = prefix الحالي)
    String? q,
    String? salesId,
    String? interest,
    bool unreadOnly = false,
    bool archived = false,
    int page = 1,
    int limit = 30,
  }) => _run(() async {
    final r = await _dio.get(
      '/${provider ?? prefix}/inbox/conversations', // 👈
      queryParameters: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (salesId != null && salesId.isNotEmpty) 'salesId': salesId,
        'interest': ?interest,
        if (unreadOnly) 'unread': 1,
        if (archived) 'view': 'archived',
        'page': page,
        'limit': limit,
      },
    );
    return [
      for (final e in (_map(r)['rows'] as List? ?? const []))
        WaConversation.fromJson(Map<String, dynamic>.from(e)),
    ];
  });

  Future<WaConversation> conversation(String id) => _run(() async {
    final r = await _dio.get('$_inbox/conversations/$id');
    return WaConversation.fromJson(_map(r));
  });

  /// الرسائل من الأقدم للأحدث. `before` = وقت أول رسالة معروضة لتحميل الأقدم
  Future<({List<WaMessage> rows, bool hasMore})> messages(
    String id, {
    DateTime? before,
    int limit = 50,
  }) => _run(() async {
    final r = await _dio.get(
      '$_inbox/conversations/$id/messages',
      queryParameters: {
        if (before != null) 'before': before.toUtc().toIso8601String(),
        'limit': limit,
      },
    );
    final m = _map(r);
    return (
      rows: [
        for (final e in (m['rows'] as List? ?? const []))
          WaMessage.fromJson(Map<String, dynamic>.from(e)),
      ],
      hasMore: m['hasMore'] == true,
    );
  });

  Future<void> markRead(String id) =>
      _run(() => _dio.post('$_inbox/conversations/$id/read'));

  Future<List<WaTemplate>> templates(String id) => _run(() async {
    final r = await _dio.get('$_inbox/conversations/$id/templates');
    return [
      for (final e in (r.data as List))
        WaTemplate.fromJson(Map<String, dynamic>.from(e)),
    ];
  });

  Future<WaMessage> sendText(String id, String text, {String? replyTo}) =>
      _send(id, {'type': 'text', 'text': text, 'replyTo': ?replyTo});

  Future<WaMessage> sendMedia(
    String id, {
    required String type, // image | video | audio | file | gif | sticker
    required String url,
    String? fileName,
    String? caption,
    bool voice = false,
  }) => _send(id, {
    'type': type,
    'url': url,
    'fileName': ?fileName,
    if (caption != null && caption.isNotEmpty) 'text': caption,
    if (voice) 'voice': true,
  });

  /// kind = stickers | gifs. بدون q بيرجّع الـ trending. بيحتاج GIPHY key في الباك (وإلا 400).
  Future<({List<Map<String, dynamic>> rows, int? next})> giphy({
    String kind = 'stickers',
    String? q,
    int offset = 0,
  }) => _run(() async {
    final r = await _dio.get(
      '/messaging/inbox/giphy',
      queryParameters: {
        'kind': kind,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        'offset': offset,
        'lang': 'ar',
      },
    );
    final m = _map(r);
    return (
      rows: [
        for (final e in (m['rows'] as List? ?? const []))
          Map<String, dynamic>.from(e),
      ],
      next: (m['next'] as num?)?.toInt(),
    );
  });

  Future<WaMessage> sendTemplate(
    String id,
    WaTemplate t, {
    List<String> bodyVars = const [],
    List<String> headerVars = const [],
    String? mediaUrl,
  }) => _send(id, {
    'type': 'template',
    'name': t.name,
    'language': t.language,
    'values': {
      'bodyVars': bodyVars,
      'headerVars': headerVars,
      if (mediaUrl != null && mediaUrl.isNotEmpty) 'mediaUrl': mediaUrl,
    },
  });

  Future<WaMessage> _send(String id, Map<String, dynamic> body) =>
      _run(() async {
        final r = await _dio.post(
          '$_inbox/conversations/$id/messages',
          data: body,
        );
        return WaMessage.fromJson(_map(r)); // 201
      });

  /// رفع ملف قبل الإرسال (image 5MB / video+audio 16MB / file 25MB)
  Future<({String url, String type, String fileName})> upload(
    String path,
    String fileName,
  ) => _run(() async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(path, filename: fileName),
    });
    final r = await _dio.post(
      '$_inbox/upload',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    final m = _map(r);
    return (
      url: m['url'].toString(),
      type: (m['type'] ?? 'file').toString(),
      fileName: (m['fileName'] ?? fileName).toString(),
    );
  });

  Future<WaConversation> pin(String id, bool on) => _toggle(id, 'pin', on);
  Future<WaConversation> archive(String id, bool on) =>
      _toggle(id, 'archive', on);

  Future<WaConversation> _toggle(String id, String action, bool on) =>
      _run(() async {
        final r = await _dio.post(
          '$_inbox/conversations/$id/$action',
          data: {'on': on},
        );
        return WaConversation.fromJson(_map(r));
      });

  /// value: interested | not_interested | null
  Future<WaConversation> setInterest(String id, String? value) =>
      _run(() async {
        final r = await _dio.post(
          '$_inbox/conversations/$id/interest',
          data: {'value': value},
        );
        return WaConversation.fromJson(_map(r));
      });

  Future<void> saveNote(String id, String text) => _run(
    () => _dio.put('$_inbox/conversations/$id/note', data: {'text': text}),
  );

  /// scope: me | all
  Future<void> deleteMessage(String mid, String scope) => _run(
    () => _dio.post('$_inbox/messages/$mid/delete', data: {'scope': scope}),
  );

  /// مش للـ Sales (403)
  /// مش للـ Sales (403)
  Future<
    ({int assigned, int already, int noLead, int notAllowed, String salesName})
  >
  assign(List<String> conversationIds, String salesId) => _run(() async {
    final r = await _dio.post(
      '$_inbox/assign',
      data: {'conversationIds': conversationIds, 'salesId': salesId},
    );
    final m = _map(r);
    int n(String k) => (m[k] as num?)?.toInt() ?? 0;
    return (
      assigned: n('assigned'),
      already: n('already'),
      noLead: n('noLead'),
      notAllowed: n('notAllowed'),
      salesName: m['salesName']?.toString() ?? '',
    );
  });

  /// POST /messaging/messages/send — Admin / Manager بس.
  /// channel = sms | whatsapp. ملاحظة: الدليل ما ذكرش نسخة /unisent/ للراوت ده.
  Future<({int sent, List failed, List invalid})> quickSend({
    required List<String> numbers,
    required String channel,
    String? message,
    String? templateName,
    String? language,
  }) => _run(() async {
    final r = await _dio.post(
      '/messaging/messages/send',
      data: {
        'numbers': numbers,
        'channel': channel,
        if (message != null && message.isNotEmpty) 'message': message,
        'templateName': ?templateName,
        'language': ?language,
      },
    );
    final m = _map(r);
    return (
      sent: (m['sent'] as num?)?.toInt() ?? 0,
      failed: (m['failed'] as List?) ?? const [],
      invalid: (m['invalid'] as List?) ?? const [],
    );
  });
}
