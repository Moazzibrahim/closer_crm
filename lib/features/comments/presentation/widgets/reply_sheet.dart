// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/utils/voice_note_util.dart';
import 'package:flutter_application_1/features/comments/providers/comments_service.dart';
import 'package:flutter_application_1/features/leads/presentation/widgets/lead_details_widget.dart';

/// بترجّع true لو الرد اتبعت.
Future<bool> showReplySheet(
  BuildContext context, {
  required CommentsService svc,
  required String leadId,
  required String commentId,
  required String replyingTo,
}) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReplySheet(
      svc: svc,
      leadId: leadId,
      commentId: commentId,
      replyingTo: replyingTo,
    ),
  );
  return r == true;
}

class _ReplySheet extends StatefulWidget {
  final CommentsService svc;
  final String leadId, commentId, replyingTo;
  const _ReplySheet({
    required this.svc,
    required this.leadId,
    required this.commentId,
    required this.replyingTo,
  });

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  final _ctrl = TextEditingController();
  File? _voice;
  bool _recording = false, _sending = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _canSend =>
      !_sending &&
      !_recording &&
      (_voice != null || _ctrl.text.trim().isNotEmpty);

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      if (_voice != null) {
        await widget.svc
            .addVoiceReply(widget.leadId, widget.commentId, _voice!);
      } else {
        await widget.svc
            .addReply(widget.leadId, widget.commentId, _ctrl.text.trim());
      }
      try {
        _voice?.deleteSync();
      } catch (_) {}
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = LdTheme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + bottom),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Reply to ${widget.replyingTo}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              enabled: _voice == null && !_sending,
              minLines: 2,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _voice == null
                    ? 'Write a reply...'
                    : 'Voice note attached (text disabled)',
                filled: true,
                fillColor: t.dark
                    ? Colors.white10
                    : AppColors.navy.withOpacity(0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: t.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: t.border),
                ),
              ),
            ),
            const SizedBox(height: 10),
            VoiceNoteField(
              enabled: !_sending,
              onChanged: (f) => setState(() => _voice = f),
              onRecordingChanged: (r) => setState(() => _recording = r),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12.5),
                ),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _canSend ? _send : null,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.navy,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_sending ? 'Sending...' : 'Send reply'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.navy,
                  disabledBackgroundColor: AppColors.gold.withOpacity(0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}