// ignore_for_file: avoid_print

import 'package:dio/dio.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/utils/dio_client.dart';
import 'package:flutter_application_1/features/auth/data/models/activity_log_model.dart';
// عدّل المسار حسب مكان DioClient عندك

class ActivityPage {
  final List<ActivityLog> items;
  final bool hasMore;
  ActivityPage(this.items, this.hasMore);
}

class ActivityService {
  final _dio = DioClient.instance.dio;

  Future<ActivityPage> fetch({
    required bool isAdmin,
    int page = 1,
    int limit = 20,
    String? userName, // للأدمن بس
    List<String> actions = const [],
    List<String> modules = const [],
    String? resourceId,
    String? createdFrom, // yyyy-MM-dd
    String? createdTo,
  }) async {
    try {
      final params = <String, dynamic>{
        'page': page,
        'limit': limit,
        'sort': '-createdAt',
        'fields': 'user,action,module,resourceId,before,after,createdAt',
        if (isAdmin && userName != null && userName.isNotEmpty)
          'userName': userName,
        if (actions.isNotEmpty) 'action': actions,
        if (modules.isNotEmpty) 'module': modules,
        if (resourceId != null && resourceId.isNotEmpty)
          'resourceId': resourceId,
        'createdFrom': ?createdFrom,
        'createdTo': ?createdTo,
      };

      final res = await _dio.get(
        // الأدمن: كل اللوجز | غيره: لوج بتاعه بس
        isAdmin ? Endpoints.activityLogs : Endpoints.profileActivity,
        queryParameters: params,
        // action=update&action=delete بدل action[]=...
        options: Options(listFormat: ListFormat.multi),
      );

      final data = res.data;

      // بندور على الـ list في أكتر من مكان لأن شكل /profile/activity مختلف
      List raw = const [];
      Map pg = const {};
      if (data is List) {
        raw = data;
      } else if (data is Map) {
        final d = data['data'];
        if (d is List) {
          raw = d;
        } else if (d is Map) {
          // الـ list جوا object: logs / activities / items / docs
          for (final k in [
            'logs',
            'activities',
            'activity',
            'items',
            'docs',
            'data',
          ]) {
            if (d[k] is List) {
              raw = d[k] as List;
              break;
            }
          }
          if (d['paginationResult'] is Map) pg = d['paginationResult'] as Map;
        }
        // الـ pagination ممكن يبقى برا الـ data
        if (data['paginationResult'] is Map) {
          pg = data['paginationResult'] as Map;
        }
      }
      print('ACTIVITY URL: ${res.requestOptions.uri}');
      final list = raw
          .whereType<Map>()
          .map((e) => ActivityLog.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final hasMore = pg['next'] != null;
      return ActivityPage(list, hasMore);
    } catch (e) {
      throw DioClient.parse(e);
    }
  }
}

// عنصر واحد من /profile/activity
class MyActivityItem {
  final String type; // stage | comment
  final DateTime at;
  final String leadId;
  final String leadName;
  final String? stageName; // لو type == stage
  final String? stageColor; // hex مثل #1ABC9C
  final String? text; // لو type == comment
  final bool hasVoice;

  MyActivityItem({
    required this.type,
    required this.at,
    required this.leadId,
    required this.leadName,
    this.stageName,
    this.stageColor,
    this.text,
    this.hasVoice = false,
  });

  factory MyActivityItem.fromJson(Map<String, dynamic> j) {
    final st = j['stage'] is Map ? j['stage'] as Map : const {};
    return MyActivityItem(
      type: '${j['type'] ?? ''}',
      at: DateTime.tryParse('${j['at']}')?.toLocal() ?? DateTime.now(),
      leadId: '${j['leadId'] ?? ''}',
      leadName: '${j['leadName'] ?? ''}',
      stageName: st['name']?.toString(),
      stageColor: st['color']?.toString(),
      text: j['text']?.toString(),
      hasVoice: j['hasVoice'] == true,
    );
  }

  // نص مقروء
  String get summary {
    if (type == 'stage') return 'Moved "$leadName" to ${stageName ?? '—'}';
    if (type == 'comment') {
      final t = (text == null || text!.isEmpty)
          ? (hasVoice ? '🎤 Voice note' : '')
          : text!;
      return 'Commented on "$leadName": $t';
    }
    return '$type · $leadName';
  }

  // تاريخ بنظام AM/PM
  String get timeText {
    final h12 = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final p = at.hour >= 12 ? 'PM' : 'AM';
    return '${at.day}/${at.month}/${at.year}  $h12:${at.minute.toString().padLeft(2, '0')} $p';
  }
}

class MyActivityPage {
  final List<MyActivityItem> items;
  final bool hasMore;
  final String? nextBefore; // الـ cursor للصفحة اللي بعدها
  MyActivityPage(this.items, this.hasMore, this.nextBefore);
}

class MyActivityService {
  final _dio = DioClient.instance.dio;

  // before = الـ cursor (nextBefore من الرد السابق)
  Future<MyActivityPage> fetch({int limit = 5, String? before}) async {
    try {
      final res = await _dio.get(
        Endpoints.profileActivity,
        queryParameters: {'limit': limit, 'before': ?before},
      );
      final d = (res.data['data'] as Map?) ?? const {};
      final items = (d['items'] as List? ?? [])
          .whereType<Map>()
          .map((e) => MyActivityItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return MyActivityPage(
        items,
        d['hasMore'] == true,
        d['nextBefore']?.toString(),
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }
}
