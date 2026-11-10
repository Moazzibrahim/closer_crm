// leads_service.dart
// كل عمليات الـ Leads: قايمة بفلاتر، إنشاء، تعديل، stage، تعيين، bulk، deals، export.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/utils/dio_client.dart';
import 'package:flutter_application_1/features/leads/providers/admin_leads_filter_service.dart';
import 'package:flutter_application_1/features/notifications/provider/notification_service.dart';

class LeadsService {
  final Dio _dio = DioClient.instance.dio;
  final NotificationService _notifications;

  LeadsService({NotificationService? notifications})
    : _notifications = notifications ?? NotificationService();
  Map<String, dynamic> _map(Response r) =>
      Map<String, dynamic>.from(r.data as Map);

  /// قايمة الـ Leads (Admin/Manager). myLeads=true لليوزر العادي.
  /// الفلاتر اللي بتقبل أكتر من قيمة بتتبعت comma-separated (stage=a,b).

  Future<Map<String, dynamic>> getLeads(
    LeadsFilters filters, {
    bool myLeads = false,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final res = await _dio.get(
        myLeads ? Endpoints.myLeads : Endpoints.leads,
        queryParameters: filters.toQuery(
          myLeads: myLeads,
          page: page,
          limit: limit,
        ),
      );
      return _map(res);
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<Map<String, dynamic>> getLead(String id) async {
    try {
      return _map(await _dio.get(Endpoints.lead(id)));
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<Map<String, dynamic>> createLead(Map<String, dynamic> body) async {
    // body: name, email, phoneCountryCode, phone, phone2CountryCode, phone2,
    // projects[], campaigns[], channel, communicationWay, leadType, budget, notes, stage, sales
    try {
      return _map(await _dio.post(Endpoints.leads, data: body));
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// PATCH — ابعت الحقول اللي اتغيرت بس. للمسح ابعت null (مثلاً phone2: null).
  Future<Map<String, dynamic>> updateLead(
    String id,
    Map<String, dynamic> fields,
  ) async {
    try {
      return _map(await _dio.patch(Endpoints.lead(id), data: fields));
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// تغيير الـ stage. لو الـ stage من نوع Done Deal ابعت deal كمان.
  Future<Map<String, dynamic>> updateStage(
    String leadId, {
    required String stageId,
    String? notes,
    Map<String, dynamic>? deal, // {unitPrice, unitType, unitNumber, ...}
  }) async {
    try {
      return _map(
        await _dio.patch(
          Endpoints.leadStage(leadId),
          data: {'stage': stageId, 'notes': ?notes, 'deal': ?deal},
        ),
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<void> _notifyAssigned() async {
    try {
      final result = await _notifications
          .sendTest(); // 👈 بدّلها بـ endpoint الإرسال الحقيقي لما يتوفر
      for (final e in result.errors) {
        debugPrint('Push error: ${e.code} - ${e.message}');
      }
    } catch (e) {
      debugPrint('Assign notification failed: $e');
    }
  }

  /// mode: replace | add | remove
  /// notify=false بيستخدمه bulkAssign عشان يبعت إشعار واحد بس
  Future<Map<String, dynamic>> assign(
    String leadId,
    List<String> salesIds, {
    String mode = 'add',
    bool notify = true,
  }) async {
    try {
      final res = _map(
        await _dio.patch(
          Endpoints.leadAssign(leadId),
          data: {'sales': salesIds, 'mode': mode},
        ),
      );
      if (notify && mode != 'remove') unawaited(_notifyAssigned());
      return res;
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// replace → PATCH /Leads/:id/assign لكل lead
  /// add     → POST  /Leads/bulk-assign
  Future<Map<String, dynamic>> bulkAssign(
    List<String> leadIds,
    List<String> salesIds, {
    String mode = 'add',
  }) async {
    try {
      final Map<String, dynamic> res;
      if (mode == 'replace') {
        final results = await Future.wait(
          leadIds.map(
            (id) => assign(id, salesIds, mode: 'replace', notify: false),
          ),
        );
        res = {'results': results};
      } else {
        res = _map(
          await _dio.post(
            Endpoints.leadsBulkAssign,
            data: {'leadIds': leadIds, 'sales': salesIds, 'mode': mode},
          ),
        );
      }
      if (mode != 'remove') unawaited(_notifyAssigned()); // إشعار واحد بس
      return res;
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// mode: replace | add | remove
  // Future<Map<String, dynamic>> assign(
  //   String leadId,
  //   List<String> salesIds, {
  //   String mode = 'add',
  // }) async {
  //   try {
  //     return _map(
  //       await _dio.patch(
  //         Endpoints.leadAssign(leadId),
  //         data: {'sales': salesIds, 'mode': mode},
  //       ),
  //     );
  //   } catch (e) {
  //     throw DioClient.parse(e);
  //   }
  // }

  // /// replace → PATCH /Leads/bulk-assign
  // /// add     → POST  /Leads/bulk-assign
  // Future<Map<String, dynamic>> bulkAssign(
  //   List<String> leadIds,
  //   List<String> salesIds, {
  //   String mode = 'add',
  // }) async {
  //   try {
  //     if (mode == 'replace') {
  //       // PATCH /Leads/:id/assign لكل lead (بدل PATCH /Leads/bulk-assign)
  //       final results = await Future.wait(
  //         leadIds.map((id) => assign(id, salesIds, mode: 'replace')),
  //       );
  //       return {'results': results};
  //     }
  //     return _map(
  //       await _dio.post(
  //         Endpoints.leadsBulkAssign,
  //         data: {'leadIds': leadIds, 'sales': salesIds, 'mode': mode},
  //       ),
  //     );
  //   } catch (e) {
  //     throw DioClient.parse(e);
  //   }
  // }

  /// changes: ابعت اللي عايز تغيره بس (stage, channel, campaigns + campaignsMode, projects + projectsMode)
  Future<Map<String, dynamic>> bulkUpdate(
    List<String> leadIds,
    Map<String, dynamic> changes,
  ) async {
    try {
      return _map(
        await _dio.patch(
          Endpoints.leadsBulkUpdate,
          data: {'leadIds': leadIds, 'changes': changes},
        ),
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// أكشنز مجمعة: assign / stage / resetDate / clearHistory (واحد على الأقل)
  Future<Map<String, dynamic>> bulkActions(
    List<String> leadIds,
    Map<String, dynamic> actions,
  ) async {
    try {
      return _map(
        await _dio.patch(
          Endpoints.leadsBulkActions,
          data: {'leadIds': leadIds, ...actions},
        ),
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// Soft delete: بيعمل deactivate للـ lead (بيروح Leads Trash) من غير ما يتمسح من الداتابيز.
  /// ⚠️ بيبعت PATCH { isActive: false } — لو الباك عندك له endpoint مخصوص للـ deactivate
  /// غيّر السطر ده بس.
  Future<void> deactivateLead(String id) async {
    try {
      await _dio.patch(Endpoints.lead(id), data: {'isActive': false});
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// بيرجّع lead من الـ Trash.
  Future<void> activateLead(String id) async {
    try {
      await _dio.patch(Endpoints.lead(id), data: {'isActive': true});
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// ⚠️ Hard delete من الداتابيز — ماتستخدمهاش في الـ UI العادي.
  Future<void> deleteLead(String id) async {
    try {
      await _dio.delete(Endpoints.lead(id));
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<void> resetCreationDate(
    String id,
    DateTime date, {
    String? notes,
  }) async {
    try {
      await _dio.patch(
        Endpoints.leadCreationDate(id),
        data: {'date': date.toUtc().toIso8601String(), 'notes': ?notes},
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<void> clearHistory(String id, {String? notes}) async {
    try {
      await _dio.post(Endpoints.leadClearHistory(id), data: {'notes': ?notes});
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  /// تطبيق submission معين على الـ lead (fields: name, email, phone, project)
  Future<void> applySubmission(
    String id,
    int submissionNumber,
    List<String> fields,
  ) async {
    try {
      await _dio.patch(
        Endpoints.leadSubmissionApply(id, submissionNumber),
        data: {'fields': fields},
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  // ---------------- Deals ----------------

  Future<Map<String, dynamic>> makeDeal(
    String leadId,
    Map<String, dynamic> deal,
  ) async {
    // deal: project, unitPrice, unitType, unitNumber, companyCommissionRatio, cashbackRatio, amountPaid, closedAt?
    try {
      return _map(await _dio.post(Endpoints.leadDeals(leadId), data: deal));
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<Map<String, dynamic>> updateDeal(
    String leadId,
    String dealId,
    Map<String, dynamic> fields,
  ) async {
    // الـ collection بيستخدم POST للتعديل — لو الباك عندك PUT/PATCH غيّر السطر ده
    try {
      return _map(
        await _dio.post(Endpoints.leadDeal(leadId, dealId), data: fields),
      );
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  Future<void> deleteDeal(String leadId, String dealId) async {
    try {
      await _dio.delete(Endpoints.leadDeal(leadId, dealId));
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  // ---------------- Export ----------------

  /// بيرجع bytes الملف (xlsx) — احفظه بـ path_provider + File أو share_plus
  /// tzOffset بالدقايق (دبي = 240)
  Future<List<int>> exportLeads({
    String scope = 'all',
    String format = 'xlsx',
    List<String> columns = const ['name', 'phone', 'stage', 'sales'],
    Map<String, dynamic>? filters,
    int tzOffset = 240,
  }) async {
    try {
      final res = await _dio.post<List<int>>(
        Endpoints.leadsExport,
        data: {
          'scope': scope,
          'format': format,
          'columns': columns,
          'filters': ?filters,
          'tzOffset': tzOffset,
        },
        options: Options(responseType: ResponseType.bytes),
      );
      return res.data ?? [];
    } catch (e) {
      throw DioClient.parse(e);
    }
  }
}
