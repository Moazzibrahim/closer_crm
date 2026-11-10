// last_comment_model.dart
// آخر كومنت على الـ Lead (جاي من الـ API جوه lead.lastComment).

class LastComment {
  /// id الكومنت (محتاجه لتحميل الصوت)
  final String? id;
  final String text;
  final String authorName;
  final DateTime? createdAt; // UTC
  final bool hasVoice;

  /// ⚠️ بافترض إن الوحدة ثواني. لو الباك بيرجّعها بالميلي ثانية قولي.
  final int? voiceDuration;
  final List<String> transcript;

  const LastComment({
    this.id,
    this.text = '',
    this.authorName = '',
    this.createdAt,
    this.hasVoice = false,
    this.voiceDuration,
    this.transcript = const [],
  });

  /// بيقبل Map (الشكل الحالي) أو String (لو الباك رجّع نص بس).
  static LastComment? tryParse(dynamic json) {
    if (json == null) return null;
    if (json is String) {
      return json.trim().isEmpty ? null : LastComment(text: json.trim());
    }
    if (json is! Map) return null;

    String name = '';
    final a = json['author'];
    if (a is Map) {
      name = '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.trim();
      if (name.isEmpty) name = '${a['fullName'] ?? a['name'] ?? a['email'] ?? ''}';
    }

    final tr = json['voiceTranscript'];
    final transcript = <String>[
      if (tr is List)
        for (final e in tr)
          if (e is Map)
            '${e['text'] ?? e['content'] ?? ''}'
          else
            '$e',
    ].where((s) => s.trim().isNotEmpty).toList();

    final dur = json['voiceDuration'];
    return LastComment(
      id: json['comment']?.toString() ?? json['_id']?.toString(),
      text: '${json['text'] ?? ''}'.trim(),
      authorName: name,
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
      hasVoice: json['hasVoice'] == true,
      voiceDuration: dur is num ? dur.round() : null,
      transcript: transcript,
    );
  }

  /// Today, 6:13 PM / Yesterday, 6:13 PM / 11 Oct 2026, 6:13 PM
  String get timeLabel {
    final c = createdAt;
    if (c == null) return '';
    final d = c.toLocal();
    final now = DateTime.now();
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final t =
        '$h12:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
    bool same(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    if (same(d, now)) return 'Today, $t';
    if (same(d, now.subtract(const Duration(days: 1)))) return 'Yesterday, $t';
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}, $t';
  }
}