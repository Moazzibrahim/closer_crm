// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/utils/voice_bubble.dart';
import 'package:flutter_application_1/features/comments/data/all_comments_model.dart';
import 'package:flutter_application_1/features/comments/presentation/widgets/edit_text_sheet.dart';
import 'package:flutter_application_1/features/comments/presentation/widgets/reply_sheet.dart';
import 'package:flutter_application_1/features/comments/providers/comments_service.dart';
import 'package:flutter_application_1/features/leads/data/lead_model.dart';
import 'package:flutter_application_1/features/leads/presentation/widgets/lead_details_widget.dart';

class CommentCard extends StatelessWidget {
  final CommentItem comment;
  final String leadId;
  final CommentsService svc;
  final bool canReply;
  final String currentUserId; // 👈 جديد
  final bool isAdmin; // 👈 جديد
  final VoidCallback? onChanged; // 👈 اتغير اسمه من onReplied
  const CommentCard({
    super.key,
    required this.comment,
    required this.leadId,
    required this.svc,
    this.canReply = true,
    this.currentUserId = '',
    this.isAdmin = false,
    this.onChanged,
  });

  bool _canManage(String authorId) =>
      isAdmin || (currentUserId.isNotEmpty && authorId == currentUserId);

  void _toast(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<bool> _confirmDelete(BuildContext context, String what) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $what?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ---- Comment actions ----
  Future<void> _editComment(BuildContext context) async {
    final ok = await showEditTextSheet(
      context,
      title: 'Edit comment',
      initial: comment.text,
      save: (txt) => svc.editComment(leadId, comment.id, txt),
    );
    if (ok) onChanged?.call();
  }

  Future<void> _deleteComment(BuildContext context) async {
    if (!await _confirmDelete(context, 'comment')) return;
    try {
      await svc.deleteComment(leadId, comment.id);
      onChanged?.call();
    } catch (e) {
      if (context.mounted) _toast(context, e.toString());
    }
  }

  // ---- Reply actions ----
  Future<void> _editReply(BuildContext context, CommentReply r) async {
    final ok = await showEditTextSheet(
      context,
      title: 'Edit reply',
      initial: r.text,
      save: (txt) => svc.editReply(leadId, comment.id, r.id, txt),
    );
    if (ok) onChanged?.call();
  }

  Future<void> _deleteReply(BuildContext context, CommentReply r) async {
    if (!await _confirmDelete(context, 'reply')) return;
    try {
      await svc.deleteReply(leadId, comment.id, r.id);
      onChanged?.call();
    } catch (e) {
      if (context.mounted) _toast(context, e.toString());
    }
  }

  /// قائمة ⋮ (Edit بس لو فيه نص، لأن الـ API بيعدّل النص فقط)
  Widget _menu({
    required bool canEdit,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_vert_rounded, size: 20),
        onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (_) => [
          if (canEdit)
            const PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit_rounded, size: 18),
                SizedBox(width: 8),
                Text('Edit'),
              ]),
            ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = LdTheme.of(context);
    final c = comment;

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
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.navy,
                child: Text(
                  c.authorName.isEmpty ? '?' : c.authorName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${c.authorRole} · ${fmtLeadDate(c.createdAt)}${c.isEdited ? ' · edited' : ''}',
                      style: TextStyle(fontSize: 11, color: t.sub),
                    ),
                  ],
                ),
              ),
              if (_canManage(c.authorId))
                _menu(
                  canEdit: c.text.isNotEmpty,
                  onEdit: () => _editComment(context),
                  onDelete: () => _deleteComment(context),
                ),
            ],
          ),
          if (c.hasStageChange) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.swap_horiz_rounded, size: 16, color: t.sub),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${(c.stageFrom ?? '').isEmpty ? '—' : c.stageFrom} → ${c.stageTo}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (c.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(c.text, style: const TextStyle(fontSize: 14, height: 1.4)),
          ],
          if (c.voice != null) ...[
            const SizedBox(height: 10),
            VoiceBubble(
              voice: c.voice!,
              loader: () => svc.downloadCommentVoice(leadId, c.id),
            ),
          ],
          if (c.replies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: t.border, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in c.replies)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${r.authorName} · ${fmtLeadDate(r.createdAt)}',
                                  style: TextStyle(fontSize: 11, color: t.sub),
                                ),
                              ),
                              if (_canManage(r.authorId))
                                _menu(
                                  canEdit: r.text.isNotEmpty,
                                  onEdit: () => _editReply(context, r),
                                  onDelete: () => _deleteReply(context, r),
                                ),
                            ],
                          ),
                          if (r.text.isNotEmpty)
                            Text(r.text, style: const TextStyle(fontSize: 13)),
                          if (r.voice != null) ...[
                            const SizedBox(height: 6),
                            VoiceBubble(
                              voice: r.voice!,
                              loader: () =>
                                  svc.downloadReplyVoice(leadId, c.id, r.id),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (canReply)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () async {
                  final ok = await showReplySheet(
                    context,
                    svc: svc,
                    leadId: leadId,
                    commentId: c.id,
                    replyingTo: c.authorName,
                  );
                  if (ok) onChanged?.call();
                },
                icon: const Icon(Icons.reply_rounded, size: 18),
                label: const Text('Reply'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.gold,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}