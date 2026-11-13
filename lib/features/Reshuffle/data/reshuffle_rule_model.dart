// reshuffle_rule_model.dart
// موديلات الـ Stage Reshuffle Rules. الـ fromJson بيقبل الحقل populated (Map) أو id بس.
import 'package:flutter/material.dart';

String _s(dynamic v) => v == null ? '' : '$v';
int _i(dynamic v, [int d = 0]) =>
    v is num ? v.toInt() : (int.tryParse(_s(v)) ?? d);
String _id(dynamic v) => v is Map ? _s(v['_id'] ?? v['id']) : _s(v);
List<String> _ids(dynamic v) => (v as List? ?? const [])
    .map(_id)
    .where((e) => e.isNotEmpty)
    .toList();

Color _hex(dynamic v) {
  final h = _s(v).replaceAll('#', '');
  final n = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return Color(n ?? 0xFF9CA3AF);
}

/// مرجع خفيف (stage أو يوزر): id + اسم + لون (للـ stages)
class RsRef {
  final String id, name;
  final Color color;
  const RsRef(this.id, this.name, [this.color = const Color(0xFF9CA3AF)]);

  factory RsRef.fromJson(dynamic v) {
    if (v is! Map) return RsRef(_s(v), '');
    final full = '${_s(v['firstName'])} ${_s(v['lastName'])}'.trim();
    return RsRef(
      _id(v),
      full.isNotEmpty ? full : _s(v['name'] ?? v['email']),
      _hex(v['color']),
    );
  }
}

/// خطوة: stage + بعد قد إيه يتحرك + أقل عدد دخلات للـ stage
class RsStep {
  RsRef? stage;
  int delayValue, minEntries;
  String delayUnit; // hours | days

  RsStep({
    this.stage,
    this.delayValue = 24,
    this.delayUnit = 'hours',
    this.minEntries = 1,
  });

  factory RsStep.fromJson(Map j) => RsStep(
    stage: j['stage'] == null ? null : RsRef.fromJson(j['stage']),
    delayValue: _i(j['delayValue'], 24),
    delayUnit: _s(j['delayUnit']).isEmpty ? 'hours' : _s(j['delayUnit']),
    minEntries: _i(j['minEntries'], 1),
  );

  Map<String, dynamic> toJson() => {
    'stage': stage?.id,
    'delayValue': delayValue,
    'delayUnit': delayUnit,
    'minEntries': minEntries,
  };

  String get label =>
      '${stage?.name ?? '—'} · $delayValue${delayUnit == 'days' ? 'd' : 'h'}';
}

class RsWorkingHours {
  bool enabled;
  String start, end; // "HH:mm"
  List<int> days;
  int utcOffsetMinutes;

  RsWorkingHours({
    this.enabled = false,
    this.start = '09:00',
    this.end = '18:00',
    List<int>? days,
    int? utcOffsetMinutes,
  }) : days = days ?? [0, 1, 2, 3, 4],
       // الافتراضي: الـ offset بتاع الموبايل (دبي = 240)
       utcOffsetMinutes =
           utcOffsetMinutes ?? DateTime.now().timeZoneOffset.inMinutes;

  factory RsWorkingHours.fromJson(dynamic v) {
    if (v is! Map) return RsWorkingHours();
    return RsWorkingHours(
      enabled: v['enabled'] == true,
      start: _s(v['start']).isEmpty ? '09:00' : _s(v['start']),
      end: _s(v['end']).isEmpty ? '18:00' : _s(v['end']),
      days: (v['days'] as List? ?? const []).map((e) => _i(e)).toList(),
      utcOffsetMinutes: v['utcOffsetMinutes'] == null
          ? null
          : _i(v['utcOffsetMinutes']),
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'start': start,
    'end': end,
    'days': days,
    'utcOffsetMinutes': utcOffsetMinutes,
  };

  String get summary => enabled ? '$start–$end' : 'Any time';
}

class RsRule {
  String id, name, description;
  bool isActive;
  int priority;
  List<RsStep> stages;

  // filters
  List<String> projects, channels, campaigns, leadTypes;
  bool excludeWithClosedDeals;

  // pool
  List<RsRef> poolUsers;
  String poolMode; // round_robin | least_loaded
  int maxLeadsPerSales; // 0 = من غير حد

  RsWorkingHours workingHours;

  String activityPolicy; // restart | ignore
  bool respectFollowUp;
  int maxReshuffles;
  String onExhausted; // user | unassign | keep
  RsRef? exhaustedUser;

  // after
  RsRef? moveToStage;
  bool resetCreationDate, clearHistory;

  RsRule({
    this.id = '',
    this.name = '',
    this.description = '',
    this.isActive = false,
    this.priority = 100,
    List<RsStep>? stages,
    List<String>? projects,
    List<String>? channels,
    List<String>? campaigns,
    List<String>? leadTypes,
    this.excludeWithClosedDeals = true,
    List<RsRef>? poolUsers,
    this.poolMode = 'round_robin',
    this.maxLeadsPerSales = 0,
    RsWorkingHours? workingHours,
    this.activityPolicy = 'restart',
    this.respectFollowUp = true,
    this.maxReshuffles = 3,
    this.onExhausted = 'keep',
    this.exhaustedUser,
    this.moveToStage,
    this.resetCreationDate = true,
    this.clearHistory = false,
  }) : stages = stages ?? [],
       projects = projects ?? [],
       channels = channels ?? [],
       campaigns = campaigns ?? [],
       leadTypes = leadTypes ?? ['Fresh', 'Cold'],
       poolUsers = poolUsers ?? [],
       workingHours = workingHours ?? RsWorkingHours();

  factory RsRule.fromJson(Map<String, dynamic> j) {
    final f = (j['filters'] as Map?) ?? const {};
    final p = (j['pool'] as Map?) ?? const {};
    final a = (j['after'] as Map?) ?? const {};
    return RsRule(
      id: _id(j),
      name: _s(j['name']),
      description: _s(j['description']),
      isActive: j['isActive'] == true,
      priority: _i(j['priority'], 100),
      stages: (j['stages'] as List? ?? const [])
          .whereType<Map>()
          .map(RsStep.fromJson)
          .toList(),
      projects: _ids(f['projects']),
      channels: _ids(f['channels']),
      campaigns: _ids(f['campaigns']),
      leadTypes: (f['leadTypes'] as List? ?? const [])
          .map((e) => '$e')
          .toList(),
      excludeWithClosedDeals: j['excludeWithClosedDeals'] != false,
      poolUsers: (p['users'] as List? ?? const [])
          .map(RsRef.fromJson)
          .toList(),
      poolMode: _s(p['mode']).isEmpty ? 'round_robin' : _s(p['mode']),
      maxLeadsPerSales: _i(p['maxLeadsPerSales']),
      workingHours: RsWorkingHours.fromJson(j['workingHours']),
      activityPolicy: _s(j['activityPolicy']).isEmpty
          ? 'restart'
          : _s(j['activityPolicy']),
      respectFollowUp: j['respectFollowUp'] != false,
      maxReshuffles: _i(j['maxReshuffles'], 3),
      onExhausted: _s(j['onExhausted']).isEmpty ? 'keep' : _s(j['onExhausted']),
      exhaustedUser: j['exhaustedUser'] == null
          ? null
          : RsRef.fromJson(j['exhaustedUser']),
      moveToStage: a['moveToStage'] == null
          ? null
          : RsRef.fromJson(a['moveToStage']),
      resetCreationDate: a['resetCreationDate'] != false,
      clearHistory: a['clearHistory'] == true,
    );
  }

  /// body الـ POST / PATCH (ids بس). isActive مش بيتبعت (الـ API بيستخدم /toggle)
  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'description': description.trim().isEmpty ? null : description.trim(),
    'priority': priority,
    'stages': stages.map((s) => s.toJson()).toList(),
    'filters': {
      'projects': projects,
      'channels': channels,
      'campaigns': campaigns,
      'leadTypes': leadTypes,
    },
    'excludeWithClosedDeals': excludeWithClosedDeals,
    'pool': {
      'users': poolUsers.map((u) => u.id).toList(),
      'mode': poolMode,
      'maxLeadsPerSales': maxLeadsPerSales,
    },
    'workingHours': workingHours.toJson(),
    'activityPolicy': activityPolicy,
    'respectFollowUp': respectFollowUp,
    'maxReshuffles': maxReshuffles,
    'onExhausted': onExhausted,
    'exhaustedUser': onExhausted == 'user' ? exhaustedUser?.id : null,
    'after': {
      'moveToStage': moveToStage?.id,
      'resetCreationDate': resetCreationDate,
      'clearHistory': clearHistory,
    },
  };

  String get poolSummary {
    final mode = poolMode == 'least_loaded' ? 'Least loaded' : 'Round robin';
    return '${poolUsers.length} sales · $mode';
  }
}
