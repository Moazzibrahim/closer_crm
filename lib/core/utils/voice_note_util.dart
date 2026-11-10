// ignore_for_file: deprecated_member_use, unused_local_variable
// voice_note_field.dart
// ويدجت تسجيل صوت قابلة لإعادة الاستخدام (stage sheet، comment sheet، ...).
// بتبلّغ الأب بالملف عن طريق onChanged، وبحالة التسجيل عن طريق onRecordingChanged.
//
// pubspec.yaml:  record: ^5.1.0  |  path_provider: ^2.1.0
// Android: <uses-permission android:name="android.permission.RECORD_AUDIO"/>
// iOS: NSMicrophoneUsageDescription في Info.plist
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceNoteField extends StatefulWidget {
  /// بيتنادى بالملف بعد ما التسجيل يخلص، وبـ null لو اتمسح.
  final ValueChanged<File?> onChanged;

  /// true وقت التسجيل (عشان الأب يقفل زرار الإرسال).
  final ValueChanged<bool>? onRecordingChanged;
  final bool enabled;

  const VoiceNoteField({
    super.key,
    required this.onChanged,
    this.onRecordingChanged,
    this.enabled = true,
  });

  @override
  State<VoiceNoteField> createState() => _VoiceNoteFieldState();
}

class _VoiceNoteFieldState extends State<VoiceNoteField> {
  final _rec = AudioRecorder();
  Timer? _timer;
  bool _recording = false;
  int _seconds = 0;
  File? _file;
  int _fileSeconds = 0;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _rec.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      if (!await _rec.hasPermission()) {
        setState(() => _error = 'Microphone permission is required');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
      setState(() {
        _error = null;
        _recording = true;
        _seconds = 0;
      });
      widget.onRecordingChanged?.call(true);
    } catch (_) {
      setState(() => _error = 'Could not start recording');
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    String? path;
    try {
      path = await _rec.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _recording = false;
      if (path != null) {
        _file = File(path);
        _fileSeconds = _seconds;
      }
    });
    widget.onRecordingChanged?.call(false);
    widget.onChanged(_file);
  }

  void _discard() {
    try {
      _file?.deleteSync();
    } catch (_) {}
    setState(() {
      _file = null;
      _fileSeconds = 0;
    });
    widget.onChanged(null);
  }

  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? AppColors.white : AppColors.textPrimary;
    final sub = dark ? Colors.white60 : AppColors.textSecondary;
    final border =
        dark ? AppColors.goldLight.withOpacity(0.15) : AppColors.border;
    final accent = dark ? AppColors.gold : AppColors.navy;
    const red = Color(0xFFEF4444);

    Widget body;
    if (_recording) {
      body = Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: BoxDecoration(
          color: red.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: red.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.fiber_manual_record_rounded, color: red, size: 16),
            const SizedBox(width: 8),
            Text(
              'Recording  ${_fmt(_seconds)}',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: text, fontSize: 14),
            ),
            const Spacer(),
            IconButton(
              onPressed: _stop,
              icon: const Icon(Icons.stop_circle_rounded, color: red, size: 32),
            ),
          ],
        ),
      );
    } else if (_file != null) {
      body = Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent),
        ),
        child: Row(
          children: [
            Icon(Icons.mic_rounded, color: accent, size: 20),
            const SizedBox(width: 8),
            Text(
              'Voice note  •  ${_fmt(_fileSeconds)}',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: text, fontSize: 14),
            ),
            const Spacer(),
            IconButton(
              onPressed: widget.enabled ? _discard : null,
              icon: const Icon(Icons.delete_outline_rounded, color: red),
            ),
          ],
        ),
      );
    } else {
      body = OutlinedButton.icon(
        onPressed: widget.enabled ? _start : null,
        icon: const Icon(Icons.mic_none_rounded),
        label: const Text('Record a voice note'),
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        body,
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_error!,
                style: const TextStyle(color: red, fontSize: 12.5)),
          ),
      ],
    );
  }
}