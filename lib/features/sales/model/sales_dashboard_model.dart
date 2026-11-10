// lib/features/sales/model/sales_dashboard_model.dart
// Models للـ 3 endpoints: stages / follow-ups / deals (نسخة السيلز)

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/widgets/dashboard_widget.dart'; // BarPoint

// ─────────────────────────────────────────────
//  Parsing helpers (آمنة ضد null / int-double)
// ─────────────────────────────────────────────
double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

/// "#E67E22" -> Color
Color _hex(dynamic h, [Color fallback = const Color(0xFF95A5A6)]) {
  final s = (h?.toString() ?? '').replaceAll('#', '');
  if (s.isEmpty) return fallback;
  final v = int.tryParse(s.length == 6 ? 'FF$s' : s, radix: 16);
  return v == null ? fallback : Color(v);
}

// ─────────────────────────────────────────────
//  Stages
// ─────────────────────────────────────────────
class StageItem {
  final String id, name;
  final Color color, lateColor;
  final int count, late;
  final double percent;
  StageItem.fromJson(Map<String, dynamic> j)
      : id = '${j['id']}',
        name = '${j['name'] ?? ''}',
        color = _hex(j['color']),
        lateColor = _hex(j['lateColor'], const Color(0xFFF2545B)),
        count = _i(j['count']),
        late = _i(j['late']),
        percent = _d(j['percent']);
}

class StagesData {
  final int total, lateTotal;
  final int shareSales, shareAll;
  final double sharePercent;
  final List<StageItem> stages;
  StagesData.fromJson(Map<String, dynamic> j)
      : total = _i(j['total']),
        lateTotal = _i(j['lateTotal']),
        sharePercent = _d(j['share']?['percent']),
        shareSales = _i(j['share']?['sales']),
        shareAll = _i(j['share']?['all']),
        stages = [
          for (final s in (j['stages'] as List? ?? []))
            StageItem.fromJson(Map<String, dynamic>.from(s as Map))
        ];
}

// ─────────────────────────────────────────────
//  Follow-ups
// ─────────────────────────────────────────────
/// bucket واحد: العدد + حدود الوقت (جاية من الـ API عشان فلتر الـ leads)
class FollowBucket {
  final int count;
  final String? from, to;
  FollowBucket.fromJson(dynamic j)
      : count = _i(j is Map ? j['count'] : 0),
        from = j is Map ? j['from']?.toString() : null,
        to = j is Map ? j['to']?.toString() : null;
}

class OverdueLead {
  final String name, stageName;
  final List<String> salesNames;
  final DateTime? dueAt;
  final Color stageColor;

  OverdueLead._(
    this.name,
    this.stageName,
    this.salesNames,
    this.dueAt,
    this.stageColor,
  );

  // القايمة فاضية في الرد اللي عندنا، فالمفاتيح هنا defensive
  // عدّلها لما تشوف عنصر حقيقي
  factory OverdueLead.fromJson(Map<String, dynamic> j) {
    final st = j['stage'];
    final stMap = st is Map ? st : null;
    final sales = j['salesNames'] ?? j['sales'];
    return OverdueLead._(
      '${j['name'] ?? j['leadName'] ?? ''}',
      '${j['stageName'] ?? stMap?['name'] ?? (st is String ? st : '')}',
      [
        if (sales is List)
          for (final s in sales) s is Map ? '${s['name'] ?? ''}' : '$s'
      ],
      DateTime.tryParse('${j['dueAt'] ?? j['nextFollowUp'] ?? ''}')?.toLocal(),
      _hex(j['stageColor'] ?? stMap?['color']),
    );
  }
}

class FollowUpsData {
  final FollowBucket overdue, today, tomorrow, week;
  final int noComment, untouched;
  final int? unassignedOld; // null = مش متاح للسيلز
  final List<OverdueLead> mostOverdue;

  FollowUpsData.fromJson(Map<String, dynamic> j)
      : overdue = FollowBucket.fromJson(j['followUps']?['overdue']),
        today = FollowBucket.fromJson(j['followUps']?['today']),
        tomorrow = FollowBucket.fromJson(j['followUps']?['tomorrow']),
        week = FollowBucket.fromJson(j['followUps']?['week']),
        noComment = _i(j['stale']?['noComment']),
        untouched = _i(j['stale']?['untouched']),
        unassignedOld = j['stale']?['unassignedOld'] == null
            ? null
            : _i(j['stale']['unassignedOld']),
        mostOverdue = [
          for (final m in (j['mostOverdue'] as List? ?? []))
            if (m is Map) OverdueLead.fromJson(Map<String, dynamic>.from(m))
        ];
}

// ─────────────────────────────────────────────
//  Deals
// ─────────────────────────────────────────────
class DealsData {
  final int deals, clients;
  final double value, commission, cashback, net;
  final List<int> years;
  final List<BarPoint> timeline;

  DealsData.fromJson(Map<String, dynamic> j)
      : deals = _i(j['totals']?['deals']),
        clients = _i(j['totals']?['clients']),
        value = _d(j['totals']?['value']),
        commission = _d(j['totals']?['commission']),
        cashback = _d(j['totals']?['cashback']),
        net = _d(j['totals']?['net']),
        years = [for (final y in (j['years'] as List? ?? [])) _i(y)],
        timeline = [
          for (final t in (j['timeline'] as List? ?? []))
            BarPoint('${t['label']}', _d(t['value']), _i(t['deals']))
        ];
}