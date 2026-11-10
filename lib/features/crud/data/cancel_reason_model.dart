// cancel_reasons_model.dart
// حطه في نفس فولدر projects_model.dart (features/crud/data/)

String? _s(dynamic v) => v == null ? null : v.toString();
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse('$v');

class CancelReasonModel {
  final String? id;
  final String name;
  final String? category; // null لو فاضي (مثلاً: Price)
  final bool active;
  final String? addedByName; // null لو مفيش
  final DateTime? createdAt, updatedAt;

  const CancelReasonModel({
    this.id,
    this.name = '',
    this.category,
    this.active = true,
    this.addedByName,
    this.createdAt,
    this.updatedAt,
  });

  factory CancelReasonModel.fromJson(Map<String, dynamic> j) {
    final added = j['addedBy'] is Map ? j['addedBy'] as Map : const {};
    final by = '${added['firstName'] ?? ''} ${added['lastName'] ?? ''}'.trim();
    final cat = _s(j['category'])?.trim();
    return CancelReasonModel(
      id: _s(j['_id'] ?? j['id']),
      name: _s(j['name']) ?? '',
      category: (cat == null || cat.isEmpty) ? null : cat,
      active: j['isActive'] != false,
      addedByName: by.isEmpty ? null : by,
      createdAt: _dt(j['createdAt']),
      updatedAt: _dt(j['updatedAt']),
    );
  }

  String get displayName => name.trim().isEmpty ? 'Unnamed' : name;
}

class CancelReasonsPagination {
  final int totalItems, totalActive, totalInactive;
  const CancelReasonsPagination({
    this.totalItems = 0,
    this.totalActive = 0,
    this.totalInactive = 0,
  });

  factory CancelReasonsPagination.fromJson(Map<String, dynamic> j) =>
      CancelReasonsPagination(
        totalItems: _i(j['totalItems']),
        totalActive: _i(j['totalLeadsActive']),
        totalInactive: _i(j['totalLeadsInactive']),
      );
}

class CancelReasonsResponse {
  final List<CancelReasonModel> data;
  final CancelReasonsPagination? pagination;
  const CancelReasonsResponse({this.data = const [], this.pagination});

  factory CancelReasonsResponse.fromJson(Map<String, dynamic> j) {
    final p = j['paginationResult'] ?? j['pagination'];
    return CancelReasonsResponse(
      data: (j['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => CancelReasonModel.fromJson(Map<String, dynamic>.from(e)))
          .where((r) => r.id != null && r.id!.isNotEmpty)
          .toList(),
      pagination: p is Map
          ? CancelReasonsPagination.fromJson(Map<String, dynamic>.from(p))
          : null,
    );
  }
}
