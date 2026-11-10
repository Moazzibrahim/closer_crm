// communication_way_model.dart
// حطه في features/crud/data/ جنب stage_model.dart

// ignore_for_file: prefer_null_aware_operators

String? _s(dynamic v) => v == null ? null : v.toString();
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse('$v');

class CommunicationWayModel {
  final String? id;
  final String name;
  final String? notes; // null لو فاضي
  final String? icon; // اسم أيقونة (MessageCircle) أو emoji أو null
  final String color; // hex
  final String? category; // Digital / In-person ...
  final bool active;
  final String? addedByName;
  final DateTime? createdAt, updatedAt;

  const CommunicationWayModel({
    this.id,
    this.name = '',
    this.notes,
    this.icon,
    this.color = '#95A5A6',
    this.category,
    this.active = true,
    this.addedByName,
    this.createdAt,
    this.updatedAt,
  });

  factory CommunicationWayModel.fromJson(Map<String, dynamic> j) {
    final added = j['addedBy'] is Map ? j['addedBy'] as Map : const {};
    final by = '${added['firstName'] ?? ''} ${added['lastName'] ?? ''}'.trim();
    final notes = _s(j['notes'])?.trim();
    final icon = _s(j['icon'])?.trim();
    final cat = _s(j['category'])?.trim();
    return CommunicationWayModel(
      id: _s(j['_id'] ?? j['id']),
      name: _s(j['name']) ?? '',
      notes: (notes == null || notes.isEmpty) ? null : notes,
      icon: (icon == null || icon.isEmpty) ? null : icon,
      color: _s(j['color']) ?? '#95A5A6',
      category: (cat == null || cat.isEmpty) ? null : cat,
      active: j['isActive'] != false,
      addedByName: by.isEmpty ? null : by,
      createdAt: _dt(j['createdAt']),
      updatedAt: _dt(j['updatedAt']),
    );
  }

  String get displayName => name.trim().isEmpty ? 'Unnamed' : name;
}

class CommunicationWaysPagination {
  final int totalItems, totalActive, totalInactive;
  const CommunicationWaysPagination({
    this.totalItems = 0,
    this.totalActive = 0,
    this.totalInactive = 0,
  });

  factory CommunicationWaysPagination.fromJson(Map<String, dynamic> j) =>
      CommunicationWaysPagination(
        totalItems: _i(j['totalItems']),
        totalActive: _i(j['totalLeadsActive']),
        totalInactive: _i(j['totalLeadsInactive']),
      );
}

class CommunicationWaysResponse {
  final List<CommunicationWayModel> data;
  final CommunicationWaysPagination? pagination;
  const CommunicationWaysResponse({this.data = const [], this.pagination});

  factory CommunicationWaysResponse.fromJson(Map<String, dynamic> j) {
    final p = j['paginationResult'] ?? j['pagination'];
    return CommunicationWaysResponse(
      data: (j['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => CommunicationWayModel.fromJson(Map<String, dynamic>.from(e)))
          .where((t) => t.id != null && t.id!.isNotEmpty)
          .toList(),
      pagination: p is Map
          ? CommunicationWaysPagination.fromJson(Map<String, dynamic>.from(p))
          : null,
    );
  }
}