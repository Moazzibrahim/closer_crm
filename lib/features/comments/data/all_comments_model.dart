class TranscriptSeg {
  final double start, end;
  final String text;
  const TranscriptSeg(this.start, this.end, this.text);

  factory TranscriptSeg.fromJson(Map j) => TranscriptSeg(
    (j['start'] as num?)?.toDouble() ?? 0,
    (j['end'] as num?)?.toDouble() ?? 0,
    (j['text'] ?? '').toString().trim(),
  );
}

class CommentVoice {
  final String url, mimeType;
  final double duration;
  final List<TranscriptSeg> transcript;
  const CommentVoice({
    required this.url,
    required this.mimeType,
    required this.duration,
    required this.transcript,
  });

  String get fullTranscript =>
      transcript.map((s) => s.text).where((t) => t.isNotEmpty).join(' ');

  static CommentVoice? tryParse(dynamic v) {
    if (v is! Map) return null;
    final url = (v['url'] ?? '').toString();
    if (url.isEmpty) return null;
    return CommentVoice(
      url: url,
      mimeType: (v['mimeType'] ?? '').toString(),
      duration: (v['duration'] as num?)?.toDouble() ?? 0,
      transcript: (v['transcript'] as List? ?? [])
          .whereType<Map>()
          .map(TranscriptSeg.fromJson)
          .toList(),
    );
  }
}

class CommentReply {
  final String id, authorId, authorName, authorRole, text;
  final CommentVoice? voice;
  final DateTime? createdAt;
  const CommentReply({
    required this.id,
    required this.authorName,
    required this.authorRole,
    required this.text,
    this.authorId = '',
    this.voice,
    this.createdAt,
  });
}

String _authorName(dynamic a) {
  if (a is! Map) return 'Unknown';
  final n = '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.trim();
  return n.isEmpty ? (a['email'] ?? 'Unknown').toString() : n;
}

String _authorId(dynamic a) => a is Map ? (a['_id'] ?? '').toString() : '';

String? _stageName(dynamic s) {
  if (s == null) return null;
  if (s is Map) return (s['name'] ?? '').toString();
  return s.toString();
}

class CommentItem {
  final String id, authorName, authorRole, authorId, text;
  final String? authorAvatar, stageFrom, stageTo;
  final CommentVoice? voice;
  final DateTime? createdAt, scheduledAt;
  final bool isEdited;
  final List<CommentReply> replies;
  final Map raw; // عشان الـ LastComment.tryParse

  const CommentItem({
    required this.id,
    required this.authorName,
    required this.authorRole,
    this.authorId = '',
    required this.text,
    required this.isEdited,
    required this.replies,
    required this.raw,
    this.authorAvatar,
    this.stageFrom,
    this.stageTo,
    this.voice,
    this.createdAt,
    this.scheduledAt,
  });

  bool get hasStageChange => (stageTo ?? '').isNotEmpty;

  factory CommentItem.fromJson(Map j) {
    final a = j['author'] is Map ? j['author'] as Map : const {};
    final sc = j['stageChange'] is Map ? j['stageChange'] as Map : const {};
    return CommentItem(
      id: (j['_id'] ?? '').toString(),
      authorName: _authorName(a),
      authorRole: (j['authorRole'] ?? a['role'] ?? '').toString(),
      authorId: _authorId(a),
      authorAvatar: a['avatar']?.toString(),
      text: (j['text'] ?? '').toString(),
      voice: CommentVoice.tryParse(j['voice']),
      stageFrom: _stageName(sc['from']),
      stageTo: _stageName(sc['to']),
      createdAt: DateTime.tryParse('${j['createdAt']}'),
      scheduledAt: DateTime.tryParse('${j['scheduledAt']}'),
      isEdited: j['isEdited'] == true,
      raw: j,
      replies: (j['replies'] as List? ?? [])
          .whereType<Map>()
          .map(
            (r) => CommentReply(
              id: (r['_id'] ?? '').toString(),
              authorName: _authorName(r['author']),
              authorRole: (r['authorRole'] ?? '').toString(),
              text: (r['text'] ?? '').toString(),
              voice: CommentVoice.tryParse(r['voice']),
              createdAt: DateTime.tryParse('${r['createdAt']}'),
            ),
          )
          .toList(),
    );
  }

  /// بتقبل الـ response كله (Map فيه data) أو List
  static List<CommentItem> parseList(dynamic res) {
    final list = res is Map ? res['data'] : res;
    if (list is! List) return [];
    return list.whereType<Map>().map(CommentItem.fromJson).toList();
  }
}
