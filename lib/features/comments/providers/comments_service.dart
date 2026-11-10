// comments_service.dart
// الكومنتات والردود (نصي + صوتي) على الـ Lead.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/utils/dio_client.dart';

class CommentsService {
  final Dio _dio = DioClient.instance.dio;

  Map<String, dynamic> _map(Response r) =>
      Map<String, dynamic>.from(r.data as Map);

  Future<Map<String, dynamic>> getComments(String leadId) async {
    try {
      return _map(await _dio.get(Endpoints.comments(leadId)));
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// stage اختياري، بس إجباري لو الـ lead ملوش stage.
  /// scheduledAt: موعد المتابعة (بيتبعت UTC)
  Future<Map<String, dynamic>> addComment(
    String leadId, {
    String? text, // 👈 اختياري: ينفع stage أو scheduledAt من غير نص
    DateTime? scheduledAt,
    String? stageId,
    Map<String, dynamic>? deal, // 👈 لو الـ stage من نوع deal
  }) async {
    try {
      final t = text?.trim();
      return _map(
        await _dio.post(
          Endpoints.comments(leadId),
          data: {
            if (t != null && t.isNotEmpty) 'text': t,
            if (scheduledAt != null)
              'scheduledAt': scheduledAt.toUtc().toIso8601String(),
            'stage': ?stageId,
            'deal': ?deal,
          },
        ),
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// كومنت صوتي: multipart/form-data.
  /// اسم الحقل 'voice' — لو الباك رجّع "Unexpected field" شوف اسمه في middleware/uploadCommentVoice.
  Future<Map<String, dynamic>> addVoiceComment(
    String leadId, {
    required File voiceFile,
    String? text,
    DateTime? scheduledAt,
    String? stageId,
    Map<String, dynamic>? deal, // 👈 لو الـ stage من نوع deal
  }) async {
    try {
      final form = FormData.fromMap({
        'voice': await MultipartFile.fromFile(voiceFile.path),
        'text': ?text,
        'deal': ?(deal == null ? null : jsonEncode(deal)),
        if (scheduledAt != null)
          'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        'stage': ?stageId,
      });
      // Dio بيحط الـ multipart content-type لوحده لما تبعت FormData
      return _map(await _dio.post(Endpoints.comments(leadId), data: form));
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<Map<String, dynamic>> editComment(
    String leadId,
    String commentId,
    String text,
  ) async {
    try {
      return _map(
        await _dio.patch(
          Endpoints.comment(leadId, commentId),
          data: {'text': text},
        ),
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<void> deleteComment(String leadId, String commentId) async {
    try {
      await _dio.delete(Endpoints.comment(leadId, commentId));
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  // ---------------- Replies ----------------

  Future<Map<String, dynamic>> addReply(
    String leadId,
    String commentId,
    String text,
  ) async {
    try {
      return _map(
        await _dio.post(
          Endpoints.replies(leadId, commentId),
          data: {'text': text},
        ),
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<Map<String, dynamic>> addVoiceReply(
    String leadId,
    String commentId,
    File voiceFile,
  ) async {
    try {
      final form = FormData.fromMap({
        'voice': await MultipartFile.fromFile(voiceFile.path),
      });
      return _map(
        await _dio.post(Endpoints.replies(leadId, commentId), data: form),
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<Map<String, dynamic>> editReply(
    String leadId,
    String commentId,
    String replyId,
    String text,
  ) async {
    try {
      return _map(
        await _dio.patch(
          Endpoints.reply(leadId, commentId, replyId),
          data: {'text': text},
        ),
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<void> deleteReply(
    String leadId,
    String commentId,
    String replyId,
  ) async {
    try {
      await _dio.delete(Endpoints.reply(leadId, commentId, replyId));
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  // ---------------- Voice playback ----------------

  /// بيرجع bytes الصوت (احفظه في ملف مؤقت وشغّله بـ just_audio مثلاً).
  /// الـ endpoint محتاج Authorization، فمينفعش تديه URL مباشرة لـ player من غير headers.
  Future<List<int>> downloadCommentVoice(
    String leadId,
    String commentId,
  ) async {
    final url = Endpoints.commentVoice(leadId, commentId);
    try {
      final res = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      return List<int>.from(res.data ?? const []);
    } on DioException catch (e) {
      final body = e.response?.data;
      print('VOICE URL: ${e.requestOptions.uri}');
      print('VOICE STATUS: ${e.response?.statusCode}');
      if (body is List<int>) {
        print('VOICE BODY: ${utf8.decode(body, allowMalformed: true)}');
      }
      throw DioClient.parse(e);
    }
  }

  Future<List<int>> downloadReplyVoice(
    String leadId,
    String commentId,
    String replyId,
  ) async {
    try {
      final res = await _dio.get<List<int>>(
        Endpoints.replyVoice(leadId, commentId, replyId),
        options: Options(responseType: ResponseType.bytes),
      );
      return res.data ?? [];
    } catch (e) {
      throw DioClient.parse(e);
    }
  }
}
