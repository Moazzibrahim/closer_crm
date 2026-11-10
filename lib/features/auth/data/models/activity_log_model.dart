// يحوّل الـ JSON بتاع اللوج لموديل + نص مقروء لكل action
class ActivityLog {
  final String id;
  final String userId;
  final String userName;
  final String userRole;
  final String
  action; // create | update | delete | assign | change_stage | deactivate ...
  final String module; // Lead | LeadComment | User | Integration ...
  final String resourceId;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
  final DateTime createdAt;

  ActivityLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.action,
    required this.module,
    required this.resourceId,
    this.before,
    this.after,
    required this.createdAt,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> j) {
    final u = (j['user'] is Map) ? j['user'] as Map : const {};
    return ActivityLog(
      id: '${j['_id'] ?? ''}',
      userId: '${u['_id'] ?? ''}',
      userName: '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim(),
      userRole: '${u['role'] ?? ''}',
      action: '${j['action'] ?? ''}',
      module: '${j['module'] ?? ''}',
      resourceId: '${j['resourceId'] ?? ''}',
      before: j['before'] is Map
          ? Map<String, dynamic>.from(j['before'])
          : null,
      after: j['after'] is Map ? Map<String, dynamic>.from(j['after']) : null,
      // التوقيت جاي UTC → نحوله للتوقيت المحلي
      createdAt:
          DateTime.tryParse('${j['createdAt']}')?.toLocal() ?? DateTime.now(),
    );
  }

  // التاريخ والوقت بنظام 12 ساعة (AM/PM)
  String get timeText {
    final d = createdAt;
    // 0 → 12 AM ، 12 → 12 PM ، 13 → 1 PM ...
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final period = d.hour >= 12 ? 'PM' : 'AM';
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year}  $h12:$min $period';
  }

  // اسم الـ lead لو موجود (من before أو after)
  String? get _leadName => (after?['name'] ?? before?['name'])?.toString();

  // نص مقروء لكل نوع عملية
  String get summary {
    String stage(Map<String, dynamic>? m) =>
        (m?['currentStage'] is Map) ? '${m!['currentStage']['name']}' : '—';

    switch (action) {
      case 'create':
        if (module == 'LeadComment') {
          return 'Added a comment: "${after?['text'] ?? ''}"';
        }
        return 'Created $module${_leadName != null ? ' "$_leadName"' : ''}';
      case 'change_stage':
        return 'Changed stage: ${stage(before)} → ${stage(after)}';
      case 'assign':
        final s = after?['sales'];
        final to = (s is List && s.isNotEmpty && s.first['user'] is Map)
            ? s.first['user']['fullName']
            : null;
        return 'Assigned lead${to != null ? ' to $to' : ''}';
      case 'delete':
        return 'Deleted $module${_leadName != null ? ' "$_leadName"' : ''}';
      case 'deactivate':
        return 'Deactivated $module';
      case 'activate':
        return 'Activated $module';
      case 'update':
        if (module == 'Lead' && before?['name'] != after?['name']) {
          return 'Renamed lead: "${before?['name']}" → "${after?['name']}"';
        }
        return 'Updated $module${_leadName != null ? ' "$_leadName"' : ''}';
      default:
        return '$action $module';
    }
  }
}
