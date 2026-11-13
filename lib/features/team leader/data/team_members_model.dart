// lib/features/sales/model/team_dashboard_model.dart
int _n(dynamic v) => (v as num?)?.toInt() ?? 0;

class TeamMember {
  final String id, name, email, role;
  final bool isActive, isMe;
  final int leads, late, today, noStage, assignedToday;
  final DateTime? lastActivity;
  final String? teamLeaderId; // 👈 id التيم ليدر بتاع العضو

  const TeamMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    required this.isMe,
    required this.leads,
    required this.late,
    required this.today,
    required this.noStage,
    required this.assignedToday,
    this.lastActivity,
    this.teamLeaderId,
  });

  factory TeamMember.fromJson(Map<String, dynamic> j) {
    final tl = j['teamLeader']; // { id, name } أو null
    return TeamMember(
      id: '${j['id']}',
      name: '${j['name'] ?? ''}',
      email: '${j['email'] ?? ''}',
      role: '${j['role'] ?? ''}',
      isActive: j['isActive'] != false,
      isMe: j['isMe'] == true,
      leads: _n(j['leads']),
      late: _n(j['late']),
      today: _n(j['today']),
      noStage: _n(j['noStage']),
      assignedToday: _n(j['assignedToday']),
      lastActivity: DateTime.tryParse('${j['lastActivity'] ?? ''}'),
      teamLeaderId: tl is Map ? tl['id']?.toString() : null,
    );
  }
}

class TeamData {
  final int members, leads, late, today, noStage, assignedToday;
  final List<TeamMember> all;

  const TeamData({
    required this.members,
    required this.leads,
    required this.late,
    required this.today,
    required this.noStage,
    required this.assignedToday,
    required this.all,
  });

  factory TeamData.fromJson(Map<String, dynamic> j) {
    final t = Map<String, dynamic>.from((j['totals'] as Map?) ?? const {});
    return TeamData(
      members: _n(t['members']),
      leads: _n(t['leads']),
      late: _n(t['late']),
      today: _n(t['today']),
      noStage: _n(t['noStage']),
      assignedToday: _n(t['assignedToday']),
      all: (j['members'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => TeamMember.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  /// صف التيم ليدر نفسه (بالـ id بتاع اللي عامل لوجين)
  TeamMember? me(String uid) {
    for (final m in all) {
      if (m.id == uid) return m;
    }
    for (final m in all) {
      if (m.isMe) return m;
    }
    return null;
  }

  /// سيلز التيم ليدر ده بس (teamLeader.id == uid)
  List<TeamMember> others(String uid) =>
      all.where((m) => m.id != uid && m.teamLeaderId == uid).toList();
}
