// property_types_model.dart
// حطه في نفس فولدر projects_model.dart (features/crud/data/)

String? _s(dynamic v) => v == null ? null : v.toString();
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse('$v');

class PropertyTypeModel {
  final String? id;
  final String name;
  final bool active;
  final String? addedByName; // null لو مفيش
  final DateTime? createdAt, updatedAt;

  const PropertyTypeModel({
    this.id,
    this.name = '',
    this.active = true,
    this.addedByName,
    this.createdAt,
    this.updatedAt,
  });

  factory PropertyTypeModel.fromJson(Map<String, dynamic> j) {
    final added = j['addedBy'] is Map ? j['addedBy'] as Map : const {};
    final by = '${added['firstName'] ?? ''} ${added['lastName'] ?? ''}'.trim();
    return PropertyTypeModel(
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

// الـ API هنا بيرجّع totalItems بس (من غير active/inactive counts)
// فالـ Active/Inactive بيتحسبوا في الشاشة من الليست
class PropertyTypesPagination {
  final int totalItems;
  const PropertyTypesPagination({this.totalItems = 0});

  factory PropertyTypesPagination.fromJson(Map<String, dynamic> j) =>
      PropertyTypesPagination(totalItems: _i(j['totalItems']));
}

class PropertyTypesResponse {
  final List<PropertyTypeModel> data;
  final PropertyTypesPagination? pagination;
  const PropertyTypesResponse({this.data = const [], this.pagination});

  factory PropertyTypesResponse.fromJson(Map<String, dynamic> j) {
    final p = j['paginationResult'] ?? j['pagination'];
    return PropertyTypesResponse(
      data: (j['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => PropertyTypeModel.fromJson(Map<String, dynamic>.from(e)))
          .where((t) => t.id != null && t.id!.isNotEmpty)
          .toList(),
      pagination: p is Map
          ? PropertyTypesPagination.fromJson(Map<String, dynamic>.from(p))
          : null,
    );
  }
}