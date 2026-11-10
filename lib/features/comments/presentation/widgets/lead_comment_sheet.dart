// ignore_for_file: deprecated_member_use, depend_on_referenced_packages
// lead_comment_sheet.dart
// شيت إضافة كومنت على الـ Lead: نص أو صوت (أو الاتنين) + موعد متابعة
// + اختيار stage (tiles) + تفاصيل Done Deal لو الـ stage من نوع Deal.
//
// pubspec.yaml:
//   record: ^5.1.0
//   path_provider: ^2.1.0
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/widgets/lead_action_sheet.dart';
import 'package:flutter_application_1/features/comments/data/last_comment_model.dart';
import 'package:flutter_application_1/features/comments/presentation/widgets/last_comment_card.dart';
import 'package:flutter_application_1/features/comments/providers/comments_service.dart';
// عشان نستخدم StageOpt (id, name, color, isDeal)
// عدّل المسار حسب مكان lead_action_sheet.dart عندك
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// بيرجّع true لو الكومنت اتضاف.
Future<bool> showLeadCommentSheet(
  BuildContext context, {
  required String leadId,
  required String leadName,
  LastComment? lastComment,
  bool canSkipStage = false, // 👈 admin بس
  String? currentStageId, // لو null/فاضي: الـ stage إجباري
  List<StageOpt> stages = const [],
  List<({String id, String name})> projects = const [], // لـ Done Deal
}) async {
  final added = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CommentSheet(
      leadId: leadId,
      leadName: leadName,
      lastComment: lastComment,
      currentStageId: currentStageId,
      canSkipStage: canSkipStage, // 👈
      stages: stages,
      projects: projects,
    ),
  );
  return added ?? false;
}

class _CommentSheet extends StatefulWidget {
  final String leadId, leadName;
  final LastComment? lastComment;
  final String? currentStageId;
  final bool canSkipStage; // 👈
  final List<StageOpt> stages;
  final List<({String id, String name})> projects;
  const _CommentSheet({
    required this.leadId,
    required this.leadName,
    required this.stages,
    required this.projects,
    this.currentStageId,
    this.canSkipStage = false, // 👈
    this.lastComment,
  });

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final _svc = CommentsService();
  final _text = TextEditingController();
  final _rec = AudioRecorder();

  // voice
  bool _recording = false;
  int _seconds = 0;
  Timer? _timer;
  File? _voice;
  int _voiceSeconds = 0;

  // schedule + stage
  DateTime? _scheduledAt;
  StageOpt? _stage;

  // Done Deal
  String? _projectId;
  final _price = TextEditingController();
  final _unitType = TextEditingController();
  final _unitNumber = TextEditingController();
  final _commission = TextEditingController();
  final _cashback = TextEditingController();
  final _paid = TextEditingController();
  DateTime? _closedAt; // null = دلوقتي

  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _rec.dispose();
    _text.dispose();
    for (final c in [
      _price,
      _unitType,
      _unitNumber,
      _commission,
      _cashback,
      _paid,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Voice ──
  Future<void> _startRecording() async {
    try {
      if (!await _rec.hasPermission()) {
        setState(() => _error = 'Microphone permission is required');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/comment_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
      setState(() {
        _error = null;
        _recording = true;
        _seconds = 0;
      });
    } catch (e) {
      setState(() => _error = 'Could not start recording');
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    try {
      final path = await _rec.stop();
      if (!mounted) return;
      setState(() {
        _recording = false;
        if (path != null) {
          _voice = File(path);
          _voiceSeconds = _seconds;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _recording = false);
    }
  }

  void _discardVoice() {
    try {
      _voice?.deleteSync();
    } catch (_) {}
    setState(() {
      _voice = null;
      _voiceSeconds = 0;
    });
  }

  Future<void> _pickClosedAt() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _closedAt ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _closedAt = d);
  }

  // ── Validation ──
  num? _n(TextEditingController c) => num.tryParse(c.text.trim());
  bool get _isDeal => _stage?.isDeal == true;

  // الليد ملوش stage → الـ Guide بيطلب stage مع أول كومنت (وإلا 400)
  bool get _noStage => (widget.currentStageId ?? '').isEmpty;

  bool get _changing =>
      _stage != null && (_isDeal || _stage!.id != widget.currentStageId);

  // الـ Guide: unitPrice / unitNumber / companyCommissionRatio / cashbackRatio مطلوبين
  bool get _dealValid {
    final price = _n(_price), c = _n(_commission), b = _n(_cashback);
    return _projectId != null &&
        price != null &&
        price >= 0 &&
        _unitNumber.text.trim().isNotEmpty &&
        c != null &&
        c >= 0 &&
        c <= 100 &&
        b != null &&
        b >= 0 &&
        b <= 100;
  }

  bool get _hasContent => _text.text.trim().isNotEmpty || _voice != null;
  bool get _stageOk => !_noStage || _stage != null;

  bool get _canSend =>
      !_recording &&
      !_sending &&
      (_hasContent || _changing || _scheduledAt != null) &&
      _stageOk &&
      // 👈 غير الـ admin: لازم يغيّر الـ stage فعلاً عشان يبعت
      (widget.canSkipStage || _changing) &&
      (!_isDeal || _dealValid);

  Map<String, dynamic>? _dealBody() {
    if (!_isDeal) return null;
    return {
      'project': _projectId,
      'unitPrice': _n(_price),
      if (_unitType.text.trim().isNotEmpty) 'unitType': _unitType.text.trim(),
      'unitNumber': _unitNumber.text.trim(),
      'companyCommissionRatio': _n(_commission),
      'cashbackRatio': _n(_cashback),
      if (_n(_paid) != null) 'amountPaid': _n(_paid),
      if (_closedAt != null) 'closedAt': _closedAt!.toUtc().toIso8601String(),
    };
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final init = _scheduledAt ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: init.isBefore(now) ? now : init,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? now),
    );
    if (t == null) return;
    setState(
      () => _scheduledAt = DateTime(d.year, d.month, d.day, t.hour, t.minute),
    );
  }

  // ── Send ──
  Future<void> _send() async {
    if (!_canSend) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final text = _text.text.trim();
    final changing = _changing;
    try {
      // طلب واحد: السيرفر يغيّر الـ stage الأول، ولو فشل الكومنت مش بيتحفظ
      if (_voice != null) {
        await _svc.addVoiceComment(
          widget.leadId,
          voiceFile: _voice!,
          text: text.isEmpty ? null : text,
          scheduledAt: _scheduledAt,
          stageId: changing ? _stage!.id : null,
          deal: changing ? _dealBody() : null,
        );
      } else {
        await _svc.addComment(
          widget.leadId,
          text: text,
          scheduledAt: _scheduledAt,
          stageId: changing ? _stage!.id : null,
          deal: changing ? _dealBody() : null,
        );
      }

      try {
        _voice?.deleteSync();
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.toString();
      });
    }
  }

  // ── UI ──
  String _fmtDuration(int s) =>
      '${(s ~/ 60)}:${(s % 60).toString().padLeft(2, '0')}';

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtSchedule(DateTime d) =>
      '${_fmtDate(d)}  ${TimeOfDay.fromDateTime(d).format(context)}';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? AppColors.navyLight : AppColors.white;
    final text = dark ? AppColors.white : AppColors.textPrimary;
    final sub = dark ? Colors.white60 : AppColors.textSecondary;
    final border = dark
        ? AppColors.goldLight.withOpacity(0.15)
        : AppColors.border;
    final accent = dark ? AppColors.gold : AppColors.navy;
    final onAccent = dark ? AppColors.navy : Colors.white;
    final tint = dark ? Colors.white.withOpacity(0.05) : AppColors.background;
    const red = Color(0xFFEF4444);
    final media = MediaQuery.of(context);

    OutlineInputBorder ob(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );
    InputDecoration deco(String hint, {IconData? icon}) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: sub.withOpacity(0.8), fontSize: 14),
      prefixIcon: icon == null ? null : Icon(icon, color: sub, size: 20),
      filled: true,
      fillColor: tint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: ob(border),
      enabledBorder: ob(border),
      focusedBorder: ob(accent, 1.5),
    );

    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(bottom: 7, top: 14),
      child: Text(
        s,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );

    Widget tile({
      required IconData icon,
      required String value,
      required VoidCallback onTap,
      VoidCallback? onClear,
    }) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: sub),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: text,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded, size: 18, color: sub),
              )
            else
              Icon(Icons.chevron_right_rounded, color: sub),
          ],
        ),
      ),
    );

    // ── stage tile ──
    Widget stageTile(StageOpt s) {
      final selected = _stage?.id == s.id;
      final current = widget.currentStageId == s.id;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _sending
            ? null
            : () {
                HapticFeedback.selectionClick();
                setState(() {
                  // لو الـ lead عنده stage: الضغط تاني بيلغي الاختيار (Keep current)
                  _stage = selected ? null : s;
                });
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? s.color.withOpacity(0.10) : tint,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? s.color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: s.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  s.name,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: text,
                  ),
                ),
              ),
              if (current) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: sub.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'CURRENT',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: sub,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? s.color : Colors.transparent,
                  border: Border.all(
                    color: selected ? s.color : sub.withOpacity(0.5),
                    width: 1.6,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      );
    }

    // ── deal text field ──
    Widget dealField(
      TextEditingController c,
      String lbl,
      String hint, {
      bool number = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              lbl,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: text,
              ),
            ),
          ),
          TextField(
            controller: c,
            enabled: !_sending,
            onChanged: (_) => setState(() {}),
            keyboardType: number
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            inputFormatters: number
                ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                : null,
            style: TextStyle(color: text, fontSize: 14.5),
            cursorColor: accent,
            decoration: deco(hint),
          ),
        ],
      ),
    );

    // ── voice row ──
    Widget voiceRow() {
      if (_recording) {
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: BoxDecoration(
            color: red.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: red.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.fiber_manual_record_rounded,
                color: red,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Recording  ${_fmtDuration(_seconds)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: text,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _stopRecording,
                icon: const Icon(
                  Icons.stop_circle_rounded,
                  color: red,
                  size: 32,
                ),
              ),
            ],
          ),
        );
      }
      if (_voice != null) {
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
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
                'Voice note  •  ${_fmtDuration(_voiceSeconds)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: text,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _sending ? null : _discardVoice,
                icon: const Icon(Icons.delete_outline_rounded, color: red),
              ),
            ],
          ),
        );
      }
      return OutlinedButton.icon(
        onPressed: _sending ? null : _startRecording,
        icon: const Icon(Icons.mic_none_rounded),
        label: const Text('Record a voice note'),
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }

    // final btnLabel = !_hasContent
    //     ? 'Write or record a comment'
    //     : (_isDeal && !_dealValid)
    //     ? 'Fill the deal details'
    //     : (_stage != null && _stage!.id != widget.currentStageId)
    //     ? 'Add comment & move to ${_stage!.name}'
    //     : 'Add comment';

    // final btnLabel = (_noStage && _stage == null)
    //     ? 'Choose a stage'
    //     : !(_hasContent || _changing || _scheduledAt != null)
    //     ? 'Write, record or pick a stage'
    //     : (_isDeal && !_dealValid)
    //     ? 'Fill the deal details'
    //     : _changing
    //     ? (_hasContent
    //           ? 'Add comment & move to ${_stage!.name}'
    //           : 'Move to ${_stage!.name}')
    //     : 'Add comment';

    final btnLabel = (_noStage && _stage == null)
        ? 'Choose a stage'
        : (!widget.canSkipStage && !_changing)
        ? 'Choose a new stage' // 👈
        : !(_hasContent || _changing || _scheduledAt != null)
        ? 'Write, record or pick a stage'
        : (_isDeal && !_dealValid)
        ? 'Fill the deal details'
        : _changing
        ? (_hasContent
              ? 'Add comment & move to ${_stage!.name}'
              : 'Move to ${_stage!.name}')
        : 'Add comment';
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: sub.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add comment',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.leadName,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: sub,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.lastComment != null) ...[
                          label('Last comment'),
                          LastCommentCard(
                            comment: widget.lastComment!,
                            leadId: widget.leadId,
                          ),
                        ],
                        label('Comment'),
                        TextField(
                          controller: _text,
                          onChanged: (_) => setState(() {}),
                          enabled: !_sending,
                          minLines: 3,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(color: text, fontSize: 14.5),
                          cursorColor: accent,
                          decoration: deco(
                            'Write a comment…',
                            icon: Icons.sticky_note_2_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
                        voiceRow(),
                        // ── Stages ──
                        if (widget.stages.isNotEmpty) ...[
                          // label('Change stage (optional)'),
                          label(
                            widget.canSkipStage
                                ? 'Change stage (optional)'
                                : 'Change stage *',
                          ), // 👈
                          for (final s in widget.stages) ...[
                            stageTile(s),
                            const SizedBox(height: 8),
                          ],
                        ],
                        // ── Stage date (يظهر بس لما يكون فيه stage متحدد) ──
                        // ── Stage date / follow-up (scheduledAt) ──
                        label(
                          _changing
                              ? 'Stage date / follow-up'
                              : 'Follow-up date (optional)',
                        ),
                        tile(
                          icon: Icons.event_available_rounded,
                          value: _scheduledAt == null
                              ? (_changing ? 'Pick a date' : 'None')
                              : _fmtSchedule(_scheduledAt!),
                          onTap: _pickSchedule,
                          onClear: _scheduledAt == null
                              ? null
                              : () => setState(() => _scheduledAt = null),
                        ),
                        if (_changing && !_isDeal && _scheduledAt == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Required unless the stage is final (e.g. Not Interested)',
                              style: TextStyle(fontSize: 11.5, color: sub),
                            ),
                          ),
                        // ── Done Deal ──
                        if (_isDeal) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Deal details',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: text,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Text(
                              'Project *',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: text,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DropdownButtonFormField<String>(
                              value: _projectId,
                              isExpanded: true,
                              dropdownColor: surface,
                              style: TextStyle(color: text, fontSize: 14.5),
                              decoration: deco(
                                widget.projects.isEmpty
                                    ? 'No projects loaded'
                                    : 'Select project',
                                icon: Icons.apartment_rounded,
                              ),
                              items: [
                                for (final pr in widget.projects)
                                  DropdownMenuItem(
                                    value: pr.id,
                                    child: Text(
                                      pr.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: _sending
                                  ? null
                                  : (v) => setState(() => _projectId = v),
                            ),
                          ),
                          dealField(
                            _price,
                            'Unit price *',
                            '2000000',
                            number: true,
                          ),
                          dealField(_unitType, 'Unit type', '3BR / Apartment'),
                          dealField(_unitNumber, 'Unit number *', 'B-305'),
                          dealField(
                            _commission,
                            'Company commission % *',
                            '3',
                            number: true,
                          ),
                          dealField(
                            _cashback,
                            'Cashback % *',
                            '2',
                            number: true,
                          ),
                          dealField(
                            _paid,
                            'Amount paid',
                            '100000',
                            number: true,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Text(
                              'Closed at',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: text,
                              ),
                            ),
                          ),
                          tile(
                            icon: Icons.event_rounded,
                            value: _closedAt == null
                                ? 'Now'
                                : _fmtDate(_closedAt!),
                            onTap: _pickClosedAt,
                            onClear: _closedAt == null
                                ? null
                                : () => setState(() => _closedAt = null),
                          ),
                        ],

                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(color: red, fontSize: 12.5),
                          ),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _canSend ? _send : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: onAccent,
                      disabledBackgroundColor: accent.withOpacity(0.18),
                      disabledForegroundColor: sub,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _sending
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: onAccent,
                            ),
                          )
                        : Text(
                            btnLabel,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
