// ignore_for_file: deprecated_member_use
// voice_comment_player.dart
// مشغّل صوت للكومنت: بيحمّل الصوت من الـ API (محتاج Authorization) مرة واحدة
// وبعدين بيشغّله من ملف مؤقت.
//
// pubspec.yaml:  just_audio: ^0.9.40  |  path_provider: ^2.1.0
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
// ⚠️ عدّل المسار لو مختلف
import 'package:flutter_application_1/features/comments/providers/comments_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class VoiceCommentPlayer extends StatefulWidget {
  final String leadId, commentId;
  final int? durationSeconds; // للعرض قبل التحميل

  const VoiceCommentPlayer({
    super.key,
    required this.leadId,
    required this.commentId,
    this.durationSeconds,
  });

  @override
  State<VoiceCommentPlayer> createState() => _VoiceCommentPlayerState();
}

class _VoiceCommentPlayerState extends State<VoiceCommentPlayer> {
  AudioPlayer? _player;
  final _subs = <StreamSubscription>[];
  bool _loading = false;
  bool _playing = false;
  String? _error;
  Duration _pos = Duration.zero;
  Duration? _dur;

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await CommentsService()
          .downloadCommentVoice(widget.leadId, widget.commentId);
      if (bytes.isEmpty) throw 'Empty audio';
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/comment_voice_${widget.commentId}.m4a');
      await file.writeAsBytes(bytes, flush: true);

      final p = AudioPlayer();
      await p.setFilePath(file.path);
      _subs.add(p.positionStream.listen((d) {
        if (mounted) setState(() => _pos = d);
      }));
      _subs.add(p.durationStream.listen((d) {
        if (mounted && d != null) setState(() => _dur = d);
      }));
      _subs.add(p.playerStateStream.listen((s) async {
        if (!mounted) return;
        if (s.processingState == ProcessingState.completed) {
          await p.pause();
          await p.seek(Duration.zero);
        }
        setState(() => _playing = s.playing &&
            s.processingState != ProcessingState.completed);
      }));
      _player = p;
    } catch (e) {
      _error = 'Could not load the voice note';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle() async {
    if (_loading) return;
    if (_player == null) {
      await _prepare();
      if (_player == null) return;
    }
    if (_playing) {
      await _player!.pause();
    } else {
      await _player!.play();
    }
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppColors.gold : AppColors.navy;
    final sub = dark ? Colors.white60 : AppColors.textSecondary;

    final total = _dur ??
        (widget.durationSeconds != null
            ? Duration(seconds: widget.durationSeconds!)
            : null);
    final progress = (total == null || total.inMilliseconds == 0)
        ? 0.0
        : (_pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: _toggle,
              customBorder: const CircleBorder(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: _loading
                    ? Padding(
                        padding: const EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: dark ? AppColors.navy : Colors.white,
                        ),
                      )
                    : Icon(
                        _playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: dark ? AppColors.navy : Colors.white,
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: progress,
                  activeColor: accent,
                  inactiveColor: accent.withOpacity(0.2),
                  onChanged: (_player == null || total == null)
                      ? null
                      : (v) => _player!.seek(total * v),
                ),
              ),
            ),
            Text(
              total == null
                  ? _fmt(_pos)
                  : '${_fmt(_pos)} / ${_fmt(total)}',
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w600, color: sub),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_error!,
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
          ),
      ],
    );
  }
}