// areas_model.dart
// حطه في نفس فولدر projects_model.dart و regions_model.dart (features/crud/data/)

import 'regions_model.dart'; // بنستخدم RegionModel نفسه كـ region بتاع المنطقة

String? _s(dynamic v) => v == null ? null : v.toString();
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse('$v');

class AreaModel {
  final String? id;
  final String name;
  final RegionModel? region;
  final String? location; // وصف/عنوان نصي
  final bool active;
  final String? addedByName; // null لو مفيش
  final DateTime? createdAt, updatedAt;

  const AreaModel({
    this.id,
    this.name = '',
    this.region,
    this.location,
    this.active = true,
    this.addedByName,
    this.createdAt,
    this.updatedAt,
  });

  factory AreaModel.fromJson(Map<String, dynamic> j) {
    final added = j['addedBy'] is Map ? j['addedBy'] as Map : const {};
    final by = '${added['firstName'] ?? ''} ${added['lastName'] ?? ''}'.trim();
    final loc = _s(j['location'])?.trim();

    // الـ region ممكن ييجي object (populated) أو id لوحده
    final r = j['region'];
    final region = r is Map
        ? RegionModel.fromJson(Map<String, dynamic>.from(r))
        : (r is String ? RegionModel(id: r) : null);

    return AreaModel(
      id: _s(j['_id'] ?? j['id']),
      name: _s(j['name']) ?? '',
      region: region,
      location: (loc == null || loc.isEmpty) ? null : loc,
      active: j['isActive'] != false,
      addedByName: by.isEmpty ? null : by,
      createdAt: _dt(j['createdAt']),
      updatedAt: _dt(j['updatedAt']),
    );
  }

  String get displayName => name.trim().isEmpty ? 'Unnamed' : name;
  String get regionName => region?.name ?? '';
}

class AreasPagination {
  final int totalItems, totalActive, totalInactive;
  const AreasPagination({
    this.totalItems = 0,
    this.totalActive = 0,
    this.totalInactive = 0,
  });

  factory AreasPagination.fromJson(Map<String, dynamic> j) => AreasPagination(
        totalItems: _i(j['totalItems']),
        totalActive: _i(j['totalLeadsActive']),
        totalInactive: _i(j['totalLeadsInactive']),
      );
}

class AreasResponse {
  final List<AreaModel> data;
  final AreasPagination? pagination;
  const AreasResponse({this.data = const [], this.pagination});

  factory AreasResponse.fromJson(Map<String, dynamic> j) {
    final p = j['paginationResult'] ?? j['pagination'];
    return AreasResponse(
      data: (j['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => AreaModel.fromJson(Map<String, dynamic>.from(e)))
          .where((a) => a.id != null && a.id!.isNotEmpty)
          .toList(),
      pagination: p is Map
          ? AreasPagination.fromJson(Map<String, dynamic>.from(p))
          : null,
    );
  }
}