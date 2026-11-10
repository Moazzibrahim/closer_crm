// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/features/comments/data/all_comments_model.dart';
import 'package:flutter_application_1/features/leads/presentation/widgets/lead_details_widget.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class VoiceBubble extends StatefulWidget {
  final CommentVoice voice;

  /// بتنزّل bytes الصوت (من CommentsService).
  final Future<List<int>> Function() loader;
  const VoiceBubble({super.key, required this.voice, required this.loader});

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  static AudioPlayer? _current; // مشغّل واحد بس في نفس الوقت

  final _player = AudioPlayer();
  StreamSubscription? _posSub, _stateSub;
  Duration _pos = Duration.zero;
  Duration? _dur;
  bool _loaded = false, _loading = false, _playing = false, _showTx = false;
  String? _err;
  double _speed = 1;
  File? _tmp;

  // webm مش بيشتغل على iOS
  bool get _unsupported =>
      Platform.isIOS && widget.voice.mimeType.toLowerCase().contains('webm');

  // الامتداد من الـ mimeType (fallback لو مقدرناش نكتشف من الـ bytes)
  String get _ext {
    final m = widget.voice.mimeType.toLowerCase();
    if (m.contains('webm')) return 'webm';
    if (m.contains('mpeg') || m.contains('mp3')) return 'mp3';
    if (m.contains('ogg')) return 'ogg';
    if (m.contains('wav')) return 'wav';
    return 'm4a'; // audio/mp4 و audio/x-m4a
  }

  // اكتشاف الصيغة الحقيقية من أول bytes الملف
  String _detectExt(List<int> b) {
    if (b.length > 4 &&
        b[0] == 0x1A &&
        b[1] == 0x45 &&
        b[2] == 0xDF &&
        b[3] == 0xA3) {
      return 'webm';
    }
    if (b.length > 8 &&
        b[4] == 0x66 &&
        b[5] == 0x74 &&
        b[6] == 0x79 &&
        b[7] == 0x70) {
      return 'm4a'; // ftyp
    }
    if (b.length > 3 && b[0] == 0x4F && b[1] == 0x67 && b[2] == 0x67) {
      return 'ogg';
    }
    if (b.length > 3 && b[0] == 0x49 && b[1] == 0x44 && b[2] == 0x33) {
      return 'mp3';
    }
    if (b.length > 1 && b[0] == 0xFF && (b[1] & 0xE0) == 0xE0) {
      return 'mp3'; // MPEG frame sync بدون ID3
    }
    if (b.length > 3 &&
        b[0] == 0x52 &&
        b[1] == 0x49 &&
        b[2] == 0x46 &&
        b[3] == 0x46) {
      return 'wav';
    }
    return _ext;
  }

  // لو الرد JSON/نص (خطأ من السيرفر) مش صوت
  bool _looksLikeText(List<int> b) {
    if (b.isEmpty) return false;
    final first = b[0];
    return first == 0x7B || first == 0x5B || first == 0x3C; // { [ <
  }

  @override
  void initState() {
    super.initState();
    _posSub = _player.positionStream.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _stateSub = _player.playerStateStream.listen((s) {
      if (!mounted) return;
      if (s.processingState == ProcessingState.completed) {
        _player.pause();
        _player.seek(Duration.zero);
      }
      setState(
        () => _playing =
            s.playing && s.processingState != ProcessingState.completed,
      );
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    if (_current == _player) _current = null;
    _player.dispose();
    try {
      _tmp?.deleteSync();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) return _player.pause();
    try {
      if (!_loaded) {
        setState(() {
          _loading = true;
          _err = null;
        });

        final bytes = await widget.loader();
        debugPrint(
          'VOICE mime=${widget.voice.mimeType} len=${bytes.length} '
          'head=${bytes.take(16).toList()}',
        );

        if (bytes.isEmpty) throw Exception('empty audio');
        if (_looksLikeText(bytes)) {
          final msg = utf8.decode(
            bytes.take(200).toList(),
            allowMalformed: true,
          );
          throw Exception('server returned non-audio: $msg');
        }

        final ext = _detectExt(bytes);
        if (Platform.isIOS && ext == 'webm') {
          throw Exception('webm is not supported on iOS');
        }

        final dir = await getTemporaryDirectory();
        final f = File(
          '${dir.path}/cv_${DateTime.now().microsecondsSinceEpoch}.$ext',
        );
        await f.writeAsBytes(bytes, flush: true);
        _tmp = f;
        debugPrint('VOICE file=${f.path} ext=$ext');

        try {
          _dur = await _player.setFilePath(f.path);
        } catch (_) {
          try {
            f.deleteSync();
          } catch (_) {}
          _tmp = null;
          rethrow;
        }
        _loaded = true;
      }
      if (_current != null && _current != _player) await _current!.pause();
      _current = _player;
      _player.play();
    } catch (e, st) {
      debugPrint('VOICE ERROR: $e\n$st');
      final s = e.toString().toLowerCase();
      final missing =
          s.contains('404') ||
          s.contains('not found') ||
          s.contains('no longer available');
      if (mounted) {
        setState(
          () => _err = missing
              ? 'Audio file is no longer available'
              : 'Cannot play this audio',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _cycleSpeed() {
    _speed = _speed == 1 ? 1.5 : (_speed == 1.5 ? 2 : 1);
    _player.setSpeed(_speed);
    setState(() {});
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  bool _isRtl(String s) => RegExp(r'[\u0600-\u06FF]').hasMatch(s);

  @override
  Widget build(BuildContext context) {
    final t = LdTheme.of(context);
    final total =
        _dur ?? Duration(milliseconds: (widget.voice.duration * 1000).round());
    final maxMs = total.inMilliseconds == 0 ? 1 : total.inMilliseconds;
    final posSec = _pos.inMilliseconds / 1000;
    final tx = widget.voice.transcript;
    final hasTx = tx.any((s) => s.text.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.dark ? Colors.white10 : AppColors.navy.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_unsupported)
            Text(
              "This recording (webm) can't be played on iOS",
              style: TextStyle(fontSize: 12, color: t.sub),
            )
          else
            Row(
              children: [
                InkWell(
                  onTap: _loading ? null : _toggle,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                    ),
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.navy,
                            ),
                          )
                        : Icon(
                            _playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: AppColors.navy,
                          ),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      activeTrackColor: AppColors.gold,
                      thumbColor: AppColors.gold,
                    ),
                    child: Slider(
                      value: _pos.inMilliseconds.clamp(0, maxMs).toDouble(),
                      max: maxMs.toDouble(),
                      onChanged: _loaded
                          ? (v) =>
                                _player.seek(Duration(milliseconds: v.round()))
                          : null,
                    ),
                  ),
                ),
                Text(
                  '${_fmt(_pos)} / ${_fmt(total)}',
                  style: TextStyle(fontSize: 11, color: t.sub),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _cycleSpeed,
                  child: Text(
                    '${_speed}x'.replaceAll('.0x', 'x'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ],
            ),
          if (_err != null)
            Text(
              _err!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          if (hasTx) ...[
            InkWell(
              onTap: () => setState(() => _showTx = !_showTx),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.subtitles_rounded, size: 16, color: t.sub),
                    const SizedBox(width: 4),
                    Text(
                      _showTx ? 'Hide transcript' : 'Show transcript',
                      style: TextStyle(fontSize: 12, color: t.sub),
                    ),
                  ],
                ),
              ),
            ),
            if (_showTx)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  textDirection: _isRtl(widget.voice.fullTranscript)
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  children: [
                    for (final s in tx.where((s) => s.text.isNotEmpty))
                      GestureDetector(
                        onTap: _loaded
                            ? () => _player.seek(
                                Duration(
                                  milliseconds: (s.start * 1000).round(),
                                ),
                              )
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: (posSec >= s.start && posSec < s.end)
                                ? AppColors.gold.withOpacity(0.3)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            s.text,
                            style: const TextStyle(fontSize: 13, height: 1.4),
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
