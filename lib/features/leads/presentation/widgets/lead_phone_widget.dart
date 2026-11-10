// ignore_for_file: deprecated_member_use
// lead_phone_widget.dart
// Widget مستقل: الرقم + (اتصال / واتساب / آخر كومنت). بيتستخدم في أي كارت أو رول.
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/utils/phone_utils.dart';
import 'package:flutter_application_1/features/comments/data/last_comment_model.dart';
import 'package:url_launcher/url_launcher.dart';

class LeadPhoneRow extends StatelessWidget {
  final String phone;
  final String? countryCode;
  final bool dark;

  /// آخر كومنت لو جاي مع الـ lead
  final LastComment? lastComment; // ✅ كان String?

  /// بديل: لو الكومنت مش جاي في الليست، حمّله من الـ API عند الضغط
  final Future<LastComment?> Function()? commentLoader; // ✅ كان Future<String?>

  /// override لو عايز سلوك تاني للزرار التالت
  final VoidCallback? onNoteTap;

  const LeadPhoneRow({
    super.key,
    required this.phone,
    required this.dark,
    this.countryCode,
    this.lastComment,
    this.commentLoader,
    this.onNoteTap,
  });

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _launch(BuildContext context, Uri uri, String failMsg) async {
    try {
      // مش بنستخدم canLaunchUrl: بترجع false على أندرويد 11+ من غير <queries>
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) _toast(context, failMsg);
    } catch (_) {
      if (context.mounted) _toast(context, failMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = PhoneUtils.parse(phone, countryCode: countryCode);
    final accent = dark ? AppColors.gold : AppColors.navy;
    final textMain = dark ? AppColors.white : AppColors.textPrimary;

    void guard(VoidCallback ok) {
      if (!info.isValid) {
        _toast(context, info.error ?? 'Invalid phone number');
        return;
      }
      ok();
    }

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              if (!info.isValid) ...[
                const Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: Color(0xFFE5484D),
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  info.isValid
                      ? info.e164
                      : '${countryCode ?? ''} $phone'.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: info.isValid ? textMain : const Color(0xFFE5484D),
                  ),
                ),
              ),
            ],
          ),
        ),
        LeadActionBtn(
          icon: Icons.call_rounded,
          color: accent,
          enabled: info.isValid,
          onTap: () => guard(
            () => _launch(
              context,
              Uri(scheme: 'tel', path: info.e164),
              'Could not open the dialer',
            ),
          ),
        ),
        const SizedBox(width: 8),
        LeadActionBtn(
          icon: Icons.chat_rounded,
          color: const Color(0xFF16A34A),
          enabled: info.isValid,
          onTap: () => guard(
            () => _launch(
              context,
              Uri.parse('https://wa.me/${info.digits}'),
              'Could not open WhatsApp',
            ),
          ),
        ),
        const SizedBox(width: 8),
        LeadActionBtn(
          icon: Icons.sticky_note_2_rounded,
          color: dark ? AppColors.goldLight : AppColors.navyLight,
          onTap:
              onNoteTap ??
              () => showLastCommentSheet(
                context,
                comment: lastComment,
                loader: commentLoader,
              ),
        ),
      ],
    );
  }
}

class LeadActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;
  const LeadActionBtn({
    super.key,
    required this.icon,
    required this.color,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Last comment sheet
// ─────────────────────────────────────────────
Future<void> showLastCommentSheet(
  BuildContext context, {
  LastComment? comment,
  Future<LastComment?> Function()? loader,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CommentSheet(comment: comment, loader: loader),
  );
}

class _CommentSheet extends StatefulWidget {
  final LastComment? comment;
  final Future<LastComment?> Function()? loader;
  const _CommentSheet({this.comment, this.loader});

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  late final Future<LastComment?> _future = widget.loader != null
      ? widget.loader!()
      : Future.value(widget.comment);

  /// 75 → 1:15 (بافتراض إن voiceDuration بالثواني)
  String _fmtDuration(int s) =>
      '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? Colors.white : AppColors.textPrimary;
    final sub = dark ? Colors.white60 : AppColors.textSecondary;
    final accent = dark ? AppColors.gold : AppColors.navy;
    final box = dark ? Colors.white.withOpacity(0.05) : AppColors.background;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewPadding.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: dark ? AppColors.navyLight : AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sticky_note_2_rounded, color: accent),
              const SizedBox(width: 8),
              Text(
                'Last comment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<LastComment?>(
            future: _future,
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return const Text(
                  'Could not load the comment',
                  style: TextStyle(color: Color(0xFFE5484D)),
                );
              }

              final c = snap.data;
              // مفيش كومنت، أو مفيش لا نص ولا صوت
              if (c == null || (c.text.isEmpty && !c.hasVoice)) {
                return Text(
                  'No comments yet',
                  style: TextStyle(color: sub, fontSize: 15),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الكاتب + الوقت
                  if (c.authorName.isNotEmpty || c.timeLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 16,
                            color: sub,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              c.authorName.isEmpty ? '—' : c.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: text,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            c.timeLabel,
                            style: TextStyle(fontSize: 12, color: sub),
                          ),
                        ],
                      ),
                    ),

                  // النص
                  if (c.text.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: box,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SelectableText(
                        c.text,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          color: text,
                        ),
                      ),
                    ),

                  // الصوت (بيان بس: التشغيل محتاج endpoint تحميل الصوت بالـ id)
                  if (c.hasVoice) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.mic_rounded, color: accent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            c.voiceDuration == null
                                ? 'Voice note'
                                : 'Voice note · ${_fmtDuration(c.voiceDuration!)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // تفريغ الصوت لنص
                  if (c.transcript.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: box,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SelectableText(
                        c.transcript.join('\n'),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: sub,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
