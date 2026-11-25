// messaging_models.dart
// Models for /api/v1/messaging/inbox (Unifonic) and /api/v1/unisent/inbox (Unisent).
// الـ responses هنا plain JSON (مش {status,data}).

// ignore_for_file: avoid_print

DateTime? _dt(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

String _s(dynamic v) => v?.toString() ?? '';

/// GET /inbox/me — صلاحيات المستخدم الحالي في المحادثات
class InboxMe {
  final String role; // admin / manager / teamleader / sales
  final bool all, canFilter, canAssign, canDeleteForMe, canDeleteForAll, gifs;
  final int maxPins;
  final String provider; // unifonic | unisent

  const InboxMe({
    required this.role,
    required this.all,
    required this.canFilter,
    required this.canAssign,
    required this.canDeleteForMe,
    required this.canDeleteForAll,
    required this.gifs,
    required this.maxPins,
    required this.provider,
  });

  bool get isUnisent => provider.toLowerCase() == 'unisent';

  factory InboxMe.fromJson(Map<String, dynamic> j) => InboxMe(
    role: _s(j['role']),
    all: j['all'] == true,
    canFilter: j['canFilter'] == true,
    canAssign: j['canAssign'] == true,
    canDeleteForMe: j['canDeleteForMe'] == true,
    canDeleteForAll: j['canDeleteForAll'] == true,
    gifs: j['gifs'] == true,
    maxPins: (j['maxPins'] as num?)?.toInt() ?? 5,
    provider: _s(j['provider']).isEmpty ? 'unifonic' : _s(j['provider']),
  );
}

class SalesOption {
  final String id, label;
  const SalesOption(this.id, this.label);
  factory SalesOption.fromJson(Map<String, dynamic> j) =>
      SalesOption(_s(j['id']), _s(j['label']));
}

class WaConversation {
  final String id, phone, name, leadId;
  final int unread;
  final String lastText, lastType, lastDirection;
  final DateTime? lastAt;
  final bool windowOpen, pinned, archived;
  final DateTime? windowEndsAt;
  final String? interest; // interested | not_interested | null
  final String note;
  final String stage, project, salesId, salesName;

  const WaConversation({
    required this.id,
    required this.phone,
    required this.name,
    required this.leadId,
    required this.unread,
    required this.lastText,
    required this.lastType,
    required this.lastDirection,
    required this.lastAt,
    required this.windowOpen,
    required this.windowEndsAt,
    required this.pinned,
    required this.archived,
    required this.interest,
    required this.note,
    required this.stage,
    required this.project,
    required this.salesId,
    required this.salesName,
  });

  String get title =>
      name.isNotEmpty ? name : (phone.isNotEmpty ? '+$phone' : '—');

  /// نص آخر رسالة للعرض في القائمة
  String get preview {
    if (lastText.isNotEmpty) return lastText;
    switch (lastType) {
      case 'image':
        return '📷 Photo';
      case 'video':
        return '🎥 Video';
      case 'audio':
        return '🎤 Audio';
      case 'file':
        return '📎 File';
      case 'sticker':
        return 'Sticker';
      case 'location':
        return '📍 Location';
      case 'template':
        return '📋 Template';
      default:
        return '';
    }
  }

  factory WaConversation.fromJson(Map<String, dynamic> j) {
    final last = (j['lastMessage'] is Map)
        ? Map<String, dynamic>.from(j['lastMessage'])
        : <String, dynamic>{};
    final lead = (j['lead'] is Map)
        ? Map<String, dynamic>.from(j['lead'])
        : <String, dynamic>{};
    return WaConversation(
      id: _s(j['id'] ?? j['_id']),
      phone: _s(j['phone']),
      name: _s(j['name'] ?? j['leadName']),
      leadId: _s(j['leadId'] ?? lead['id']),
      unread: (j['unread'] as num?)?.toInt() ?? 0,
      lastText: _s(last['text']),
      lastType: _s(last['type']),
      lastDirection: _s(last['direction']),
      lastAt: _dt(last['at']),
      windowOpen: j['windowOpen'] == true,
      windowEndsAt: _dt(j['windowEndsAt']),
      pinned: j['pinned'] == true,
      archived: j['archived'] == true,
      interest: j['interest']?.toString(),
      note: _s(j['note']),
      stage: _s(lead['stage']),
      project: _s(lead['project']),
      salesId: _s(lead['salesId']),
      salesName: _s(lead['salesName']),
    );
  }
}

class WaMessage {
  final String id, conversationId, direction, status, error, type, text;
  final DateTime at;
  final String userName, templateName, source;
  final String? mediaUrl, mediaName;
  final bool voice, forwarded;
  final Map<String, dynamic>? location;

  const WaMessage({
    required this.id,
    required this.conversationId,
    required this.direction,
    required this.at,
    required this.status,
    required this.error,
    required this.type,
    required this.text,
    required this.userName,
    required this.templateName,
    required this.source,
    required this.mediaUrl,
    required this.mediaName,
    required this.voice,
    required this.forwarded,
    required this.location,
  });

  bool get isOut => direction == 'out';
  bool get isDeleted => type == 'deleted';

  factory WaMessage.fromJson(Map<String, dynamic> j) {
    // شكل الـ media مش موضح في الدليل (null في الأمثلة): نقبل String أو Map فيها url
    String? url, name;
    if (_s(j['type']) == 'sticker') print('MSG RAW [sticker]: $j');
    final m = j['media'];
    if (m is String) {
      url = m;
    } else if (m is Map) {
      url = (m['url'] ?? m['link'])?.toString();
      name = (m['fileName'] ?? m['name'])?.toString();
    }
    return WaMessage(
      id: _s(j['id'] ?? j['_id']),
      conversationId: _s(j['conversationId']),
      direction: _s(j['direction']),
      at: _dt(j['at']) ?? DateTime.now(),
      status: _s(j['status']),
      error: _s(j['error']),
      type: _s(j['type']).isEmpty ? 'text' : _s(j['type']),
      text: _s(j['text']),
      userName: _s(j['userName']),
      templateName: _s(j['templateName']),
      source: _s(j['source']),
      mediaUrl: url,
      mediaName: name,
      voice: j['voice'] == true,
      forwarded: j['forwarded'] == true,
      location: j['location'] is Map
          ? Map<String, dynamic>.from(j['location'])
          : null,
    );
  }
}

class WaTemplate {
  final String name, language, category, bodyText;
  final int bodyVars, headerVars;
  final dynamic header; // شكله مش موضح، بنستخدمه بس نعرف لو محتاج media
  final List<String> buttons;

  const WaTemplate({
    required this.name,
    required this.language,
    required this.category,
    required this.bodyText,
    required this.bodyVars,
    required this.headerVars,
    required this.header,
    required this.buttons,
  });

  bool get needsMedia {
    final h = header;
    if (h is Map) {
      final f = _s(h['format'] ?? h['type']).toUpperCase();
      return f == 'IMAGE' || f == 'VIDEO' || f == 'DOCUMENT';
    }
    return false;
  }

  static int _count(dynamic v) =>
      v is num ? v.toInt() : (v is List ? v.length : 0);

  factory WaTemplate.fromJson(Map<String, dynamic> j) => WaTemplate(
    name: _s(j['name']),
    language: _s(j['language']),
    category: _s(j['category']),
    bodyText: _s(j['bodyText']),
    bodyVars: _count(j['bodyVars']),
    headerVars: _count(j['headerVars']),
    header: j['header'],
    buttons: [
      for (final b in (j['buttons'] as List? ?? const []))
        if (b is Map) _s(b['text']),
    ],
  );
}
