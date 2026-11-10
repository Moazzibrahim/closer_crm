// ignore_for_file: deprecated_member_use
// last_comment_card.dart
// كارت آخر كومنت: اسم الكاتب + الوقت + النص + مشغّل الصوت (لو فويس).
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/features/comments/data/last_comment_model.dart';
import 'package:flutter_application_1/features/comments/presentation/widgets/voice_comment_player.dart';

class LastCommentCard extends StatelessWidget {
  final LastComment comment;
  final String leadId;
  const LastCommentCard({
    super.key,
    required this.comment,
    required this.leadId,
  });

  String get _initials {
    final parts = comment.authorName
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts[1][0] : ''))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? AppColors.white : AppColors.textPrimary;
    final sub = dark ? Colors.white60 : AppColors.textSecondary;
    final tint = dark ? Colors.white.withOpacity(0.05) : AppColors.background;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── author + time ──
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.navy, AppColors.navyLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.authorName.isEmpty
                          ? 'Unknown'
                          : comment.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: text),
                    ),
                    if (comment.timeLabel.isNotEmpty)
                      Text(
                        comment.timeLabel,
                        style: TextStyle(fontSize: 11.5, color: sub),
                      ),
                  ],
                ),
              ),
              if (comment.hasVoice)
                Icon(Icons.mic_rounded, size: 18, color: sub),
            ],
          ),

          // ── text ──
          if (comment.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              comment.text,
              style: TextStyle(fontSize: 14, height: 1.4, color: text),
            ),
          ],

          // ── voice ──
          if (comment.hasVoice && comment.id != null) ...[
            const SizedBox(height: 10),
            VoiceCommentPlayer(
              leadId: leadId,
              commentId: comment.id!,
              durationSeconds: comment.voiceDuration,
            ),
          ],

          // ── transcript ──
          if (comment.transcript.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment.transcript.join(' '),
              style: TextStyle(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                  color: sub),
            ),
          ],
        ],
      ),
    );
  }
}