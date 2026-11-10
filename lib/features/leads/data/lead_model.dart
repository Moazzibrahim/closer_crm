import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/comments/data/last_comment_model.dart';

/// سؤال وإجابة جاية من الـ integration/campaign (حقل qa في الـ JSON)
class LeadQA {
  final String question;
  final String answer;
  final String? source; // مثلاً: integration
  final DateTime? answeredAt;

  const LeadQA({
    required this.question,
    required this.answer,
    this.source,
    this.answeredAt,
  });

  factory LeadQA.fromJson(Map<String, dynamic> j) => LeadQA(
    question: (j['question'] ?? '').toString(),
    answer: (j['answer'] ?? '').toString(),
    source: j['source']?.toString(),
    answeredAt: j['answeredAt'] == null
        ? null
        : DateTime.tryParse(j['answeredAt'].toString()),
  );
}

class LeadItem {
  final String id,
      name,
      phone,
      fullPhone,
      stageId,
      stageName,
      project,
      salesman,
      leadType;
  final String? phoneCountryCode, notes;
  final String? email;
  final LastComment? lastComment;
  final Color stageColor;
  final DateTime? stageDate, created, nextFollowUpAt;
  final String? jobDescription, campaignLink; // 👈
  final int totalSubmissions; // 👈
  final List<LeadSubmission> submissions; // 👈
  final bool isActive;
  final List<LeadQA> qa; // 👈 الأسئلة والإجابات

  const LeadItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.fullPhone,
    required this.stageId,
    required this.stageName,
    required this.stageColor,
    required this.project,
    required this.salesman,
    required this.leadType,
    required this.isActive,
    this.email,
    this.lastComment,
    this.phoneCountryCode,
    this.notes,
    this.stageDate,
    this.created,
    this.nextFollowUpAt, // 👈
    this.jobDescription,
    this.campaignLink,
    this.totalSubmissions = 0,
    this.submissions = const [],
    this.qa =
        const [], // 👈 default فاضية عشان ما تكسرش أي مكان بيستخدم الـ constructor
  });

  static Color _hex(String? h) {
    try {
      final s = (h ?? '').replaceAll('#', '');
      return Color(int.parse(s.length == 6 ? 'FF$s' : s, radix: 16));
    } catch (_) {
      return const Color(0xFFEF4444);
    }
  }

  static DateTime? _dt(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  factory LeadItem.fromJson(Map<String, dynamic> j) {
    final stage = j['currentStage'] is Map ? j['currentStage'] as Map : null;

    // المشاريع: أول واحد + عدد الباقي
    final projects = (j['projects'] as List? ?? [])
        .whereType<Map>()
        .map((p) => (p['name'] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .toList();
    final project = projects.isEmpty
        ? '—'
        : projects.length == 1
        ? projects.first
        : '${projects.first} +${projects.length - 1}';

    // السيلز الحاليين (isCurrent)
    final sales = (j['sales'] as List? ?? [])
        .whereType<Map>()
        .where((s) => s['isCurrent'] == true && s['user'] is Map)
        .map((s) {
          final u = s['user'] as Map;
          final full =
              (u['fullName'] ??
                      '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}')
                  .toString()
                  .trim();
          return full.isEmpty ? (u['email'] ?? '').toString() : full;
        })
        .where((n) => n.isNotEmpty)
        .toList();

    // تاريخ آخر تغيير للـ stage
    DateTime? stageDate;
    for (final s in (j['stages'] as List? ?? []).whereType<Map>()) {
      if (s['isCurrent'] == true) stageDate = _dt(s['stageDate']);
    }

    // الأسئلة والإجابات: نتجاهل أي عنصر مش Map أو سؤاله/إجابته فاضيين
    final qa = (j['qa'] as List? ?? [])
        .whereType<Map>()
        .map((e) => LeadQA.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.question.isNotEmpty || e.answer.isNotEmpty)
        .toList();

    final cc = (j['phoneCountryCode'] ?? '').toString();
    final ph = (j['phone'] ?? '').toString();
    String? nz(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    final submissions = (j['allVersions'] as List? ?? [])
        .whereType<Map>()
        .map((e) => LeadSubmission.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return LeadItem(
      id: (j['_id'] ?? j['id']).toString(),
      name: (j['name'] ?? '').toString(),
      email: j['email']?.toString(),
      phone: ph,
      fullPhone: (j['fullPhone'] ?? '$cc$ph').toString(),
      stageId: (stage?['_id'] ?? '').toString(),
      stageName: (stage?['name'] ?? 'No Stage').toString(),
      stageColor: stage == null
          ? const Color(0xFFEF4444)
          : _hex(stage['color']?.toString()),
      project: project,
      salesman: sales.isEmpty ? 'Unassigned' : sales.join(', '),
      leadType: (j['leadType'] ?? '').toString(),
      isActive: j['isActive'] != false,
      lastComment: LastComment.tryParse(
        j['lastComment'],
      ), // Map أو String أو null
      stageDate: stageDate ?? _dt(j['updatedAt']),
      created: _dt(j['creationDate'] ?? j['createdAt']),
      nextFollowUpAt: _dt(j['nextFollowUpAt']), // 👈
      jobDescription: nz(j['jobDescription']), // 👈
      campaignLink: nz(j['campaignLink']), // 👈
      totalSubmissions: (j['totalSubmissions'] as num?)?.toInt() ?? 0, // 👈
      submissions: submissions, // 👈
      phoneCountryCode: cc.isEmpty ? null : cc,
      notes: j['notes']?.toString(),
      qa: qa, // 👈
    );
  }
}

/// نسخة (submission) واحدة من حقل allVersions
class LeadSubmission {
  final int version;
  final DateTime? recordedAt;
  final String name,
      email,
      phone,
      notes,
      jobDescription,
      campaignLink,
      leadType;
  final num? budget;
  final List<LeadQA> qa;

  const LeadSubmission({
    required this.version,
    this.recordedAt,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.notes = '',
    this.jobDescription = '',
    this.campaignLink = '',
    this.leadType = '',
    this.budget,
    this.qa = const [],
  });

  factory LeadSubmission.fromJson(Map<String, dynamic> j) {
    String s(dynamic v) => v == null ? '' : v.toString().trim();
    return LeadSubmission(
      version: (j['versionNumber'] as num?)?.toInt() ?? 0,
      recordedAt: j['recordedAt'] == null
          ? null
          : DateTime.tryParse(j['recordedAt'].toString()),
      name: s(j['name']),
      email: s(j['email']),
      phone: '${s(j['phoneCountryCode'])}${s(j['phone'])}',
      notes: s(j['notes']),
      jobDescription: s(j['jobDescription']),
      campaignLink: s(j['campaignLink']),
      leadType: s(j['leadType']),
      budget: j['budget'] is num ? j['budget'] as num : null,
      qa: (j['qa'] as List? ?? [])
          .whereType<Map>()
          .map((e) => LeadQA.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// dd/MM/yyyy · hh:mm AM (بتوقيت الجهاز)
String fmtLeadDate(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  return '${two(l.day)}/${two(l.month)}/${l.year} · ${two(h)}:${two(l.minute)} ${l.hour >= 12 ? 'PM' : 'AM'}';
}
