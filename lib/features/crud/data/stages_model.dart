// stage_model.dart
// حطه في features/crud/data/ جنب stage_type_model.dart

// ignore_for_file: prefer_null_aware_operators

import 'package:flutter/painting.dart';

String? _s(dynamic v) => v == null ? null : v.toString();
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse('$v');

/// "#4C6FFF" → Color
Color hexToColor(String? hex, [Color fallback = const Color(0xFF95A5A6)]) {
  if (hex == null) return fallback;
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return (h.length == 8 && v != null) ? Color(v) : fallback;
}

/// الـ stage type المتضمن جوه الـ stage (id + name + isActive)
class StageTypeRef {
  final String? id;
  final String name;
  final bool active;
  const StageTypeRef({this.id, this.name = '', this.active = true});

  factory StageTypeRef.fromJson(Map<String, dynamic> j) => StageTypeRef(
        id: _s(j['_id'] ?? j['id']),
        name: _s(j['name']) ?? '',
        active: j['isActive'] != false,
      );
}

class StageModel {
  final String? id;
  final String name;
  final StageTypeRef? stageType;
  final String? note; // null لو فاضي
  final String color; // hex
  final String lateColor; // hex
  final bool active;
  final String? addedByName;
  final DateTime? createdAt, updatedAt;

  const StageModel({
    this.id,
    this.name = '',
    this.stageType,
    this.note,
    this.color = '#95A5A6',
    this.lateColor = '#95A5A6',
    this.active = true,
    this.addedByName,
    this.createdAt,
    this.updatedAt,
  });

  factory StageModel.fromJson(Map<String, dynamic> j) {
    final added = j['addedBy'] is Map ? j['addedBy'] as Map : const {};
    final by = '${added['firstName'] ?? ''} ${added['lastName'] ?? ''}'.trim();
    final note = _s(j['note'])?.trim();
    final st = j['stageType'];
    return StageModel(
      id: _s(j['_id'] ?? j['id']),
      name: _s(j['name']) ?? '',
      // ممكن ييجي object أو id بس
      stageType: st is Map
          ? StageTypeRef.fromJson(Map<String, dynamic>.from(st))
          : (st != null ? StageTypeRef(id: st.toString()) : null),
      note: (note == null || note.isEmpty) ? null : note,
      color: _s(j['color']) ?? '#95A5A6',
      lateColor: _s(j['lateColor']) ?? '#95A5A6',
      active: j['isActive'] != false,
      addedByName: by.isEmpty ? null : by,
      createdAt: _dt(j['createdAt']),
      updatedAt: _dt(j['updatedAt']),
    );
  }

  String get displayName => name.trim().isEmpty ? 'Unnamed' : name;
  Color get colorValue => hexToColor(color);
  Color get lateColorValue => hexToColor(lateColor);
}

class StagesPagination {
  final int totalItems, totalActive, totalInactive;
  const StagesPagination({
    this.totalItems = 0,
    this.totalActive = 0,
    this.totalInactive = 0,
  });

  factory StagesPagination.fromJson(Map<String, dynamic> j) => StagesPagination(
        totalItems: _i(j['totalItems']),
        totalActive: _i(j['totalLeadsActive']),
        totalInactive: _i(j['totalLeadsInactive']),
      );
}

class StagesResponse {
  final List<StageModel> data;
  final StagesPagination? pagination;
  const StagesResponse({this.data = const [], this.pagination});

  factory StagesResponse.fromJson(Map<String, dynamic> j) {
    final p = j['paginationResult'] ?? j['pagination'];
    return StagesResponse(
      data: (j['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => StageModel.fromJson(Map<String, dynamic>.from(e)))
          .where((t) => t.id != null && t.id!.isNotEmpty)
          .toList(),
      pagination: p is Map
          ? StagesPagination.fromJson(Map<String, dynamic>.from(p))
          : null,
    );
  }
}