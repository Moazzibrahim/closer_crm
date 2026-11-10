class DeviceSession {
  final String id;
  final String deviceName;
  final String userAgent;
  final String platform; // android / ios / web / windows ...
  final String ip;
  final DateTime? lastLoginAt;
  final String? city, region, country;

  const DeviceSession({
    required this.id,
    required this.deviceName,
    required this.userAgent,
    required this.platform,
    required this.ip,
    this.lastLoginAt,
    this.city,
    this.region,
    this.country,
  });

  factory DeviceSession.fromJson(Map<String, dynamic> j) {
    final loc = (j['location'] as Map?) ?? const {};
    return DeviceSession(
      id: (j['_id'] ?? '').toString(),
      deviceName: (j['deviceName'] ?? 'Unknown device').toString(),
      userAgent: (j['userAgent'] ?? '').toString(),
      platform: (j['platform'] ?? 'unknown').toString().toLowerCase(),
      ip: (j['ip'] ?? '').toString().replaceFirst('::ffff:', ''),
      lastLoginAt: DateTime.tryParse(
        j['lastLoginAt']?.toString() ?? '',
      )?.toLocal(),
      city: loc['city']?.toString(),
      region: loc['region']?.toString(),
      country: loc['country']?.toString(),
    );
  }

  String? get locationText {
    final parts = [
      city,
      country,
    ].where((e) => e != null && e.trim().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// اسم مفهوم بدل الـ User-Agent الطويل
  String get prettyName {
    final ua = (userAgent.isNotEmpty ? userAgent : deviceName).toLowerCase();

    if (ua.startsWith('dart/')) {
      return platform == 'ios' ? 'iOS app' : 'Android app';
    }
    if (ua.startsWith('postman')) return 'Postman';

    if (ua.startsWith('mozilla')) {
      // الـ iPhone/iPad UA فيه "Mac OS X" فلازم نفحصه قبل mac
      final os = ua.contains('iphone') || ua.contains('ipad')
          ? 'iOS'
          : ua.contains('android')
          ? 'Android'
          : ua.contains('windows')
          ? 'Windows'
          : ua.contains('mac os')
          ? 'macOS'
          : ua.contains('linux')
          ? 'Linux'
          : 'Unknown OS';
      // Edge و Opera فيهم كلمة chrome، فلازم قبلها
      final br = ua.contains('edg/')
          ? 'Edge'
          : ua.contains('opr/')
          ? 'Opera'
          : ua.contains('firefox')
          ? 'Firefox'
          : ua.contains('chrome') || ua.contains('crios')
          ? 'Chrome'
          : ua.contains('safari')
          ? 'Safari'
          : 'Browser';
      return '$br on $os';
    }

    if (ua.startsWith('unknown browser')) {
      return platform == 'android'
          ? 'Android device'
          : platform == 'ios'
          ? 'iPhone / iPad'
          : 'Web browser';
    }
    return deviceName;
  }
}

class DeviceSessionsPage {
  final List<DeviceSession> items;
  final int currentPage, numberOfPages, totalItems;
  final bool hasNext;

  const DeviceSessionsPage({
    required this.items,
    required this.currentPage,
    required this.numberOfPages,
    required this.totalItems,
    required this.hasNext,
  });

  factory DeviceSessionsPage.fromJson(Map<String, dynamic> j) {
    final items = (j['data'] as List? ?? [])
        .whereType<Map>()
        .map((e) => DeviceSession.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final p = j['paginationResult'];
    // /sessions/user/:id مبيرجّعش pagination → كل الداتا في response واحد
    if (p is! Map) {
      return DeviceSessionsPage(
        items: items,
        currentPage: 1,
        numberOfPages: 1,
        totalItems: items.length,
        hasNext: false,
      );
    }
    return DeviceSessionsPage(
      items: items,
      currentPage: (p['currentPage'] ?? 1) as int,
      numberOfPages: (p['NumberOfPages'] ?? 1) as int,
      totalItems: (p['totalItems'] ?? items.length) as int,
      hasNext: p['next'] != null,
    );
  }
}
