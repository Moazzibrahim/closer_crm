// crm_settings.dart
// مكان الملف المقترح: lib/features/settings/crm_settings.dart
// بيحتوي: Models + Service + Provider لـ GET /crm-settings/me
// ignore_for_file: unnecessary_this

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────
//  Helpers للـ parsing الآمن (عشان أي field ناقص ما يكسرش الأبلكيشن)
// ─────────────────────────────────────────────
bool _b(dynamic v, [bool d = false]) => v is bool ? v : d;
String _s(dynamic v, [String d = '']) => v?.toString() ?? d;
Map<String, dynamic> _m(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

// ─────────────────────────────────────────────
//  Models
// ─────────────────────────────────────────────

/// { "hidden": [...] } — القائمة دي فيها العناصر المخفية عن اليوزر
class HiddenList {
  final List<String> hidden;
  const HiddenList([this.hidden = const []]);

  factory HiddenList.fromJson(dynamic json) {
    final raw = _m(json)['hidden'];
    return HiddenList(raw is List ? raw.map((e) => e.toString()).toList() : []);
  }

  /// true لو العنصر ده مسموح يظهر
  bool allows(String key) => !hidden.contains(key);
}

class NotificationPerms {
  final bool leadCreated, leadAssigned, teamAssigned, leadComment, leadReply;
  const NotificationPerms({
    this.leadCreated = true,
    this.leadAssigned = true,
    this.teamAssigned = true,
    this.leadComment = true,
    this.leadReply = true,
  });

  factory NotificationPerms.fromJson(dynamic json) {
    final j = _m(json);
    return NotificationPerms(
      leadCreated: _b(j['leadCreated'], true),
      leadAssigned: _b(j['leadAssigned'], true),
      teamAssigned: _b(j['teamAssigned'], true),
      leadComment: _b(j['leadComment'], true),
      leadReply: _b(j['leadReply'], true),
    );
  }
}

class InventoryPerms {
  final bool view, add, update, activate, deactivate;
  const InventoryPerms({
    this.view = false,
    this.add = false,
    this.update = false,
    this.activate = false,
    this.deactivate = false,
  });

  factory InventoryPerms.fromJson(dynamic json) {
    final j = _m(json);
    return InventoryPerms(
      view: _b(j['view']),
      add: _b(j['add']),
      update: _b(j['update']),
      activate: _b(j['activate']),
      deactivate: _b(j['deactivate']),
    );
  }
}

class SectionsPerms {
  final bool integration, rotation, marketing, reshuffle, automation, trash;
  final InventoryPerms inventory;
  const SectionsPerms({
    this.integration = false,
    this.rotation = false,
    this.marketing = false,
    this.reshuffle = false,
    this.automation = false,
    this.trash = false,
    this.inventory = const InventoryPerms(),
  });

  factory SectionsPerms.fromJson(dynamic json) {
    final j = _m(json);
    return SectionsPerms(
      integration: _b(j['integration']),
      rotation: _b(j['rotation']),
      marketing: _b(j['marketing']),
      reshuffle: _b(j['reshuffle']),
      automation: _b(j['automation']),
      trash: _b(j['trash']),
      inventory: InventoryPerms.fromJson(j['inventory']),
    );
  }
}

class CrmPermissions {
  final bool aiChat, editLead, maskPhone, exportData, copyData, isAdmin;
  final String duplicatePhone; // "warn" | غيرها حسب الباك
  final HiddenList aiModels,
      aiLeadInfo,
      filters,
      columns,
      dashboardStages,
      filterStages;
  final NotificationPerms notifications;
  final SectionsPerms sections;

  const CrmPermissions({
    this.aiChat = false,
    this.editLead = false,
    this.maskPhone = false,
    this.exportData = false,
    this.copyData = false,
    this.isAdmin = false,
    this.duplicatePhone = 'warn',
    this.aiModels = const HiddenList(),
    this.aiLeadInfo = const HiddenList(),
    this.filters = const HiddenList(),
    this.columns = const HiddenList(),
    this.dashboardStages = const HiddenList(),
    this.filterStages = const HiddenList(),
    this.notifications = const NotificationPerms(),
    this.sections = const SectionsPerms(),
  });

  factory CrmPermissions.fromJson(dynamic json) {
    final j = _m(json);
    return CrmPermissions(
      aiChat: _b(j['aiChat']),
      editLead: _b(j['editLead']),
      maskPhone: _b(j['maskPhone']),
      exportData: _b(j['exportData']),
      copyData: _b(j['copyData']),
      isAdmin: _b(j['isAdmin']),
      duplicatePhone: _s(j['duplicatePhone'], 'warn'),
      aiModels: HiddenList.fromJson(j['aiModels']),
      aiLeadInfo: HiddenList.fromJson(j['aiLeadInfo']),
      filters: HiddenList.fromJson(j['filters']),
      columns: HiddenList.fromJson(j['columns']),
      dashboardStages: HiddenList.fromJson(j['dashboardStages']),
      filterStages: HiddenList.fromJson(j['filterStages']),
      notifications: NotificationPerms.fromJson(j['notifications']),
      sections: SectionsPerms.fromJson(j['sections']),
    );
  }
}

class CrmStage {
  final String id;
  final String name;
  final bool deal; // مرحلة صفقة
  final bool isFinal; // "final" كلمة محجوزة في Dart فسميناه isFinal

  const CrmStage({
    required this.id,
    required this.name,
    required this.deal,
    required this.isFinal,
  });

  factory CrmStage.fromJson(Map<String, dynamic> j) => CrmStage(
        id: _s(j['id']),
        name: _s(j['name']),
        deal: _b(j['deal']),
        isFinal: _b(j['final']),
      );
}

class CrmSettings {
  final String timezone;
  final String role;
  final CrmPermissions permissions;
  final List<CrmStage> stages;

  const CrmSettings({
    this.timezone = 'UTC',
    this.role = '',
    this.permissions = const CrmPermissions(),
    this.stages = const [],
  });

  /// بياخد الـ response كامل (فيه status + data)
  factory CrmSettings.fromResponse(dynamic body) {
    final data = _m(_m(body)['data']);
    final rawStages = data['stages'];
    return CrmSettings(
      timezone: _s(data['timezone'], 'UTC'),
      role: _s(data['role']),
      permissions: CrmPermissions.fromJson(data['permissions']),
      stages: rawStages is List
          ? rawStages.map((e) => CrmStage.fromJson(_m(e))).toList()
          : const [],
    );
  }
}

// ─────────────────────────────────────────────
//  Service
//  لو عندك Dio client جاهز (بيحط الـ token بـ interceptor) مرّره في الـ constructor
//  وشيل سطر الـ Authorization اليدوي.
// ─────────────────────────────────────────────
class CrmSettingsService {
  final Dio? _client;
  CrmSettingsService([this._client]);

  Future<CrmSettings> fetchMe() async {
    final dio = _client ??
        Dio(BaseOptions(
          baseUrl: ApiConfig.api, // getter → بيتقري مع كل request
          connectTimeout: ApiConfig.connectTimeout,
          receiveTimeout: ApiConfig.receiveTimeout,
        ));

    // الـ token من SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(ApiConfig.tokenKey);

    final res = await dio.get(
      Endpoints.crmSettingsMe,
      options: Options(headers: {
        if (_client == null && token != null) 'Authorization': 'Bearer $token',
      }),
    );
    return CrmSettings.fromResponse(res.data);
  }
}

// ─────────────────────────────────────────────
//  Provider (ChangeNotifier)
// ─────────────────────────────────────────────
class CrmSettingsProvider extends ChangeNotifier {
  final CrmSettingsService _service;
  CrmSettingsProvider([CrmSettingsService? service])
      : _service = service ?? CrmSettingsService();

  CrmSettings _settings = const CrmSettings();
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  CrmSettings get settings => _settings;
  CrmPermissions get perms => _settings.permissions;
  SectionsPerms get sections => _settings.permissions.sections;
  List<CrmStage> get stages => _settings.stages;
  bool get isLoading => _loading;
  bool get isLoaded => _loaded;
  String? get error => _error;

  /// نادِ عليها بعد اللوجين وعند فتح الأبلكيشن (لو في token)
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _settings = await _service.fetchMe();
      _loaded = true;
    } on DioException catch (e) {
      _error = e.response?.data is Map
          ? _s((e.response!.data as Map)['message'], 'Request failed')
          : (e.message ?? 'Network error');
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  /// نادِ عليها في logout عشان صلاحيات يوزر قديم ما تفضلش
  void clear() {
    _settings = const CrmSettings();
    _loaded = false;
    _error = null;
    notifyListeners();
  }

  // ── Shortcuts جاهزة للاستخدام في الـ UI ──
  bool get isAdmin => perms.isAdmin;
  bool get canEditLead => perms.editLead;
  bool get canExport => perms.exportData;
  bool get canCopy => perms.copyData;
  bool get maskPhone => perms.maskPhone;
  bool get canUseAiChat => perms.aiChat;

  bool filterAllowed(String key) => perms.filters.allows(key);
  bool columnAllowed(String key) => perms.columns.allows(key);
  bool dashboardStageAllowed(String stageId) =>
      perms.dashboardStages.allows(stageId);
  bool filterStageAllowed(String stageId) => perms.filterStages.allows(stageId);

  /// المراحل المسموح تظهر في الفلتر
  List<CrmStage> get visibleFilterStages =>
      stages.where((s) => filterStageAllowed(s.id)).toList();
}