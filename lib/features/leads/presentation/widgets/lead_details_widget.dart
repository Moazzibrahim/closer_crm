// ignore_for_file: deprecated_member_use, unnecessary_underscores
// كل الـ widgets والـ helpers المشتركة بين صفحة التفاصيل وصفحة All Comments.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/features/comments/data/last_comment_model.dart';
import 'package:flutter_application_1/features/leads/data/lead_model.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Theme tokens ──
class LdTheme {
  final bool dark;
  const LdTheme(this.dark);
  factory LdTheme.of(BuildContext c) =>
      LdTheme(Theme.of(c).brightness == Brightness.dark);

  Color get bg => dark ? const Color(0xFF121212) : AppColors.background;
  Color get card => dark ? const Color(0xFF1E1E1E) : AppColors.white;
  Color get text => dark ? Colors.white : AppColors.textPrimary;
  Color get sub => dark ? Colors.white54 : AppColors.textSecondary;
  Color get border => dark ? Colors.white10 : AppColors.border;
  Color get accent => dark ? AppColors.goldLight : AppColors.navy;
  List<BoxShadow> get shadow => [
    BoxShadow(
      color: Colors.black.withOpacity(dark ? 0.2 : 0.04),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];
}

// ── Parsing helpers ──
/// نص من String أو Map (name / fullName / title)
String ldS(dynamic v) {
  if (v == null) return '';
  if (v is Map)
    return '${v['name'] ?? v['fullName'] ?? v['title'] ?? ''}'.trim();
  return v.toString().trim();
}

/// أسماء من List<Map|String> مدموجة
String ldNames(dynamic v) {
  if (v is! List) return ldS(v);
  return v.map(ldS).where((e) => e.isNotEmpty).join(', ');
}

String ldPersonName(dynamic u) {
  if (u is! Map) return ldS(u);
  final full =
      '${u['fullName'] ?? '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'}'
          .trim();
  return full.isEmpty ? '${u['email'] ?? ''}' : full;
}

/// بيفك {data: {...}} أو الـ object نفسه
Map<String, dynamic> ldUnwrapLead(Map<String, dynamic> res) {
  final d = res['data'];
  if (d is Map) {
    final inner = d['lead'];
    return Map<String, dynamic>.from(inner is Map ? inner : d);
  }
  final l = res['lead'];
  return Map<String, dynamic>.from(l is Map ? l : res);
}

/// ليستة الكومنتات (الأحدث الأول)
List<LastComment> ldParseComments(Map<String, dynamic> res) {
  dynamic raw = res['data'];
  if (raw is Map) raw = raw['comments'] ?? raw['data'];
  raw ??= res['comments'];
  final list = (raw is List ? raw : const [])
      .map(LastComment.tryParse)
      .whereType<LastComment>()
      .toList();
  list.sort((a, b) {
    final x = a.createdAt, y = b.createdAt;
    if (x == null || y == null) return 0;
    return y.compareTo(x);
  });
  return list;
}

// ── Models ──
class LdAssignEntry {
  final String name, by, date;
  final bool current;
  const LdAssignEntry(this.name, this.by, this.date, this.current);
}

class LdRow {
  final IconData icon;
  final String label, value;
  final bool copy;
  final String? actionLabel; // 👈 نص الزرار (اختياري)
  final VoidCallback? onAction; // 👈
  const LdRow(
    this.icon,
    this.label,
    this.value, {
    this.copy = false,
    this.actionLabel,
    this.onAction,
  });
}

// ─────────────────────────────────────────────
//  Header
// ─────────────────────────────────────────────
class LdHeader extends StatelessWidget {
  final LeadItem? item;
  final VoidCallback onBack;
  final bool canCall;
  const LdHeader({
    super.key,
    required this.item,
    required this.onBack,
    this.canCall = true,
  });

  String get _initials {
    final p = (item?.name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (p.isEmpty) return '?';
    return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
  }

  Future<void> _call() async {
    final phone = item?.fullPhone.replaceAll(RegExp(r'[^\d+]'), '') ?? '';
    if (phone.isEmpty) return;
    try {
      await launchUrl(
        Uri(scheme: 'tel', path: phone),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final top = MediaQuery.of(context).padding.top;
    final lead = item;

    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 10, 16, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? [const Color(0xFF1A1F2E), AppColors.navy]
              : [AppColors.navy, AppColors.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LdBackBtn(onTap: onBack),
              const SizedBox(width: 12),
              const Text(
                'Lead Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (lead != null) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.gold, width: 1.5),
                  ),
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.goldLight,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.flag_rounded,
                              size: 12,
                              color: AppColors.navy,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                lead.stageName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.phone_rounded,
                    size: 18,
                    color: AppColors.goldLight,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lead.fullPhone,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  if (canCall)
                    InkWell(
                      onTap: _call,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.call_rounded,
                          size: 20,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class LdBackBtn extends StatelessWidget {
  final VoidCallback onTap;
  const LdBackBtn({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.goldLight,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Small widgets
// ─────────────────────────────────────────────
class LdActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool gold;
  final VoidCallback onTap;
  const LdActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.gold = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = LdTheme.of(context);
    final accent = gold ? AppColors.gold : t.accent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border),
          boxShadow: t.shadow,
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withOpacity(t.dark ? 0.15 : 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: t.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LdBottomBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const LdBottomBtn({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = LdTheme.of(context);
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? AppColors.navy : t.card,
          foregroundColor: filled ? AppColors.goldLight : t.text,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: filled ? AppColors.gold : t.border),
          ),
        ),
      ),
    );
  }
}

class LdSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const LdSectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = LdTheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, trailing == null ? 16 : 6, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: t.text,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class LdInfoCard extends StatelessWidget {
  final List<LdRow> rows;
  final VoidCallback onCopied;
  const LdInfoCard({super.key, required this.rows, required this.onCopied});

  @override
  Widget build(BuildContext context) {
    final t = LdTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.border),
          boxShadow: t.shadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              for (int i = 0; i < rows.length; i++) ...[
                _InfoTile(row: rows[i], onCopied: onCopied),
                if (i != rows.length - 1)
                  Divider(height: 1, indent: 58, color: t.border),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final LdRow row;
  final VoidCallback onCopied;
  const _InfoTile({required this.row, required this.onCopied});

  @override
  Widget build(BuildContext context) {
    final t = LdTheme.of(context);
    return InkWell(
      // النسخ للـ email والـ link بس
      onTap: row.copy
          ? () {
              Clipboard.setData(ClipboardData(text: row.value));
              onCopied();
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: t.accent.withOpacity(t.dark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(row.icon, size: 18, color: t.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                      color: t.sub,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    row.value,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: t.text,
                    ),
                  ),
                ],
              ),
            ),
            if (row.onAction != null && row.actionLabel != null)
              TextButton(
                onPressed: row.onAction,
                style: TextButton.styleFrom(
                  foregroundColor: t.accent,
                  backgroundColor: t.accent.withOpacity(0.10),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  row.actionLabel!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (row.copy) Icon(Icons.copy_rounded, size: 16, color: t.sub),
          ],
        ),
      ),
    );
  }
}

class LdHistoryCard extends StatelessWidget {
  final List<LdAssignEntry> items;
  const LdHistoryCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final t = LdTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.border),
          boxShadow: t.shadow,
        ),
        child: Column(
          children: [
            for (int i = 0; i < items.length; i++)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 20,
                      child: Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(top: 3),
                            decoration: BoxDecoration(
                              color: items[i].current
                                  ? AppColors.gold
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.gold,
                                width: 2,
                              ),
                            ),
                          ),
                          if (i != items.length - 1)
                            Expanded(
                              child: Container(
                                width: 2,
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                color: t.border,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    items[i].name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: t.text,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (items[i].current) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.gold.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'CURRENT',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.gold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            // by + التاريخ بيظهروا لو موجودين
                            if (items[i].by.isNotEmpty ||
                                !items[i].date.startsWith('—')) ...[
                              const SizedBox(height: 3),
                              Text(
                                [
                                  if (items[i].by.isNotEmpty)
                                    'by ${items[i].by}',
                                  if (!items[i].date.startsWith('—'))
                                    items[i].date,
                                ].join('  •  '),
                                style: TextStyle(fontSize: 11, color: t.sub),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Timeline (مشترك للـ Stages History والـ Creation Dates) ──
class LdTimelineEntry {
  final String title, meta, notes; // meta = "by X • التاريخ والوقت"
  final Color color;
  final bool current;
  const LdTimelineEntry({
    required this.title,
    required this.meta,
    this.notes = '',
    required this.color,
    this.current = false,
  });
}

/// "#E67E22" → Color
Color ldHex(String? h, [Color fallback = AppColors.gold]) {
  final s = (h ?? '').replaceAll('#', '');
  final v = int.tryParse(s.length == 6 ? 'FF$s' : s, radix: 16);
  return v == null ? fallback : Color(v);
}

class LdTimelineCard extends StatelessWidget {
  final List<LdTimelineEntry> items;
  const LdTimelineCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final t = LdTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.border),
          boxShadow: t.shadow,
        ),
        child: Column(
          children: [
            for (int i = 0; i < items.length; i++)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // النقطة + الخط
                    SizedBox(
                      width: 20,
                      child: Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(top: 3),
                            decoration: BoxDecoration(
                              color: items[i].current
                                  ? items[i].color
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: items[i].color,
                                width: 2,
                              ),
                            ),
                          ),
                          if (i != items.length - 1)
                            Expanded(
                              child: Container(
                                width: 2,
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                color: t.border,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    items[i].title,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: t.text,
                                    ),
                                  ),
                                ),
                                if (items[i].current) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: items[i].color.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'CURRENT',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: items[i].color,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (items[i].meta.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                items[i].meta,
                                style: TextStyle(fontSize: 11, color: t.sub),
                              ),
                            ],
                            if (items[i].notes.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                items[i].notes,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: t.text.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LdEmptyComments extends StatelessWidget {
  final VoidCallback? onTap; // null = مفيش صلاحية إضافة
  const LdEmptyComments({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = LdTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.border),
        ),
        child: Text(
          onTap == null
              ? 'No comments yet'
              : 'No comments yet. Tap to add one.',
          style: TextStyle(fontSize: 13, color: t.sub),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Questions & Answers
// ─────────────────────────────────────────────
class LdQACard extends StatelessWidget {
  final List<LeadQA> items;
  const LdQACard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final t = LdTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.border),
          boxShadow: t.shadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // أيقونة السؤال
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: t.accent.withOpacity(t.dark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.help_outline_rounded,
                          size: 18,
                          color: t.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // السؤال
                            Text(
                              items[i].question.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9.5,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w600,
                                color: t.sub,
                              ),
                            ),
                            const SizedBox(height: 3),
                            // الإجابة
                            Text(
                              items[i].answer.isEmpty ? '—' : items[i].answer,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: t.text,
                              ),
                            ),
                            // المصدر + وقت الإجابة (لو موجودين)
                            if (items[i].source != null ||
                                items[i].answeredAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if (items[i].source != null) items[i].source!,
                                  if (items[i].answeredAt != null)
                                    fmtLeadDate(items[i].answeredAt),
                                ].join('  •  '),
                                style: TextStyle(fontSize: 11, color: t.sub),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (i != items.length - 1)
                  Divider(height: 1, indent: 58, color: t.border),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LdErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const LdErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFE5484D)),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ── Submissions sheet ──
void showLdSubmissionsSheet(
  BuildContext context,
  List<Map> versions, {
  Map<String, String> names = const {}, // 👈 id → name
}) {
  final t = LdTheme.of(context);
  // الأحدث الأول
  final list = [...versions]
    ..sort(
      (a, b) => ((b['versionNumber'] as num?) ?? 0).compareTo(
        (a['versionNumber'] as num?) ?? 0,
      ),
    );

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(ctx).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Submissions (${list.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: t.text,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No submissions history',
                        style: TextStyle(color: t.sub),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) =>
                          _SubmissionTile(v: list[i], names: names),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SubmissionTile extends StatelessWidget {
  final Map v;
  final Map<String, String> names;
  const _SubmissionTile({required this.v, this.names = const {}});

  // الـ id أو الـ object → الاسم (فاضي لو مش لاقيه)
  String _resolve(dynamic x) {
    if (x == null) return '';
    if (x is Map) return ldS(x);
    return names['$x'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final t = LdTheme.of(context);
    final phone = '${v['phoneCountryCode'] ?? ''}${v['phone'] ?? ''}';
    final budget = v['budget'] is num
        ? (v['budget'] as num)
              .toStringAsFixed(0)
              .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')
        : '';
    final qa = (v['qa'] as List? ?? []).whereType<Map>().toList();

    // label → value (الفاضي بيتشال)
    final fields = <String, String>{
      'Name': ldS(v['name']),
      'Email': ldS(v['email']),
      'Phone': phone.trim(),
      'Project': _resolve(v['project']), // 👈 جديد
      'Channel': _resolve(v['channel']), // 👈 جديد
      'Campaign': _resolve(v['campaign']), // 👈 جديد
      'Budget': budget, // موجود، بيظهر لو فيه قيمة
      'Job Description': ldS(v['jobDescription']),
      'Campaign Link': ldS(v['campaignLink']),
      'Lead Type': ldS(v['leadType']),
      'Notes': ldS(v['notes']),
    }..removeWhere((_, val) => val.isEmpty);

    // ... باقي الـ build زي ما هو بدون تغيير
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${v['versionNumber'] ?? '-'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                fmtLeadDate(DateTime.tryParse('${v['recordedAt'] ?? ''}')),
                style: TextStyle(fontSize: 11.5, color: t.sub),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final e in fields.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.key.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                      color: t.sub,
                    ),
                  ),
                  Text(
                    e.value,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: t.text,
                    ),
                  ),
                ],
              ),
            ),
          if (qa.isNotEmpty) ...[
            Divider(color: t.border),
            for (final q in qa)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${q['question'] ?? ''}: ${q['answer'] ?? ''}',
                  style: TextStyle(fontSize: 12.5, color: t.text),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
