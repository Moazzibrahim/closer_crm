// stage_types_model.dart
// حطه في نفس فولدر projects_model.dart (features/crud/data/)

// ignore_for_file: prefer_null_aware_operators

String? _s(dynamic v) => v == null ? null : v.toString();
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse('$v');

/// اختيار جوه الـ stage type (زي "Broker" جوه "Reason")
class StageOption {
  final String? id;
  final String label;
  final bool active;
  final DateTime? createdAt, updatedAt;

  const StageOption({
    this.id,
    this.label = '',
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  factory StageOption.fromJson(Map<String, dynamic> j) => StageOption(
        id: _s(j['_id'] ?? j['id']),
        label: _s(j['label']) ?? '',
        active: j['isActive'] != false,
        createdAt: _dt(j['createdAt']),
        updatedAt: _dt(j['updatedAt']),
      );
}

class StageTypeModel {
  final String? id;
  final String name;
  final String? note; // null لو فاضي
  final bool active;
  final List<StageOption> options;
  final String? addedByName; // null لو مفيش
  final DateTime? createdAt, updatedAt;

  const StageTypeModel({
    this.id,
    this.name = '',
    this.note,
    this.active = true,
    this.options = const [],
    this.addedByName,
    this.createdAt,
    this.updatedAt,
  });

  factory StageTypeModel.fromJson(Map<String, dynamic> j) {
    final added = j['addedBy'] is Map ? j['addedBy'] as Map : const {};
    final by = '${added['firstName'] ?? ''} ${added['lastName'] ?? ''}'.trim();
    final note = _s(j['note'])?.trim();
    return StageTypeModel(
      id: _s(j['_id'] ?? j['id']),
      name: _s(j['name']) ?? '',
      note: (note == null || note.isEmpty) ? null : note,
      active: j['isActive'] != false,
      options: (j['options'] as List? ?? [])
          .whereType<Map>()
          .map((e) => StageOption.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      addedByName: by.isEmpty ? null : by,
      createdAt: _dt(j['createdAt']),
      updatedAt: _dt(j['updatedAt']),
    );
  }

  String get displayName => name.trim().isEmpty ? 'Unnamed' : name;

  /// الـ options الـ active بس
  List<StageOption> get activeOptions =>
      options.where((o) => o.active).toList();
}

class StageTypesPagination {
  final int totalItems, totalActive, totalInactive;
  const StageTypesPagination({
    this.totalItems = 0,
    this.totalActive = 0,
    this.totalInactive = 0,
  });

  factory StageTypesPagination.fromJson(Map<String, dynamic> j) =>
      StageTypesPagination(
        totalItems: _i(j['totalItems']),
        totalActive: _i(j['totalLeadsActive']),
        totalInactive: _i(j['totalLeadsInactive']),
      );
}

class StageTypesResponse {
  final List<StageTypeModel> data;
  final StageTypesPagination? pagination;
  const StageTypesResponse({this.data = const [], this.pagination});

  factory StageTypesResponse.fromJson(Map<String, dynamic> j) {
    final p = j['paginationResult'] ?? j['pagination'];
    return StageTypesResponse(
      data: (j['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => StageTypeModel.fromJson(Map<String, dynamic>.from(e)))
          .where((t) => t.id != null && t.id!.isNotEmpty)
          .toList(),
      pagination: p is Map
          ? StageTypesPagination.fromJson(Map<String, dynamic>.from(p))
          : null,
    );
  }
}