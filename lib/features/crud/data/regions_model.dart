// regions_model.dart
// حطه في نفس فولدر projects_model.dart (features/crud/data/)

// ignore_for_file: prefer_null_aware_operators

String? _s(dynamic v) => v == null ? null : v.toString();
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse('$v');

class RegionModel {
  final String? id;
  final String name;
  final bool active;
  final String? addedByName; // null لو مفيش
  final DateTime? createdAt, updatedAt;

  const RegionModel({
    this.id,
    this.name = '',
    this.active = true,
    this.addedByName,
    this.createdAt,
    this.updatedAt,
  });

  factory RegionModel.fromJson(Map<String, dynamic> j) {
    final added = j['addedBy'] is Map ? j['addedBy'] as Map : const {};
    final by = '${added['firstName'] ?? ''} ${added['lastName'] ?? ''}'.trim();
    return RegionModel(
      id: _s(j['_id'] ?? j['id']),
      name: _s(j['name']) ?? '',
      active: j['isActive'] != false,
      addedByName: by.isEmpty ? null : by,
      createdAt: _dt(j['createdAt']),
      updatedAt: _dt(j['updatedAt']),
    );
  }

  String get displayName => name.trim().isEmpty ? 'Unnamed' : name;
}

class RegionsPagination {
  final int totalItems, totalActive, totalInactive;
  const RegionsPagination({
    this.totalItems = 0,
    this.totalActive = 0,
    this.totalInactive = 0,
  });

  factory RegionsPagination.fromJson(Map<String, dynamic> j) =>
      RegionsPagination(
        totalItems: _i(j['totalItems']),
        totalActive: _i(j['totalLeadsActive']),
        totalInactive: _i(j['totalLeadsInactive']),
      );
}

class RegionsResponse {
  final List<RegionModel> data;
  final RegionsPagination? pagination;
  const RegionsResponse({this.data = const [], this.pagination});

  factory RegionsResponse.fromJson(Map<String, dynamic> j) {
    final p = j['paginationResult'] ?? j['pagination'];
    return RegionsResponse(
      data: (j['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => RegionModel.fromJson(Map<String, dynamic>.from(e)))
          .where((r) => r.id != null && r.id!.isNotEmpty)
          .toList(),
      pagination: p is Map
          ? RegionsPagination.fromJson(Map<String, dynamic>.from(p))
          : null,
    );
  }
}
