// chat_screen.dart — محادثة واحدة: رسائل، إرسال نص/ميديا/template، pin/archive/interest/note/assign

// ignore_for_file: unnecessary_null_comparison

import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/utils/dio_client.dart';
import 'package:flutter_application_1/features/messaging/data/messaging_model.dart';
import 'package:flutter_application_1/features/messaging/provider/messaging_provider.dart';
import 'package:flutter_application_1/features/messaging/provider/messaging_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import 'inbox_screen.dart' show fmtTime;

class _StickerSheet extends StatefulWidget {
  final MessagingService service;
  const _StickerSheet({required this.service});
  @override
  State<_StickerSheet> createState() => _StickerSheetState();
}

class _StickerSheetState extends State<_StickerSheet> {
  final _q = TextEditingController();
  late Future<({List<Map<String, dynamic>> rows, int? next})> _f = widget
      .service
      .giphy();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _q,
                decoration: const InputDecoration(
                  hintText: 'Search stickers',
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: (v) =>
                    setState(() => _f = widget.service.giphy(q: v)),
              ),
            ),
            Expanded(
              child: FutureBuilder(
                future: _f,
                builder: (_, s) {
                  if (s.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (s.hasError) return Center(child: Text('${s.error}'));
                  final rows = s.data!.rows;
                  return GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: rows.length,
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => Navigator.pop(context, rows[i]),
                      child: Image.network(
                        rows[i]['preview'].toString(),
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _abs(String? u) {
  if (u == null || u.isEmpty) return null;
  return u.startsWith('http')
      ? u
      : '${ApiConfig.baseUrl}/${u.replaceFirst(RegExp(r'^/'), '')}';
}

class ChatScreen extends StatefulWidget {
  final WaConversation conversation;
  const ChatScreen({super.key, required this.conversation});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late MessagingProvider _p;
  MessagingService get _svc => _p.service;

  late WaConversation _conv = widget.conversation;
  final List<WaMessage> _msgs = []; // الأقدم → الأحدث
  final _input = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<WaMessage>? _sub;
  bool _loading = true,
      _hasMore = false,
      _loadingOlder = false,
      _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _p = context.read<MessagingProvider>();
    _sub = _p.messageStream.listen(_onSocketMessage);
    _scroll.addListener(() {
      // القايمة reverse → maxScrollExtent = أقدم رسالة
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) {
        _loadOlder();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _input.dispose();
    _rec.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pickSticker() async {
    final row = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StickerSheet(service: _svc),
    );
    if (row == null) return;
    setState(() => _sending = true);
    await _guard(() async {
      final m = await _svc.sendMedia(
        _conv.id,
        type: 'sticker',
        url: row['preview'].toString(),
      );
      setState(() => _upsertMsg(m));
    });
    if (mounted) setState(() => _sending = false);
  }

  // بيستخدم live conv من الـ provider لو اتحدّثت (pin/window/...)
  void _syncConv() {
    final fresh = _p.conversations.where((c) => c.id == _conv.id).firstOrNull;
    if (fresh != null) _conv = fresh;
  }

  Future<void> _load() async {
    try {
      final r = await _svc.messages(_conv.id);
      _msgs
        ..clear()
        ..addAll(r.rows);
      _hasMore = r.hasMore;
      _error = null;
      _p.markRead(_conv.id);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore || _msgs.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final r = await _svc.messages(_conv.id, before: _msgs.first.at);
      _msgs.insertAll(0, r.rows);
      _hasMore = r.hasMore;
    } catch (_) {}
    if (mounted) setState(() => _loadingOlder = false);
  }

  void _onSocketMessage(WaMessage m) {
    if (m.conversationId != _conv.id || !mounted) return;
    setState(() {
      _upsertMsg(m);
      _syncConv();
    });
    if (!m.isOut) _p.markRead(_conv.id);
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _guard(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (mounted) _toast(e.toString());
    }
  }

  // ─────────────── send ───────────────
  Future<void> _sendText() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    await _guard(() async {
      final m = await _svc.sendText(_conv.id, text);
      _input.clear();
      setState(() => _upsertMsg(m));
    });
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _attach() async {
    final res = await FilePicker.pickFiles();
    if (res == null || res.isEmpty) return;

    final f = res.single;
    if (f.path == null) return;
    setState(() => _sending = true);
    await _guard(() async {
      final up = await _svc.upload(f.path!, f.name);
      final m = await _svc.sendMedia(
        _conv.id,
        type: up.type,
        url: up.url,
        fileName: up.fileName,
        caption: _input.text.trim(),
      );
      _input.clear();
      setState(() => _upsertMsg(m));
    });
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _pickTemplate() async {
    List<WaTemplate> list;
    try {
      list = await _svc.templates(_conv.id);
    } catch (e) {
      _toast(e.toString());
      return;
    }
    if (!mounted) return;
    final sent = await showModalBottomSheet<WaMessage>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TemplateSheet(
        templates: list,
        conversationId: _conv.id,
        service: _svc,
      ),
    );
    if (sent != null) setState(() => _upsertMsg(sent));
  }

  // ─────────────── menu actions ───────────────
  Future<void> _editNote() async {
    final ctrl = TextEditingController(text: _conv.note);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Internal note'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Not sent to the customer',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _guard(() async {
        await _svc.saveNote(_conv.id, ctrl.text.trim());
        final fresh = await _svc.conversation(_conv.id);
        _p.upsert(fresh);
        setState(() => _conv = fresh);
      });
    }
  }

  Future<void> _assign() async {
    final sales = _p.salesOptions;
    final id = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            title: Text(
              'Assign lead to…',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          for (final s in sales)
            ListTile(
              title: Text(s.label),
              onTap: () => Navigator.pop(context, s.id),
            ),
        ],
      ),
    );
    if (id == null) return;
    await _guard(() async {
      final name = await _svc.assign([_conv.id], id);
      _toast('Assigned to $name');
      _p.load();
    });
  }

  Future<void> _menu(String v) async {
    await _guard(() async {
      switch (v) {
        case 'pin':
          await _p.togglePin(_conv);
        case 'archive':
          await _p.toggleArchive(_conv);
          if (mounted) Navigator.pop(context);
          return;
        case 'interested':
          await _p.setInterest(
            _conv,
            _conv.interest == 'interested' ? null : 'interested',
          );
        case 'not_interested':
          await _p.setInterest(
            _conv,
            _conv.interest == 'not_interested' ? null : 'not_interested',
          );
        case 'note':
          await _editNote();
        case 'assign':
          await _assign();
      }
      if (mounted) setState(_syncConv);
    });
  }

  Future<void> _deleteMsg(WaMessage m) async {
    final me = _p.me!;
    final scope = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (me.canDeleteForMe)
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('Delete for me'),
                onTap: () => Navigator.pop(context, 'me'),
              ),
            if (me.canDeleteForAll)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete for everyone'),
                onTap: () => Navigator.pop(context, 'all'),
              ),
          ],
        ),
      ),
    );
    if (scope == null) return;
    await _guard(() async {
      await _svc.deleteMessage(m.id, scope);
      setState(() => _msgs.removeWhere((e) => e.id == m.id));
    });
  }

  // يضيف الرسالة أو يحدّثها لو موجودة (بالـ id) → مفيش تكرار
  void _upsertMsg(WaMessage m) {
    final i = _msgs.indexWhere((e) => e.id == m.id);
    if (i >= 0) {
      _msgs[i] = m;
    } else {
      _msgs.add(m);
    }
  }

  // ─────────────── build ───────────────
  @override
  Widget build(BuildContext context) {
    context
        .watch<MessagingProvider>(); // يتحدّث لما الـ conv تتغير من الـ socket
    _syncConv();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final me = _p.me!;

    return Scaffold(
      backgroundColor: dark ? AppColors.navy : AppColors.background,
      appBar: AppBar(
        backgroundColor: dark ? AppColors.navyLight : AppColors.white,
        foregroundColor: dark ? AppColors.goldLight : AppColors.navy,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _conv.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              [
                if (_conv.stage.isNotEmpty) _conv.stage,
                if (_conv.salesName.isNotEmpty) _conv.salesName,
              ].join(' · '),
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _menu,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'pin',
                child: Text(_conv.pinned ? 'Unpin' : 'Pin'),
              ),
              PopupMenuItem(
                value: 'archive',
                child: Text(_conv.archived ? 'Unarchive' : 'Archive'),
              ),
              PopupMenuItem(
                value: 'interested',
                child: Text(
                  _conv.interest == 'interested'
                      ? 'Clear "Interested"'
                      : 'Mark interested',
                ),
              ),
              PopupMenuItem(
                value: 'not_interested',
                child: Text(
                  _conv.interest == 'not_interested'
                      ? 'Clear "Not interested"'
                      : 'Mark not interested',
                ),
              ),
              const PopupMenuItem(value: 'note', child: Text('Internal note')),
              if (me.canAssign && _p.salesOptions.isNotEmpty)
                const PopupMenuItem(
                  value: 'assign',
                  child: Text('Assign to sales'),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_conv.note.isNotEmpty)
            Container(
              width: double.infinity,
              color: AppColors.gold.withOpacity(0.15),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                '📝 ${_conv.note}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          Expanded(child: _messages(dark)),
          _composer(dark),
        ],
      ),
    );
  }

  final _rec = AudioRecorder();
  bool _recording = false;

  Future<void> _toggleRecord() async {
    if (!_recording) {
      if (!await _rec.hasPermission()) {
        _toast('Microphone permission denied');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/vn_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      setState(() => _recording = true);
      return;
    }
    final path = await _rec.stop();
    setState(() => _recording = false);
    if (path == null) return;
    setState(() => _sending = true);
    await _guard(() async {
      final up = await _svc.upload(path, 'voice.m4a');
      final m = await _svc.sendMedia(
        _conv.id,
        type: 'audio',
        url: up.url,
        fileName: up.fileName,
        voice: true,
      );
      setState(() => _upsertMsg(m));
    });
    if (mounted) setState(() => _sending = false);
  }

  Widget _messages(bool dark) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final rev = _msgs.reversed.toList();
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.all(12),
      itemCount: rev.length + (_loadingOlder ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= rev.length) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final m = rev[i];
        return _Bubble(
          m: m,
          dark: dark,
          onLongPress: (_p.me!.canDeleteForMe || _p.me!.canDeleteForAll)
              ? () => _deleteMsg(m)
              : null,
        );
      },
    );
  }

  Widget _composer(bool dark) {
    // الـ 24h window مقفول → نص حر مش مسموح، template بس
    if (!_conv.windowOpen) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _pickTemplate,
              icon: const Icon(Icons.description_outlined),
              label: const Text('24h window closed — send a template'),
            ),
          ),
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        color: dark ? AppColors.navyLight : AppColors.white,
        child: Row(
          children: [
            IconButton(
              onPressed: _sending ? null : _attach,
              icon: const Icon(Icons.attach_file_rounded),
            ),
            IconButton(
              onPressed: _sending ? null : _pickTemplate,
              icon: const Icon(Icons.description_outlined),
            ),
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 5,
                maxLength: 4000,
                decoration: const InputDecoration(
                  hintText: 'Message',
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              onPressed: _sending ? null : _sendText,
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, color: AppColors.gold),
            ),
            if (_p.me!.gifs)
              IconButton(
                onPressed: _sending ? null : _pickSticker,
                icon: const Icon(Icons.emoji_emotions_outlined),
              ),
            IconButton(
              onPressed: _sending ? null : _toggleRecord,
              icon: Icon(
                _recording ? Icons.stop_circle : Icons.mic_none_rounded,
                color: _recording ? Colors.red : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoicePlayer extends StatefulWidget {
  final String url;
  final Color color;
  const _VoicePlayer({required this.url, required this.color});
  @override
  State<_VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<_VoicePlayer> {
  static AudioPlayer? _current; // مشغّل واحد بس في نفس الوقت
  final _player = AudioPlayer();
  StreamSubscription? _posSub, _stateSub;
  Duration _pos = Duration.zero;
  Duration? _dur;
  bool _loaded = false, _loading = false, _playing = false;
  String? _err;
  File? _tmp;

  // اكتشاف الصيغة الحقيقية من أول bytes (نفس منطق VoiceBubble)
  String _detectExt(List<int> b) {
    if (b.length > 4 &&
        b[0] == 0x1A &&
        b[1] == 0x45 &&
        b[2] == 0xDF &&
        b[3] == 0xA3)
      return 'webm';
    if (b.length > 8 &&
        b[4] == 0x66 &&
        b[5] == 0x74 &&
        b[6] == 0x79 &&
        b[7] == 0x70)
      return 'm4a';
    if (b.length > 3 && b[0] == 0x4F && b[1] == 0x67 && b[2] == 0x67)
      return 'ogg';
    if (b.length > 3 && b[0] == 0x49 && b[1] == 0x44 && b[2] == 0x33)
      return 'mp3';
    if (b.length > 1 && b[0] == 0xFF && (b[1] & 0xE0) == 0xE0) return 'mp3';
    if (b.length > 3 &&
        b[0] == 0x52 &&
        b[1] == 0x49 &&
        b[2] == 0x46 &&
        b[3] == 0x46)
      return 'wav';
    return 'm4a';
  }

  bool _looksLikeText(List<int> b) =>
      b.isNotEmpty && (b[0] == 0x7B || b[0] == 0x5B || b[0] == 0x3C);

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

        // نزّل الـ bytes بالـ Dio client (فيه الـ token + x-device-id)
        final r = await DioClient.instance.dio.get<List<int>>(
          widget.url,
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 60), // Render cold start
          ),
        );
        final bytes = r.data ?? const <int>[];
        debugPrint(
          'CHAT VOICE len=${bytes.length} head=${bytes.take(16).toList()}',
        );

        if (bytes.isEmpty) throw Exception('empty audio');
        if (_looksLikeText(bytes)) {
          throw Exception('server returned non-audio');
        }

        final ext = _detectExt(bytes);
        final dir = await getTemporaryDirectory();
        final f = File(
          '${dir.path}/chat_${DateTime.now().microsecondsSinceEpoch}.$ext',
        );
        await f.writeAsBytes(bytes, flush: true);
        _tmp = f;

        _dur = await _player.setFilePath(f.path);
        _loaded = true;
      }
      if (_current != null && _current != _player) await _current!.pause();
      _current = _player;
      _player.play();
    } catch (e, st) {
      debugPrint('CHAT VOICE ERROR: $e\n$st');
      if (mounted) setState(() => _err = 'Cannot play this audio');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final total = _dur;
    final maxMs = (total?.inMilliseconds ?? 0) == 0 ? 1 : total!.inMilliseconds;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _loading
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      _playing ? Icons.pause_circle : Icons.play_circle,
                      color: widget.color,
                      size: 34,
                    ),
                    onPressed: _toggle,
                  ),
            SizedBox(
              width: 120,
              child: Slider(
                value: _pos.inMilliseconds.clamp(0, maxMs).toDouble(),
                max: maxMs.toDouble(),
                activeColor: widget.color,
                onChanged: _loaded
                    ? (v) => _player.seek(Duration(milliseconds: v.round()))
                    : null,
              ),
            ),
            Text(
              total == null ? '' : '${_fmt(_pos)}/${_fmt(total)}',
              style: TextStyle(fontSize: 10, color: widget.color),
            ),
          ],
        ),
        if (_err != null)
          Text(
            _err!,
            style: const TextStyle(fontSize: 11, color: Colors.redAccent),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final WaMessage m;
  final bool dark;
  final VoidCallback? onLongPress;
  const _Bubble({required this.m, required this.dark, this.onLongPress});

  IconData? get _statusIcon {
    switch (m.status) {
      case 'sent':
        return Icons.done_rounded;
      case 'delivered':
      case 'read':
        return Icons.done_all_rounded;
      case 'failed':
        return Icons.error_outline_rounded;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final out = m.isOut;
    final bg = out
        ? AppColors.navy
        : (dark ? AppColors.navyLight : AppColors.white);
    final fg = out || dark ? Colors.white : AppColors.textPrimary;

    String body = m.text;
    if (m.isDeleted) {
      body = '🚫 This message was deleted';
    } else if (body.isEmpty) {
      body = switch (m.type) {
        'image' => '📷 Photo',
        'video' => '🎥 Video',
        'audio' => m.voice ? '🎤 Voice note' : '🎵 Audio',
        'file' => '📎 ${m.mediaName ?? 'File'}',
        'sticker' => 'Sticker',
        'location' => '📍 Location',
        'template' => '📋 ${m.templateName}',
        _ => '',
      };
    }

    final url = m.isDeleted ? null : _abs(m.mediaUrl);
    Widget content = Text(body, style: TextStyle(color: fg));
    if (url != null) {
      switch (m.type) {
        case 'sticker':
        case 'gif':
          content = Image.network(
            url,
            width: 140,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Text(body, style: TextStyle(color: fg)),
          );
        case 'image':
          content = ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              url,
              width: 220,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Text(body, style: TextStyle(color: fg)),
            ),
          );
        case 'audio':
          content = _VoicePlayer(url: url, color: fg);
      }
    }

    return Align(
      alignment: out ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: out ? null : Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (out && m.userName.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    m.userName,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

              // ✅ كان هنا Text(body) — لازم نعرض الـ content (صورة/ستيكر/فويس)
              content,

              // لو الميديا ليها caption نعرضه تحتها (غير كده الـ content أصًال نص)
              if (url != null &&
                  m.text.isNotEmpty &&
                  const {'image', 'sticker', 'gif', 'audio'}.contains(m.type))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(m.text, style: TextStyle(color: fg)),
                ),

              const SizedBox(height: 2),
              // ... باقي الـ Row بتاع الوقت والـ status زي ما هو
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fmtTime(m.at),
                    style: TextStyle(fontSize: 10, color: fg.withOpacity(0.6)),
                  ),
                  if (out && _statusIcon != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _statusIcon,
                      size: 14,
                      color: m.status == 'read'
                          ? Colors.lightBlueAccent
                          : (m.status == 'failed'
                                ? Colors.redAccent
                                : fg.withOpacity(0.6)),
                    ),
                  ],
                ],
              ),
              if (m.status == 'failed' && m.error.isNotEmpty)
                Text(
                  m.error,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 10),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────── Template picker ───────────────
class _TemplateSheet extends StatefulWidget {
  final List<WaTemplate> templates;
  final String conversationId;
  final MessagingService service;
  const _TemplateSheet({
    required this.templates,
    required this.conversationId,
    required this.service,
  });
  @override
  State<_TemplateSheet> createState() => _TemplateSheetState();
}

class _TemplateSheetState extends State<_TemplateSheet> {
  WaTemplate? _sel;
  List<TextEditingController> _body = [], _head = [];
  final _media = TextEditingController();
  bool _busy = false;

  void _select(WaTemplate t) {
    setState(() {
      _sel = t;
      _body = List.generate(t.bodyVars, (_) => TextEditingController());
      _head = List.generate(t.headerVars, (_) => TextEditingController());
    });
  }

  Future<void> _send() async {
    final t = _sel!;
    setState(() => _busy = true);
    try {
      final m = await widget.service.sendTemplate(
        widget.conversationId,
        t,
        bodyVars: _body.map((c) => c.text.trim()).toList(),
        headerVars: _head.map((c) => c.text.trim()).toList(),
        mediaUrl: _media.text.trim(),
      );
      if (mounted) Navigator.pop(context, m);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _sel;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: t == null
            ? (widget.templates.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No approved templates'),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final x in widget.templates)
                          ListTile(
                            title: Text(x.name),
                            subtitle: Text(
                              x.bodyText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(x.language),
                            onTap: () => _select(x),
                          ),
                      ],
                    ))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(t.bodyText),
                    const SizedBox(height: 12),
                    for (int i = 0; i < _head.length; i++)
                      TextField(
                        controller: _head[i],
                        decoration: InputDecoration(
                          labelText: 'Header variable ${i + 1}',
                        ),
                      ),
                    for (int i = 0; i < _body.length; i++)
                      TextField(
                        controller: _body[i],
                        decoration: InputDecoration(
                          labelText: 'Variable {{${i + 1}}}',
                        ),
                      ),
                    if (t.needsMedia)
                      TextField(
                        controller: _media,
                        decoration: const InputDecoration(
                          labelText: 'Media URL (header)',
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _sel = null),
                          child: const Text('Back'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: _busy ? null : _send,
                          child: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Send'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
