class ChannelRef {
  final String? id;
  final String? name;
  final String? code;
  final bool? isActive;

  const ChannelRef({this.id, this.name, this.code, this.isActive});

  factory ChannelRef.fromJson(Map<String, dynamic> j) => ChannelRef(
    id: j['_id']?.toString(),
    name: j['name']?.toString(),
    code: j['code']?.toString(),
    isActive: j['isActive'] as bool?,
  );
}

class UserModel {
  final String? id;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? avatar;
  final String? role;
  final bool? isActive;
  final int? aiDailyLimit;
  final List<ChannelRef>? channels;
  final String? addedByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? teamLeaderId; // 👈

  const UserModel({
    this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.avatar,
    this.role,
    this.isActive,
    this.aiDailyLimit,
    this.channels,
    this.addedByName,
    this.createdAt,
    this.updatedAt,
    this.teamLeaderId, // 👈
  });

  // ───── Safe getters للـ UI ─────
  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();
  String get initial =>
      (firstName?.isNotEmpty ?? false) ? firstName![0].toUpperCase() : '?';
  bool get active => isActive != false; // null = نعتبره active
  List<ChannelRef> get channelList => channels ?? const [];
  String get channelIds =>
      channelList.map((c) => c.id ?? '').where((e) => e.isNotEmpty).join(', ');
  String get channelNames => channelList
      .map((c) => c.name ?? '')
      .where((e) => e.isNotEmpty)
      .join(', ');

  factory UserModel.fromJson(Map<String, dynamic> j) {
    final added = j['addedBy'];
    final tl = j['teamLeader'] ?? j['leader']; // ⚠️ عدّل الاسم حسب رد الباك
    return UserModel(
      id: (j['_id'] ?? j['id'])?.toString(),
      firstName: j['firstName']?.toString(),
      lastName: j['lastName']?.toString(),
      email: j['email']?.toString(),
      phone: j['phone']?.toString(),
      avatar: j['avatar']?.toString(),
      role: j['role']?.toString(),
      isActive: j['isActive'] as bool?,
      aiDailyLimit: (j['aiDailyLimit'] as num?)?.toInt(),
      channels: (j['channels'] as List?)
          ?.whereType<Map>()
          .map((c) => ChannelRef.fromJson(Map<String, dynamic>.from(c)))
          .toList(),
      addedByName: added is Map
          ? '${added['firstName'] ?? ''} ${added['lastName'] ?? ''}'.trim()
          : null,
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(j['updatedAt']?.toString() ?? ''),
      teamLeaderId: tl is Map
          ? (tl['_id'] ?? tl['id'])?.toString()
          : tl?.toString(),
    );
  }
}
