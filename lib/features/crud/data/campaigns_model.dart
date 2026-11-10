// campaigns_model.dart
// حطه في نفس فولدر projects_model.dart (features/crud/data/)

// ignore_for_file: prefer_null_aware_operators

String? _s(dynamic v) => v == null ? null : v.toString();
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
double? _d(dynamic v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse('$v');

/// مشروع جوه الحملة: {project: {_id, name}, cost, startDate, endDate, _id}
class CampaignProject {
  final String? id; // id الصف نفسه
  final String? projectId;
  final String projectName;
  final double? cost;
  final DateTime? startDate, endDate;

  const CampaignProject({
    this.id,
    this.projectId,
    this.projectName = '',
    this.cost,
    this.startDate,
    this.endDate,
  });

  factory CampaignProject.fromJson(Map<String, dynamic> j) {
    // الـ project ممكن يكون object (populated) أو id لوحده
    final p = j['project'];
    return CampaignProject(
      id: _s(j['_id'] ?? j['id']),
      projectId: p is Map ? _s(p['_id'] ?? p['id']) : _s(p),
      projectName: p is Map ? (_s(p['name']) ?? '') : '',
      cost: _d(j['cost']),
      startDate: _dt(j['startDate']),
      endDate: _dt(j['endDate']),
    );
  }
}

class CampaignModel {
  final String? id;
  final String name;
  final DateTime? startDate;
  final double? cost;
  final String? notes; // null لو فاضي
  final List<CampaignProject> projects;
  final bool active;
  final String? addedByName; // null لو مفيش
  final DateTime? createdAt, updatedAt;

  const CampaignModel({
    this.id,
    this.name = '',
    this.startDate,
    this.cost,
    this.notes,
    this.projects = const [],
    this.active = true,
    this.addedByName,
    this.createdAt,
    this.updatedAt,
  });

  factory CampaignModel.fromJson(Map<String, dynamic> j) {
    final added = j['addedBy'] is Map ? j['addedBy'] as Map : const {};
    final by = '${added['firstName'] ?? ''} ${added['lastName'] ?? ''}'.trim();
    final notes = _s(j['notes'])?.trim();
    return CampaignModel(
      id: _s(j['_id'] ?? j['id']),
      name: _s(j['name']) ?? '',
      startDate: _dt(j['startDate']),
      cost: _d(j['cost']),
      notes: (notes == null || notes.isEmpty) ? null : notes,
      projects: (j['projects'] as List? ?? [])
          .whereType<Map>()
          .map((e) => CampaignProject.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      active: j['isActive'] != false,
      addedByName: by.isEmpty ? null : by,
      createdAt: _dt(j['createdAt']),
      updatedAt: _dt(j['updatedAt']),
    );
  }

  String get displayName => name.trim().isEmpty ? 'Unnamed' : name;

  /// أسماء المشاريع المختلفة (من غير تكرار) — الحملة ممكن تحط نفس المشروع أكتر من مرة
  List<String> get projectNames => projects
      .map((p) => p.projectName)
      .where((n) => n.isNotEmpty)
      .toSet()
      .toList();
}

class CampaignsPagination {
  final int totalItems, totalActive, totalInactive;
  const CampaignsPagination({
    this.totalItems = 0,
    this.totalActive = 0,
    this.totalInactive = 0,
  });

  factory CampaignsPagination.fromJson(Map<String, dynamic> j) =>
      CampaignsPagination(
        totalItems: _i(j['totalItems']),
        totalActive: _i(j['totalLeadsActive']),
        totalInactive: _i(j['totalLeadsInactive']),
      );
}

class CampaignsResponse {
  final List<CampaignModel> data;
  final CampaignsPagination? pagination;
  const CampaignsResponse({this.data = const [], this.pagination});

  factory CampaignsResponse.fromJson(Map<String, dynamic> j) {
    final p = j['paginationResult'] ?? j['pagination'];
    return CampaignsResponse(
      data: (j['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => CampaignModel.fromJson(Map<String, dynamic>.from(e)))
          .where((c) => c.id != null && c.id!.isNotEmpty)
          .toList(),
      pagination: p is Map
          ? CampaignsPagination.fromJson(Map<String, dynamic>.from(p))
          : null,
    );
  }
}
