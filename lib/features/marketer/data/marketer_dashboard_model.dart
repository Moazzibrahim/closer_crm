// lib/features/marketer/model/marketing_dashboard_model.dart
// موديل داشبورد المسوّق: بيحوّل رد /dashboard/marketing لـ objects.
// كل الـ parsing متسامح (null-safe) عشان أي field ناقص ما يوقعش الشاشة.

import 'package:flutter/material.dart';

int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
String _s(dynamic v) => v == null ? '' : '$v';

/// '#EC4899' → Color
Color _hex(dynamic v, [Color fallback = const Color(0xFF8B95A1)]) {
  final s = _s(v).replaceAll('#', '');
  if (s.length != 6) return fallback;
  final n = int.tryParse(s, radix: 16);
  return n == null ? fallback : Color(0xFF000000 | n);
}

class MktChannel {
  final String id, name;
  const MktChannel(this.id, this.name);
  factory MktChannel.fromJson(Map<String, dynamic> j) =>
      MktChannel(_s(j['id']), _s(j['name']));
}

class MktDeals {
  final int count, clients;
  final double value;
  const MktDeals(this.count, this.clients, this.value);
  factory MktDeals.fromJson(Map<String, dynamic>? j) =>
      MktDeals(_i(j?['count']), _i(j?['clients']), _d(j?['value']));
}

class MktTotals {
  final int leads, assigned, contacted, closed, late, fresh, unassigned;
  final int prevLeads, resubmissions;
  final double conversion, change;
  final MktDeals deals;
  const MktTotals({
    required this.leads,
    required this.assigned,
    required this.contacted,
    required this.closed,
    required this.late,
    required this.fresh,
    required this.unassigned,
    required this.prevLeads,
    required this.resubmissions,
    required this.conversion,
    required this.change,
    required this.deals,
  });
  factory MktTotals.fromJson(Map<String, dynamic>? j) => MktTotals(
    leads: _i(j?['leads']),
    assigned: _i(j?['assigned']),
    contacted: _i(j?['contacted']),
    closed: _i(j?['closed']),
    late: _i(j?['late']),
    fresh: _i(j?['fresh']),
    unassigned: _i(j?['unassigned']),
    prevLeads: _i(j?['prevLeads']),
    resubmissions: _i(j?['resubmissions']),
    conversion: _d(j?['conversion']),
    change: _d(j?['change']),
    deals: MktDeals.fromJson(j?['deals'] as Map<String, dynamic>?),
  );
}

class MktDay {
  final DateTime date;
  final int leads, closed;
  const MktDay(this.date, this.leads, this.closed);
  factory MktDay.fromJson(Map<String, dynamic> j) => MktDay(
    DateTime.tryParse(_s(j['date'])) ?? DateTime.now(),
    _i(j['leads']),
    _i(j['closed']),
  );
}

/// صف في تقسيمة (Source / Campaign / Project)
class MktBreakdown {
  final String id, name;
  final int leads, assigned, contacted, closed;
  final double conversion;
  const MktBreakdown({
    required this.id,
    required this.name,
    required this.leads,
    required this.assigned,
    required this.contacted,
    required this.closed,
    required this.conversion,
  });
  factory MktBreakdown.fromJson(Map<String, dynamic> j) => MktBreakdown(
    id: _s(j['id']),
    name: _s(j['name']),
    leads: _i(j['leads']),
    assigned: _i(j['assigned']),
    contacted: _i(j['contacted']),
    closed: _i(j['closed']),
    conversion: _d(j['conversion']),
  );
}

class MktStage {
  final String id, name;
  final Color color;
  final int count;
  final double percent;
  const MktStage(this.id, this.name, this.color, this.count, this.percent);
  factory MktStage.fromJson(Map<String, dynamic> j) => MktStage(
    _s(j['id']),
    _s(j['name']),
    _hex(j['color']),
    _i(j['count']),
    _d(j['percent']),
  );
}

class MktRecentLead {
  final String id, name, source, campaign, project;
  final DateTime? at;
  final String? stageName;
  final Color stageColor;
  final bool assigned;
  const MktRecentLead({
    required this.id,
    required this.name,
    required this.source,
    required this.campaign,
    required this.project,
    required this.at,
    required this.stageName,
    required this.stageColor,
    required this.assigned,
  });
  factory MktRecentLead.fromJson(Map<String, dynamic> j) {
    final st = j['stage'] as Map<String, dynamic>?; // ممكن تكون null
    return MktRecentLead(
      id: _s(j['id']),
      name: _s(j['name']),
      source: _s(j['source']),
      campaign: _s(j['campaign']),
      project: _s(j['project']),
      at: DateTime.tryParse(_s(j['at']))?.toLocal(),
      stageName: st == null ? null : _s(st['name']),
      stageColor: _hex(st?['color']),
      assigned: j['assigned'] == true,
    );
  }
}

class MarketingData {
  final bool noChannels;
  final List<MktChannel> channels;
  final MktTotals totals;
  final List<MktDay> timeline;
  final List<MktBreakdown> bySource, byCampaign, byProject;
  final List<MktStage> byStage;
  final List<MktRecentLead> recent;

  const MarketingData({
    required this.noChannels,
    required this.channels,
    required this.totals,
    required this.timeline,
    required this.bySource,
    required this.byCampaign,
    required this.byProject,
    required this.byStage,
    required this.recent,
  });

  static List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
      v is List ? v.whereType<Map<String, dynamic>>().map(f).toList() : [];

  /// بياخد الـ `data` object (مش الـ wrapper بتاع status)
  factory MarketingData.fromJson(Map<String, dynamic> j) => MarketingData(
    noChannels: j['noChannels'] == true,
    channels: _list(j['channels'], MktChannel.fromJson),
    totals: MktTotals.fromJson(j['totals'] as Map<String, dynamic>?),
    timeline: _list(j['timeline'], MktDay.fromJson),
    bySource: _list(j['bySource'], MktBreakdown.fromJson),
    byCampaign: _list(j['byCampaign'], MktBreakdown.fromJson),
    byProject: _list(j['byProject'], MktBreakdown.fromJson),
    byStage: _list(j['byStage'], MktStage.fromJson),
    recent: _list(j['recent'], MktRecentLead.fromJson),
  );
}
