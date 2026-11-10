// lib/features/admin/data/admin_dashboard_model.dart
// Models for GET /dashboard/stages
import 'package:flutter/material.dart';

/// "2026-10-21" — the format the API expects for createdFrom / createdTo
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

// Parses "#RRGGBB" into a Color (falls back if null / invalid)
Color _hex(String? hex, Color fallback) {
  if (hex == null) return fallback;
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

/// عنصر في قايمة اختيار السيلز (id + اسم)
class SalesOpt {
  final String id;
  final String name;
  const SalesOpt(this.id, this.name);
}

/// بيانات السيلز اللي الرد اتفلتر بيه (scope=sales)
class SalesInfo {
  final String id;
  final String name;
  final String role;
  const SalesInfo({required this.id, required this.name, required this.role});

  factory SalesInfo.fromJson(Map<String, dynamic> j) => SalesInfo(
    id: '${j['id'] ?? ''}',
    name: '${j['name'] ?? ''}',
    role: '${j['role'] ?? ''}',
  );
}

/// نصيب السيلز من كل الـ leads: { sales: 2, all: 111, percent: 1.8 }
class ShareStat {
  final int sales;
  final int all;
  final double percent;
  const ShareStat({
    required this.sales,
    required this.all,
    required this.percent,
  });

  factory ShareStat.fromJson(Map<String, dynamic> j) => ShareStat(
    sales: _i(j['sales']),
    all: _i(j['all']),
    percent: _d(j['percent']),
  );
}

class StageTypeRef {
  final String id;
  final String name;
  const StageTypeRef({required this.id, required this.name});

  factory StageTypeRef.fromJson(Map<String, dynamic> j) =>
      StageTypeRef(id: '${j['id'] ?? ''}', name: '${j['name'] ?? ''}');
}

class StageStat {
  final String? id; // null for the virtual "No stage" bucket
  final String name;
  final Color color;
  final Color lateColor;
  final bool isActive;
  final bool isVirtual;
  final StageTypeRef? stageType;
  final int count;
  final double percent; // 0..100
  final int late;
  final double latePercent; // 0..100 (late / count)

  const StageStat({
    required this.id,
    required this.name,
    required this.color,
    required this.lateColor,
    required this.isActive,
    required this.isVirtual,
    required this.stageType,
    required this.count,
    required this.percent,
    required this.late,
    required this.latePercent,
  });

  factory StageStat.fromJson(Map<String, dynamic> j) => StageStat(
    id: j['id'] as String?,
    name: '${j['name'] ?? ''}',
    color: _hex(j['color'] as String?, const Color(0xFF8B95A1)),
    lateColor: _hex(j['lateColor'] as String?, const Color(0xFFF2545B)),
    isActive: j['isActive'] as bool? ?? true,
    isVirtual: j['virtual'] as bool? ?? false,
    stageType: j['stageType'] is Map
        ? StageTypeRef.fromJson(Map<String, dynamic>.from(j['stageType']))
        : null,
    count: _i(j['count']),
    percent: _d(j['percent']),
    late: _i(j['late']),
    latePercent: _d(j['latePercent']),
  );
}

class FreshStat {
  final int count;
  final double percent;
  const FreshStat({required this.count, required this.percent});

  factory FreshStat.fromJson(Map<String, dynamic> j) =>
      FreshStat(count: _i(j['count']), percent: _d(j['percent']));
}

class DashboardStages {
  final String scope; // full | sales
  final DateTime? generatedAt;
  final String? createdFrom;
  final String? createdTo;
  final int total;
  final int lateTotal;

  /// null لما scope=sales (الـ API بيرجّعها null)
  final FreshStat? fresh;

  /// موجود بس لما scope=sales
  final SalesInfo? sales;
  final ShareStat? share;

  final List<StageStat> stages;

  const DashboardStages({
    required this.scope,
    required this.generatedAt,
    required this.createdFrom,
    required this.createdTo,
    required this.total,
    required this.lateTotal,
    required this.fresh,
    required this.stages,
    this.sales,
    this.share,
  });

  factory DashboardStages.fromJson(Map<String, dynamic> j) {
    final range = j['range'] is Map ? j['range'] as Map : const {};
    return DashboardStages(
      scope: '${j['scope'] ?? 'full'}',
      generatedAt: DateTime.tryParse('${j['generatedAt']}')?.toLocal(),
      createdFrom: range['createdFrom'] as String?,
      createdTo: range['createdTo'] as String?,
      total: _i(j['total']),
      lateTotal: _i(j['lateTotal']),
      fresh: j['fresh'] is Map
          ? FreshStat.fromJson(Map<String, dynamic>.from(j['fresh']))
          : null,
      sales: j['sales'] is Map
          ? SalesInfo.fromJson(Map<String, dynamic>.from(j['sales']))
          : null,
      share: j['share'] is Map
          ? ShareStat.fromJson(Map<String, dynamic>.from(j['share']))
          : null,
      stages: ((j['stages'] as List?) ?? const [])
          .map((e) => StageStat.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

// ───────── GET /dashboard/follow-ups ─────────
String _fullName(Map? u) =>
    '${u?['firstName'] ?? ''} ${u?['lastName'] ?? ''}'.trim();

class StaleStats {
  final int noComment;
  final int untouched;
  final int unassignedOld;
  const StaleStats({
    required this.noComment,
    required this.untouched,
    required this.unassignedOld,
  });

  factory StaleStats.fromJson(Map<String, dynamic> j) => StaleStats(
    noComment: _i(j['noComment']),
    untouched: _i(j['untouched']),
    unassignedOld: _i(j['unassignedOld']),
  );
}

class OverdueLead {
  final String id;
  final String name;
  final DateTime? dueAt;
  final String stageName;
  final Color stageColor;
  final List<String> salesNames;
  const OverdueLead({
    required this.id,
    required this.name,
    required this.dueAt,
    required this.stageName,
    required this.stageColor,
    required this.salesNames,
  });

  factory OverdueLead.fromJson(Map<String, dynamic> j) {
    final stage = j['stage'] is Map ? j['stage'] as Map : const {};
    return OverdueLead(
      id: '${j['id'] ?? ''}',
      name: '${j['name'] ?? ''}',
      dueAt: DateTime.tryParse('${j['dueAt']}')?.toLocal(),
      stageName: '${stage['name'] ?? ''}',
      stageColor: _hex(stage['color'] as String?, const Color(0xFF8B95A1)),
      salesNames: ((j['sales'] as List?) ?? const [])
          .whereType<Map>()
          .map(_fullName)
          .where((n) => n.isNotEmpty)
          .toList(),
    );
  }
}

class LateBySales {
  final String id;
  final String name;
  final int late;
  final DateTime? oldest;
  const LateBySales({
    required this.id,
    required this.name,
    required this.late,
    required this.oldest,
  });

  factory LateBySales.fromJson(Map<String, dynamic> j) => LateBySales(
    id: '${j['id'] ?? ''}',
    name: _fullName(j['user'] as Map?),
    late: _i(j['late']),
    oldest: DateTime.tryParse('${j['oldest']}')?.toLocal(),
  );
}

/// bucket واحد من الـ follow-ups: العدد + حدود الوقت (ISO) للفلترة
class FollowBucket {
  final int count;
  final String? from; // null في overdue
  final String? to;
  const FollowBucket({required this.count, this.from, this.to});

  factory FollowBucket.fromJson(dynamic j) {
    final m = j is Map ? j : const {};
    return FollowBucket(
      count: _i(m['count']),
      from: m['from'] as String?,
      to: m['to'] as String?,
    );
  }
}

class DashboardFollowUps {
  final String scope;
  final FollowBucket overdue, today, tomorrow, week; // 👈 كانت int
  final StaleStats stale;
  final List<OverdueLead> mostOverdue;
  final List<LateBySales> lateBySales;

  const DashboardFollowUps({
    required this.scope,
    required this.overdue,
    required this.today,
    required this.tomorrow,
    required this.week,
    required this.stale,
    required this.mostOverdue,
    required this.lateBySales,
  });

  factory DashboardFollowUps.fromJson(Map<String, dynamic> j) {
    final f = j['followUps'] is Map ? j['followUps'] as Map : const {};

    List<T> list<T>(String key, T Function(Map<String, dynamic>) fn) =>
        ((j[key] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => fn(Map<String, dynamic>.from(e)))
            .toList();

    return DashboardFollowUps(
      scope: '${j['scope'] ?? 'full'}',
      overdue: FollowBucket.fromJson(f['overdue']),
      today: FollowBucket.fromJson(f['today']),
      tomorrow: FollowBucket.fromJson(f['tomorrow']),
      week: FollowBucket.fromJson(f['week']),
      stale: StaleStats.fromJson(
        j['stale'] is Map
            ? Map<String, dynamic>.from(j['stale'])
            : <String, dynamic>{},
      ),
      mostOverdue: list('mostOverdue', OverdueLead.fromJson),
      lateBySales: list('lateBySales', LateBySales.fromJson),
    );
  }
}
