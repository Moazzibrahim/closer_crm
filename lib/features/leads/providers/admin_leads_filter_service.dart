import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/features/crud/providers/crud_service.dart';
import 'package:flutter_application_1/features/leads/data/lead_model.dart';

/// عنصر في قوائم الاختيار (id + اسم)
class Opt {
  final String id, name;
  const Opt(this.id, this.name);
}

class LeadsFilters {
  String keyword;
  String? phone; // بحث جزئي في التليفون (phone=50)
  bool? isActive;
  String? leadType;
  List<String> stages,
      oldStages,
      projects,
      propertyTypes,
      developers,
      sales,
      assignedFrom,
      assignedBy,
      countryCodes,
      campaigns,
      channel,
      communicationWay,
      cities,
      regions,
      areas,
      fields;
  bool unassigned, hasClosedDeals, transferred, toDistribute, linkedDeals;
  num? budgetMin, budgetMax;
  String? createdFrom, createdTo;
  String? assignDateFrom, assignDateTo;
  String? activityFrom, activityTo;
  String sort; // ممكن يبقى أكتر من واحد: "-createdAt,name"
  bool lateFollowUp;
  String? followUpFrom, followUpTo;
  String? stale; // noComment | untouched | unassignedOld

  LeadsFilters({
    this.keyword = '',
    this.phone,
    this.isActive = true,
    this.leadType,
    List<String>? stages,
    List<String>? oldStages,
    List<String>? projects,
    List<String>? propertyTypes,
    List<String>? developers,
    List<String>? sales,
    List<String>? assignedFrom,
    List<String>? assignedBy,
    List<String>? countryCodes,
    List<String>? campaigns,
    List<String>? channel,
    List<String>? communicationWay,
    List<String>? cities,
    List<String>? regions,
    List<String>? areas,
    List<String>? fields,
    this.unassigned = false,
    this.hasClosedDeals = false,
    this.transferred = false,
    this.toDistribute = false,
    this.linkedDeals = false,
    this.budgetMin,
    this.budgetMax,
    this.createdFrom,
    this.createdTo,
    this.assignDateFrom,
    this.assignDateTo,
    this.activityFrom,
    this.activityTo,
    this.sort = '-createdAt',
    this.lateFollowUp = false,
    this.followUpFrom,
    this.followUpTo,
    this.stale,
  }) : stages = stages ?? [],
       oldStages = oldStages ?? [],
       projects = projects ?? [],
       propertyTypes = propertyTypes ?? [],
       developers = developers ?? [],
       sales = sales ?? [],
       assignedFrom = assignedFrom ?? [],
       assignedBy = assignedBy ?? [],
       countryCodes = countryCodes ?? [],
       campaigns = campaigns ?? [],
       channel = channel ?? [],
       communicationWay = communicationWay ?? [],
       cities = cities ?? [],
       regions = regions ?? [],
       areas = areas ?? [],
       fields = fields ?? [];

  LeadsFilters copy() => LeadsFilters(
    keyword: keyword,
    phone: phone,
    isActive: isActive,
    leadType: leadType,
    stages: [...stages],
    oldStages: [...oldStages],
    projects: [...projects],
    propertyTypes: [...propertyTypes],
    developers: [...developers],
    sales: [...sales],
    assignedFrom: [...assignedFrom],
    assignedBy: [...assignedBy],
    countryCodes: [...countryCodes],
    campaigns: [...campaigns],
    channel: [...channel],
    communicationWay: [...communicationWay],
    cities: [...cities],
    regions: [...regions],
    areas: [...areas],
    fields: [...fields],
    unassigned: unassigned,
    hasClosedDeals: hasClosedDeals,
    transferred: transferred,
    toDistribute: toDistribute,
    linkedDeals: linkedDeals,
    budgetMin: budgetMin,
    budgetMax: budgetMax,
    createdFrom: createdFrom,
    createdTo: createdTo,
    assignDateFrom: assignDateFrom,
    assignDateTo: assignDateTo,
    activityFrom: activityFrom,
    activityTo: activityTo,
    sort: sort,
    lateFollowUp: lateFollowUp,
    followUpFrom: followUpFrom,
    followUpTo: followUpTo,
    stale: stale,
  );

  void clearFollowUp() {
    lateFollowUp = false;
    followUpFrom = followUpTo = stale = null;
  }

  bool get hasFollowUp => lateFollowUp || followUpFrom != null || stale != null;

  /// الفلاتر "المتقدمة" بس (keyword / isActive / stages من برا الشيت)
  void copyAdvancedFrom(LeadsFilters o) {
    phone = o.phone;
    leadType = o.leadType;
    oldStages = o.oldStages;
    projects = o.projects;
    propertyTypes = o.propertyTypes;
    developers = o.developers;
    sales = o.sales;
    assignedFrom = o.assignedFrom;
    assignedBy = o.assignedBy;
    countryCodes = o.countryCodes;
    campaigns = o.campaigns;
    channel = o.channel;
    communicationWay = o.communicationWay;
    cities = o.cities;
    regions = o.regions;
    areas = o.areas;
    unassigned = o.unassigned;
    hasClosedDeals = o.hasClosedDeals;
    transferred = o.transferred;
    toDistribute = o.toDistribute;
    linkedDeals = o.linkedDeals;
    budgetMin = o.budgetMin;
    budgetMax = o.budgetMax;
    createdFrom = o.createdFrom;
    createdTo = o.createdTo;
    assignDateFrom = o.assignDateFrom;
    assignDateTo = o.assignDateTo;
    activityFrom = o.activityFrom;
    activityTo = o.activityTo;
    followUpFrom = o.followUpFrom;
    followUpTo = o.followUpTo;
    stale = o.stale;
    sort = o.sort;
  }

  int get advancedCount =>
      (phone != null && phone!.isNotEmpty ? 1 : 0) +
      (leadType != null ? 1 : 0) +
      (oldStages.isNotEmpty ? 1 : 0) +
      (projects.isNotEmpty ? 1 : 0) +
      (propertyTypes.isNotEmpty ? 1 : 0) +
      (developers.isNotEmpty ? 1 : 0) +
      (sales.isNotEmpty ? 1 : 0) +
      (assignedFrom.isNotEmpty ? 1 : 0) +
      (assignedBy.isNotEmpty ? 1 : 0) +
      (countryCodes.isNotEmpty ? 1 : 0) +
      (campaigns.isNotEmpty ? 1 : 0) +
      (channel.isNotEmpty ? 1 : 0) +
      (communicationWay.isNotEmpty ? 1 : 0) +
      (cities.isNotEmpty ? 1 : 0) +
      (regions.isNotEmpty ? 1 : 0) +
      (areas.isNotEmpty ? 1 : 0) +
      (unassigned ? 1 : 0) +
      (hasClosedDeals ? 1 : 0) +
      (transferred ? 1 : 0) +
      (toDistribute ? 1 : 0) +
      (linkedDeals ? 1 : 0) +
      (budgetMin != null || budgetMax != null ? 1 : 0) +
      (createdFrom != null || createdTo != null ? 1 : 0) +
      (assignDateFrom != null || assignDateTo != null ? 1 : 0) +
      (activityFrom != null || activityTo != null ? 1 : 0) +
      (followUpFrom != null || followUpTo != null ? 1 : 0) +
      (stale != null ? 1 : 0) +
      (sort != '-createdAt' ? 1 : 0);

  Map<String, String> toQuery({
    required bool myLeads,
    required int page,
    required int limit,
  }) {
    final q = <String, String>{};

    var kw = keyword.trim();
    final looksLikePhone =
        RegExp(r'^[+\d\s\-()]+$').hasMatch(kw) &&
        kw.replaceAll(RegExp(r'\D'), '').length >= 3;
    if (looksLikePhone) kw = kw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (kw.isNotEmpty) q['keyword'] = kw;

    void list(String key, List<String> v) {
      if (v.isNotEmpty) q[key] = v.join(',');
    }

    void put(String key, String? v) {
      if (v != null && v.isNotEmpty) q[key] = v;
    }

    // ── أساسي ──
    if (isActive != null) q['isActive'] = '$isActive';
    put('leadType', leadType);
    final ph = phone?.replaceAll(RegExp(r'[\s\-()+]'), '');
    put('phone', ph);
    // الـ API عايز 971 من غير +
    list(
      'countryCode',
      countryCodes.map((c) => c.replaceFirst('+', '')).toList(),
    );

    // ── stage ──
    list('stage', stages);
    list('oldStage', oldStages);

    // ── source ──
    list('projects', projects);
    list('propertyTypes', propertyTypes);
    list('developer', developers);
    list('campaigns', campaigns);
    list('channel', channel);
    list('communicationWay', communicationWay);

    // ── location ──
    list('cities', cities);
    list('regions', regions);
    list('areas', areas);

    // ── assignment (مش في my-leads) ──
    if (!myLeads) {
      list('sales', sales);
      list('assignedFrom', assignedFrom);
      list('assignedBy', assignedBy);
      if (unassigned) q['unassigned'] = 'true';
      if (toDistribute) q['toDistribute'] = 'true';
      put('assignDateFrom', assignDateFrom);
      put('assignDateTo', assignDateTo);
    }

    // ── budget ──
    if (budgetMin != null) q['budgetMin'] = '$budgetMin';
    if (budgetMax != null) q['budgetMax'] = '$budgetMax';

    // ── dates ──
    put('createdFrom', createdFrom);
    put('createdTo', createdTo);
    put('activityFrom', activityFrom);
    put('activityTo', activityTo);

    // ── flags ──
    if (hasClosedDeals) q['hasClosedDeals'] = 'true';
    if (transferred) q['transferred'] = 'true';
    if (linkedDeals) q['linkedDeals'] = 'true';

    // ── follow-up / stale ──
    if (lateFollowUp) q['lateFollowUp'] = 'true';
    put('followUpFrom', followUpFrom);
    put('followUpTo', followUpTo);
    put('stale', stale);

    list('fields', fields);
    q['page'] = '$page';
    q['limit'] = '$limit';
    q['sort'] = sort;
    return q;
  }
}

class LeadsController extends ChangeNotifier {
  /// myLeads=true → /Leads/my-leads  |  preset = فلاتر ثابتة للصفحة
  LeadsController({
    this.myLeads = false,
    LeadsFilters? preset,
    this.pageSize = 10,
  }) : filters = preset?.copy() ?? LeadsFilters();

  final bool myLeads;
  final int pageSize;

  LeadsFilters filters;
  final List<LeadItem> items = [];

  int _page = 1;
  int _req = 0; // عشان نتجاهل ردود قديمة (لما المستخدم يكتب بسرعة)
  bool hasMore = true, loading = false, loadingMore = false;
  String? error;

  int totalAll = 0, totalActive = 0, totalInactive = 0, totalItems = 0;

  Future<void> refresh() => _fetch(reset: true);

  Future<void> loadMore() {
    if (loading || loadingMore || !hasMore) return Future.value();
    return _fetch(reset: false);
  }

  /// عدّل الفلاتر وبعدين اعمل fetch
  Future<void> apply(void Function(LeadsFilters f) change) {
    change(filters);
    return refresh();
  }

  Future<void> _fetch({required bool reset}) async {
    final id = ++_req;
    final page = reset ? 1 : _page + 1;

    if (reset) {
      loading = true;
      error = null;
    } else {
      loadingMore = true;
    }
    notifyListeners();

    try {
      // ✅ التغيير المهم: بنبني الـ query من الفلاتر ونبعتها مباشرة
      final query = filters.toQuery(
        myLeads: myLeads,
        page: page,
        limit: pageSize,
      );
      if (kDebugMode) debugPrint('GET leads → $query'); // للتأكد من الـ URL

      final path = myLeads ? '${Endpoints.leads}/my-leads' : Endpoints.leads;
      final res = await CrudService(path).getAll(params: query);
      if (id != _req) return; // جه رد أحدث

      final list = (res['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => LeadItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final p = (res['pagination'] as Map?) ?? {};

      if (reset) items.clear();
      items.addAll(list);
      _page = page;
      hasMore = p['next'] != null;
      totalAll = (p['totalAllLeads'] ?? p['totalItems'] ?? 0) as int;
      totalActive = (p['totalLeadsActive'] ?? 0) as int;
      totalInactive = (p['totalLeadsInactive'] ?? 0) as int;
      totalItems = (p['totalItems'] ?? 0) as int;
      error = null;
    } catch (e) {
      if (id != _req) return;
      error = e.toString();
    }
    loading = false;
    loadingMore = false;
    notifyListeners();
  }
}
