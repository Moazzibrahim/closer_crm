// ignore_for_file: unused_element_parameter, deprecated_member_use, unnecessary_underscores

// lead action sheet
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/features/auth/providers/auth_service.dart';
import 'package:flutter_application_1/features/crud/data/users_model.dart';
import 'package:flutter_application_1/features/crud/providers/users_lookup_service.dart';
import 'package:flutter_application_1/features/leads/providers/leads_service.dart';

// ─────────────────────────────────────────────
//  lead_action_sheet.dart
//    showAssignSheet        → Assign as a salesman / to team leader (multi-select)
//    showChangeStageSheet   → اختيار stage جديد + كومنت (+ Done Deal + خيارات الـ Admin)
//    showEditLeadSheet      → تعديل بيانات lead واحد
//    showDeleteLeadsDialog  → تأكيد الحذف (soft delete → Leads Trash)
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
//  Models
// ─────────────────────────────────────────────
class LeadPerson {
  final String id, name, subtitle;
  const LeadPerson(this.id, this.name, this.subtitle);

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    final a = parts.first.isNotEmpty ? parts.first[0] : '';
    final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (a + b).toUpperCase();
  }
}

/// stage جاية من الـ API
class StageOpt {
  final String id, name;
  final Color color;
  final bool isDeal; // الـ stage من نوع Done Deal
  const StageOpt(this.id, this.name, this.color, {this.isDeal = false});
}

enum AssignTarget { salesman, teamLeader }

class AssignResult {
  final AssignTarget target;
  final List<LeadPerson> people;
  final bool replace; // true = Replace current, false = Add to current
  final bool clearHistory; // Admin بس
  final bool resetCreationDate; // Admin بس
  final DateTime? creationDate; // بيتستخدم لو resetCreationDate = true
  final StageOpt? stage; // 👈 جديد

  const AssignResult({
    required this.target,
    required this.people,
    required this.replace,
    this.clearHistory = false,
    this.resetCreationDate = false,
    this.creationDate,
    this.stage,
  });

  String get names => people.map((p) => p.name).join(', ');
  List<String> get salesIds => people.map((p) => p.id).toList();
}

class StageChange {
  final String stageId, stage, note; // stage = الاسم للعرض
  final Map<String, dynamic>? deal; // بس لو Done Deal
  final File? voice; // كومنت صوتي (اختياري لو فيه note)
  final DateTime? stageDate; // تاريخ ووقت الـ stage (اختياري، null = دلوقتي)
  final DateTime? scheduledAt; // موعد المتابعة

  const StageChange({
    required this.stageId,
    required this.stage,
    required this.note, // ممكن يبقى فاضي لو فيه voice
    this.voice,
    this.stageDate,
    this.scheduledAt,
    this.deal,
  });
}

class LeadEditData {
  final String id, name, phoneCountryCode, phone;
  final String? email, notes;
  const LeadEditData({
    required this.id,
    required this.name,
    required this.phoneCountryCode,
    required this.phone,
    this.email,
    this.notes,
  });
}

String _leadsLabel(int n) => n == 1 ? '1 lead' : '$n leads';

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ─────────────────────────────────────────────
//  Public entry points
// ─────────────────────────────────────────────
Future<T?> _showSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}

Future<AssignResult?> showAssignSheet(
  BuildContext context, {
  required int count,
  bool showHistoryOptions = false,
  List<String> currentIds = const [],
  List<StageOpt> stages = const [], // 👈
  bool allowTeamLeader = true, // false للتيم ليدر
  String? teamOwnerId, // null = كل اليوزرز (أدمن)
  bool teamOwnerIsManager = false,
  bool allowResetCreationDate = true,
  String? teamOwnerName,
  Map<String, String> currentNames = const {},
  bool allowAddToCurrent = true, // 👈 Add to current للأدمن بس
}) {
  return _showSheet<AssignResult>(
    context,
    (_) => _AssignSheet(
      count: count,
      showHistoryOptions: showHistoryOptions,
      currentIds: currentIds,
      stages: stages, // 👈
      allowTeamLeader: allowTeamLeader,
      teamOwnerId: teamOwnerId,
      teamOwnerIsManager: teamOwnerIsManager,
      allowResetCreationDate: allowResetCreationDate,
      teamOwnerName: teamOwnerName,
      currentNames: currentNames,
      allowAddToCurrent: allowAddToCurrent, // 👈
    ),
  );
}

Future<StageChange?> showChangeStageSheet(
  BuildContext context, {
  required int count,
  required List<StageOpt> stages,
  String? currentStageId, // بس لو lead واحد متحدد
  List<({String id, String name})> projects = const [], // لـ Done Deal
}) {
  return _showSheet<StageChange>(
    context,
    (_) => _StageSheet(
      count: count,
      stages: stages,
      currentStageId: currentStageId,
      projects: projects,
    ),
  );
}

Future<bool> showEditLeadSheet(
  BuildContext context, {
  required LeadEditData lead,
}) async {
  final saved = await _showSheet<bool>(
    context,
    (_) => _EditLeadSheet(lead: lead),
  );
  return saved ?? false;
}

Future<bool> showDeleteLeadsDialog(
  BuildContext context, {
  required int count,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (_) => _DeleteDialog(count: count),
  );
  return ok ?? false;
}

// ─────────────────────────────────────────────
//  Palette helper
// ─────────────────────────────────────────────
class _Pal {
  final bool dark;
  const _Pal(this.dark);

  factory _Pal.of(BuildContext context) =>
      _Pal(Theme.of(context).brightness == Brightness.dark);

  Color get surface => dark ? AppColors.navyLight : AppColors.white;
  Color get text => dark ? AppColors.white : AppColors.textPrimary;
  Color get sub => dark ? Colors.white60 : AppColors.textSecondary;
  Color get border =>
      dark ? AppColors.goldLight.withOpacity(0.15) : AppColors.border;
  Color get accent => dark ? AppColors.gold : AppColors.navy;
  Color get onAccent => dark ? AppColors.navy : Colors.white;
  Color get tint =>
      dark ? Colors.white.withOpacity(0.05) : AppColors.background;
}

const Color _red = Color(0xFFEF4444);

InputDecoration _fieldDecoration(_Pal p, {String? hint, IconData? icon}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c, width: w),
  );

  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: p.sub.withOpacity(0.8), fontSize: 14),
    prefixIcon: icon == null ? null : Icon(icon, color: p.sub, size: 20),
    filled: true,
    fillColor: p.tint,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(p.border),
    enabledBorder: border(p.border),
    focusedBorder: border(p.accent, 1.5),
    errorBorder: border(_red),
    focusedErrorBorder: border(_red, 1.5),
  );
}

// ─────────────────────────────────────────────
//  Shared building blocks
// ─────────────────────────────────────────────
class _SheetFrame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget child;
  const _SheetFrame({
    required this.title,
    required this.child,
    this.subtitle,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final p = _Pal.of(context);
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
        decoration: BoxDecoration(
          color: p.surface,
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
                      color: p.sub.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (onBack != null) ...[
                      InkWell(
                        onTap: onBack,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: p.tint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            size: 20,
                            color: p.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: p.text,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: p.sub,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = _Pal.of(context);

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? p.accent,
          foregroundColor: color != null ? Colors.white : p.onAccent,
          disabledBackgroundColor: p.accent.withOpacity(0.18),
          disabledForegroundColor: p.sub,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _CheckDot extends StatelessWidget {
  final bool selected;
  final Color color;
  final Color onColor;
  const _CheckDot({
    required this.selected,
    required this.color,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = _Pal.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? color : Colors.transparent,
        border: Border.all(
          color: selected ? color : p.sub.withOpacity(0.5),
          width: 1.6,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 16, color: onColor)
          : null,
    );
  }
}

class _Segmented extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const _Segmented({
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = _Pal.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.tint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? p.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: i == index ? p.onAccent : p.sub,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final p = _Pal.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: p.text,
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _DateTile({
    required this.icon,
    required this.text,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final p = _Pal.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: p.tint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: p.sub),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: p.text,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded, size: 18, color: p.sub),
              )
            else
              Icon(Icons.chevron_right_rounded, color: p.sub),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = _Pal.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: p.tint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: value ? p.accent : p.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: p.sub)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: p.accent,
            activeTrackColor: p.accent.withOpacity(0.35),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  1) Assign sheet
// ─────────────────────────────────────────────
class _AssignSheet extends StatefulWidget {
  final int count;
  final bool showHistoryOptions;
  final List<String> currentIds;
  final List<StageOpt> stages; // 👈
  final bool allowTeamLeader;
  final String? teamOwnerId;
  final bool teamOwnerIsManager;
  final bool allowResetCreationDate;
  final String? teamOwnerName;
  final Map<String, String> currentNames;
  final bool allowAddToCurrent; // 👈

  const _AssignSheet({
    required this.count,
    this.showHistoryOptions = false,
    this.currentIds = const [],
    this.stages = const [], // 👈
    this.allowTeamLeader = true,
    this.teamOwnerId,
    this.teamOwnerIsManager = false,
    this.allowResetCreationDate = true,
    this.teamOwnerName,
    this.currentNames = const {},
    this.allowAddToCurrent = true, // 👈
  });

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  late final Set<String> _initial = widget.currentIds.toSet();
  // ... باقي الحقول زي ما هي
  late AssignTarget? _target = widget.allowTeamLeader
      ? null
      : AssignTarget.salesman;
  final Set<String> _picked = {};
  bool _replace = true;
  final TextEditingController _search = TextEditingController();
  String _query = '';
  // History options (Admin بس)
  bool _clearHistory = false;
  bool _resetCreation = false;
  DateTime _creationDate = DateTime.now();
  // 4) _AssignSheetState: جنب _creationDate
  bool _changeStage = false;
  StageOpt? _stage;

  List<StageOpt> get _stageOptions =>
      widget.stages.where((s) => !s.isDeal).toList();

  StageOpt? get _freshStage {
    for (final s in _stageOptions) {
      if (s.name.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '') == 'fresh') {
        return s;
      }
    }
    return null;
  }

  Future<void> _pickCreationDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _creationDate.isAfter(now) ? now : _creationDate,
      firstDate: DateTime(2020),
      lastDate: now, // الباك مش بيقبل مستقبل
    );
    if (d == null || !mounted) return;

    // اختيار الساعة والدقيقة
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_creationDate),
    );
    if (t == null) return;

    var picked = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    // لو اختار النهارده بساعة لسه ما جتش، نرجّعه لدلوقتي
    if (picked.isAfter(now)) picked = now;
    setState(() => _creationDate = picked);
  }

  List<LeadPerson> _salesmen = [], _leaders = [];
  bool _loading = true;
  String? _error;

  bool get _isTeamLeader => _target == AssignTarget.teamLeader;
  List<LeadPerson> get _source => _isTeamLeader ? _leaders : _salesmen;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Replace: الحاليين معلّمين تلقائياً. Add: الاختيار فاضي.
  /// الـ current معلّمين تلقائياً في Replace و Add
  void _resetPicked() {
    _picked
      ..clear()
      ..addAll(_source.where((p) => _initial.contains(p.id)).map((p) => p.id));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      int byName(LeadPerson a, LeadPerson b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase());

      if (widget.teamOwnerId != null) {
        // مانجر / تيم ليدر: فريقه بس
        final team = await UsersLookupService().myTeam(
          isManager: widget.teamOwnerIsManager,
          userId: widget.teamOwnerId!,
        );
        LeadPerson toPerson(LookupUser u) => LeadPerson(
          u.id,
          u.name.isEmpty ? (u.email.isEmpty ? 'Unnamed' : u.email) : u.name,
          u.role,
        );
        final sales =
            team
                .where((u) => u.role == 'Sales' && u.id != widget.teamOwnerId)
                .map(toPerson)
                .toList()
              ..sort(byName);
        _salesmen = [
          if (widget.teamOwnerName != null && !widget.teamOwnerIsManager)
            LeadPerson(
              widget.teamOwnerId!,
              widget.teamOwnerName!.trim().isEmpty
                  ? 'Me'
                  : '${widget.teamOwnerName} (me)',
              'Team Leader',
            ),
          ...sales,
        ];
        _leaders = widget.allowTeamLeader
            ? (team.where((u) => u.role == 'Team Leader').map(toPerson).toList()
                ..sort(byName))
            : <LeadPerson>[];
      } else {
        // أدمن: كل اليوزرز (زي ما كان)
        final r = await AuthService().getAllUsers();
        final users = (r['data'] as List? ?? [])
            .whereType<Map>()
            .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e)))
            .where((u) => u.id != null && u.active)
            .toList();

        LeadPerson toPerson(UserModel u) => LeadPerson(
          u.id!,
          u.fullName.isEmpty ? (u.email ?? 'Unnamed') : u.fullName,
          '${u.role}',
        );
        _salesmen = users.where((u) => u.role == 'Sales').map(toPerson).toList()
          ..sort(byName);
        _leaders =
            users.where((u) => u.role == 'Team Leader').map(toPerson).toList()
              ..sort(byName);
      }
      // السيلز الحاليين اللي مش في القايمة (معطّلين / مش تابعين للتيم ليدر):
      // نضيفهم عشان يتعلّموا CURRENT ويفضلوا ظاهرين
      for (final id in widget.currentIds) {
        final exists =
            _salesmen.any((p) => p.id == id) || _leaders.any((p) => p.id == id);
        if (!exists) {
          _salesmen.add(
            LeadPerson(
              id,
              widget.currentNames[id] ?? 'Current assignee',
              'Current',
            ),
          );
        }
      }
    } catch (e) {
      _error = e.toString();
    }
    if (_target != null) _resetPicked();
    if (mounted) setState(() => _loading = false);
  }

  void _choose(AssignTarget target) {
    HapticFeedback.selectionClick();
    setState(() {
      _target = target;
      _picked.clear();
      _search.clear();
      _query = '';
      _resetPicked();
    });
  }

  void _toggle(LeadPerson person) {
    HapticFeedback.selectionClick();
    setState(() {
      // Replace → single select
      if (_replace) {
        if (_picked.contains(person.id)) {
          _picked.clear();
        } else {
          _picked
            ..clear()
            ..add(person.id);
        }
        return;
      }

      // Add → multi select، والـ current ثابتين (مينفعش يتشالوا)
      if (_initial.contains(person.id)) return;
      if (!_picked.add(person.id)) _picked.remove(person.id);
    });
  }

  void _submit() {
    // Add → الجداد بس (الـ current موجودين أصلاً)، Replace → الاختيار كله
    final people = _source
        .where(
          (p) =>
              _picked.contains(p.id) && (_replace || !_initial.contains(p.id)),
        )
        .toList();
    final now = DateTime.now().subtract(const Duration(minutes: 1));
    final date = _creationDate.isAfter(now) ? now : _creationDate;

    Navigator.of(context).pop(
      AssignResult(
        target: _target!,
        people: people,
        replace: widget.allowAddToCurrent ? _replace : true, // 👈
        clearHistory: _clearHistory,
        resetCreationDate: widget.allowResetCreationDate && _resetCreation,
        creationDate: (widget.allowResetCreationDate && _resetCreation)
            ? date
            : null,
        stage: _changeStage ? _stage : null, // 👈
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String title;
    final String subtitle;
    if (_target == null) {
      title = 'Assign leads';
      subtitle = '${_leadsLabel(widget.count)} selected';
    } else if (_isTeamLeader) {
      title = 'Assign to team leader';
      subtitle = 'Select one or more team leaders';
    } else {
      title = 'Assign as a salesman';
      subtitle = 'Select one or more salesmen';
    }

    return _SheetFrame(
      title: title,
      subtitle: subtitle,
      onBack: (_target == null || !widget.allowTeamLeader)
          ? null
          : () => setState(() => _target = null),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _target == null
            ? _buildChooser()
            : _loading
            ? const Padding(
                key: ValueKey('loading'),
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
            ? _buildError()
            : _buildPicker(),
      ),
    );
  }

  Widget _buildError() {
    return Column(
      key: const ValueKey('error'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _red),
        ),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ],
    );
  }

  Widget _buildChooser() {
    return Column(
      key: const ValueKey('chooser'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _OptionTile(
          icon: Icons.support_agent_rounded,
          title: 'Assign as a salesman',
          subtitle: 'Pick one or more salesmen',
          onTap: () => _choose(AssignTarget.salesman),
        ),
        const SizedBox(height: 12),
        _OptionTile(
          icon: Icons.groups_rounded,
          title: 'Assign to team leader',
          subtitle: 'Pick one or more team leaders',
          onTap: () => _choose(AssignTarget.teamLeader),
        ),
      ],
    );
  }

  Widget _buildPicker() {
    final p = _Pal.of(context);
    final q = _query.trim().toLowerCase();
    final list = _source
        .where((e) => q.isEmpty || e.name.toLowerCase().contains(q))
        .toList();
    final n = _source.where((e) => _picked.contains(e.id)).length;
    final base = _source
        .where((e) => _initial.contains(e.id))
        .map((e) => e.id)
        .toSet();
    // 6) _buildPicker: بدّل unchanged وضيف stageMissing
    final newCount = _picked.where((id) => !base.contains(id)).length;

    final unchanged = _replace
        ? (!_changeStage &&
              base.isNotEmpty &&
              _picked.length == base.length &&
              _picked.containsAll(base))
        : newCount == 0; // Add: لازم تختار واحد جديد على الأقل

    final stageMissing = _changeStage && _stage == null;
    final shown = _replace ? n : newCount;
    final noun = _isTeamLeader
        ? (shown == 1 ? 'team leader' : 'team leaders')
        : (shown == 1 ? 'salesman' : 'salesmen');

    return Column(
      key: const ValueKey('picker'),
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _query = v),
          style: TextStyle(color: p.text, fontSize: 14.5),
          cursorColor: p.accent,
          decoration: _fieldDecoration(
            p,
            hint: _isTeamLeader ? 'Search team leaders' : 'Search salesmen',
            icon: Icons.search_rounded,
          ),
        ),
        const SizedBox(height: 12),
        // غير الأدمن مفيش عنده Add to current، فمفيش داعي للتبديل
        if (widget.allowAddToCurrent) ...[
          _Segmented(
            labels: const ['Replace current', 'Add to current'],
            index: _replace ? 0 : 1,
            onChanged: (i) => setState(() {
              _replace = i == 0;
              _resetPicked();
            }),
          ),
          const SizedBox(height: 12),
        ],
        Flexible(
          child: list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    'No results',
                    style: TextStyle(color: p.sub, fontSize: 13.5),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _PersonRow(
                    person: list[i],
                    selected: _picked.contains(list[i].id),
                    current: _initial.contains(list[i].id),
                    onTap: () => _toggle(list[i]),
                  ),
                ),
        ),
        // ── Admin only ──
        if (widget.showHistoryOptions) ...[
          const SizedBox(height: 12),
          _SwitchTile(
            title: 'Clear history',
            subtitle: 'Remove the lead\'s previous activity history',
            value: _clearHistory,
            onChanged: (v) => setState(() => _clearHistory = v),
          ),
          const SizedBox(height: 8),
          if (widget.allowResetCreationDate) ...[
            const SizedBox(height: 8),
            _SwitchTile(
              title: 'Reset creation date',
              subtitle: 'Set a new creation date for the lead',
              value: _resetCreation,
              onChanged: (v) => setState(() => _resetCreation = v),
            ),
            if (_resetCreation) ...[
              const SizedBox(height: 8),
              _DateTile(
                icon: Icons.event_available_rounded,
                text:
                    '${_fmtDate(_creationDate)}  ${TimeOfDay.fromDateTime(_creationDate).format(context)}',
                onTap: _pickCreationDate,
              ),
            ],
          ],
          // 7) جوه if (widget.showHistoryOptions) ...[ بعد بلوك Reset creation date
          if (_stageOptions.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SwitchTile(
              title: 'Change stage with assign',
              subtitle: 'Optional, e.g. assign as Fresh',
              value: _changeStage,
              onChanged: (v) => setState(() {
                _changeStage = v;
                _stage = v ? (_stage ?? _freshStage) : null;
              }),
            ),
            if (_changeStage) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _stageOptions)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _stage = s);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _stage?.id == s.id
                              ? s.color.withOpacity(0.12)
                              : p.tint,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _stage?.id == s.id
                                ? s.color
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: s.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              s.name,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: p.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ],
        const SizedBox(height: 14),
        _PrimaryButton(
          label: shown == 0
              ? 'Select at least one'
              : stageMissing
              ? 'Select a stage'
              : unchanged
              ? 'No changes'
              : 'Assign to $shown $noun${_changeStage ? ' + ${_stage!.name}' : ''}',
          onPressed: (shown == 0 || unchanged || stageMissing) ? null : _submit,
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = _Pal.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.tint,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.navy, AppColors.navyLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                child: Icon(icon, color: AppColors.gold, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12.5, color: p.sub),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.sub),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final LeadPerson person;
  final bool selected;
  final bool current;
  final VoidCallback onTap;
  const _PersonRow({
    required this.person,
    required this.selected,
    required this.onTap,
    this.current = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = _Pal.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? p.accent.withOpacity(0.10) : p.tint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? p.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.navy, AppColors.navyLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                person.initials,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          person.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: p.text,
                          ),
                        ),
                      ),
                      if (current) ...[
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
                  const SizedBox(height: 2),
                  Text(
                    person.subtitle,
                    style: TextStyle(fontSize: 12, color: p.sub),
                  ),
                ],
              ),
            ),
            _CheckDot(selected: selected, color: p.accent, onColor: p.onAccent),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  2) Change stage sheet
//     Comment إجباري • Done Deal (lead واحد) • Clear history / Reset date (Admin)
// ─────────────────────────────────────────────
class _StageSheet extends StatefulWidget {
  final int count;
  final List<StageOpt> stages;
  final String? currentStageId;
  final List<({String id, String name})> projects;
  const _StageSheet({
    required this.count,
    required this.stages,
    this.currentStageId,
    this.projects = const [],
  });

  @override
  State<_StageSheet> createState() => _StageSheetState();
}

class _StageSheetState extends State<_StageSheet> {
  StageOpt? _picked;
  final _note = TextEditingController();

  // Done Deal
  String? _projectId;
  final _price = TextEditingController();
  final _unitType = TextEditingController();
  final _unitNumber = TextEditingController();
  final _commission = TextEditingController();
  final _cashback = TextEditingController();
  final _paid = TextEditingController();
  DateTime? _closedAt; // اختياري (null = دلوقتي)
  @override
  void dispose() {
    for (final c in [
      _note,
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

  bool get _isDeal => _picked?.isDeal == true;
  num? _n(TextEditingController c) => num.tryParse(c.text.trim());

  bool get _dealValid =>
      _projectId != null &&
      (_n(_price) ?? 0) > 0 &&
      _unitType.text.trim().isNotEmpty &&
      _unitNumber.text.trim().isNotEmpty;

  // Done Deal لازم lead واحد
  bool get _dealBlocked => _isDeal && widget.count > 1;

  bool get _canSubmit =>
      _picked != null && !_dealBlocked && (!_isDeal || _dealValid);

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2050),
  );

  Map<String, dynamic>? _dealBody() {
    if (!_isDeal) return null;
    return {
      'project': _projectId,
      'unitPrice': _n(_price),
      'unitType': _unitType.text.trim(),
      'unitNumber': _unitNumber.text.trim(),
      if (_n(_commission) != null) 'companyCommissionRatio': _n(_commission),
      if (_n(_cashback) != null) 'cashbackRatio': _n(_cashback),
      if (_n(_paid) != null) 'amountPaid': _n(_paid),
      if (_closedAt != null) 'closedAt': _closedAt!.toUtc().toIso8601String(),
    };
  }

  void _submit() {
    Navigator.of(context).pop(
      StageChange(
        stageId: _picked!.id,
        stage: _picked!.name,
        note: '',
        deal: _dealBody(),
      ),
    );
  }

  Widget _field(
    _Pal p,
    TextEditingController c,
    String label,
    String hint, {
    bool number = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label),
          TextField(
            controller: c,
            onChanged: (_) => setState(() {}),
            keyboardType: number
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            inputFormatters: number
                ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                : null,
            style: TextStyle(color: p.text, fontSize: 14.5),
            cursorColor: p.accent,
            decoration: _fieldDecoration(p, hint: hint),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _Pal.of(context);

    final String btn = _picked == null
        ? 'Select a stage'
        : _dealBlocked
        ? 'Select one lead for Done Deal'
        : (_isDeal && !_dealValid)
        ? 'Fill the deal details'
        : 'Move to ${_picked!.name}';

    return _SheetFrame(
      title: 'Change stage',
      subtitle: '${_leadsLabel(widget.count)} selected',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.stages.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                          'No stages available',
                          style: TextStyle(color: p.sub),
                        ),
                      ),
                    )
                  else
                    for (final s in widget.stages) ...[
                      _StageTile(
                        stage: s.name,
                        color: s.color,
                        selected: _picked?.id == s.id,
                        current: widget.currentStageId == s.id,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _picked = s);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],

                  // ── Comment (إجباري) ──
                  const SizedBox(height: 14),

                  // ── Done Deal ──
                  if (_isDeal) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Deal details',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_dealBlocked)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Done Deal can be set for one lead at a time.',
                          style: TextStyle(color: _red, fontSize: 12.5),
                        ),
                      ),
                    const _FieldLabel('Project *'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        value: _projectId,
                        isExpanded: true,
                        dropdownColor: p.surface,
                        style: TextStyle(color: p.text, fontSize: 14.5),
                        decoration: _fieldDecoration(
                          p,
                          hint: widget.projects.isEmpty
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
                        onChanged: (v) => setState(() => _projectId = v),
                      ),
                    ),
                    _field(p, _price, 'Unit price *', '2000000', number: true),
                    _field(p, _unitType, 'Unit type *', '3BR / Apartment'),
                    _field(p, _unitNumber, 'Unit number *', 'B-305'),
                    _field(
                      p,
                      _commission,
                      'Company commission %',
                      '3',
                      number: true,
                    ),
                    _field(p, _cashback, 'Cashback %', '2', number: true),
                    _field(p, _paid, 'Amount paid', '100000', number: true),
                    const _FieldLabel('Closed at'),
                    _DateTile(
                      icon: Icons.event_rounded,
                      text: _closedAt == null ? 'Now' : _fmtDate(_closedAt!),
                      onTap: () async {
                        final d = await _pickDate(_closedAt ?? DateTime.now());
                        if (d != null) setState(() => _closedAt = d);
                      },
                      onClear: _closedAt == null
                          ? null
                          : () => setState(() => _closedAt = null),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _PrimaryButton(label: btn, onPressed: _canSubmit ? _submit : null),
        ],
      ),
    );
  }
}

class _StageTile extends StatelessWidget {
  final String stage;
  final Color color;
  final bool selected, current;
  final VoidCallback onTap;
  const _StageTile({
    required this.stage,
    required this.color,
    required this.selected,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = _Pal.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.10) : p.tint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.transparent,
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
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                stage,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: p.text,
                ),
              ),
            ),
            if (current) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: p.sub.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'CURRENT',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: p.sub,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            _CheckDot(selected: selected, color: color, onColor: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  3) Edit lead sheet (lead واحد)
// ─────────────────────────────────────────────
class _EditLeadSheet extends StatefulWidget {
  final LeadEditData lead;
  const _EditLeadSheet({required this.lead});

  @override
  State<_EditLeadSheet> createState() => _EditLeadSheetState();
}

class _EditLeadSheetState extends State<_EditLeadSheet> {
  final _form = GlobalKey<FormState>();
  final _svc = LeadsService();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _notes;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final l = widget.lead;
    _name = TextEditingController(text: l.name);
    _phone = TextEditingController(text: l.phone);
    _email = TextEditingController(text: l.email ?? '');
    _notes = TextEditingController(text: l.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final l = widget.lead;

    final changes = <String, dynamic>{};
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim();
    final notes = _notes.text.trim();

    if (name != l.name) changes['name'] = name;
    if (phone != l.phone) changes['phone'] = phone;
    if (email.isNotEmpty && email != (l.email ?? '')) changes['email'] = email;
    if (notes != (l.notes ?? '')) {
      changes['notes'] = notes.isEmpty ? null : notes;
    }

    if (changes.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _svc.updateLead(l.id, changes);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _Pal.of(context);
    final inputStyle = TextStyle(
      color: p.text,
      fontSize: 14.5,
      fontWeight: FontWeight.w600,
    );

    return _SheetFrame(
      title: 'Edit lead information',
      subtitle: widget.lead.name,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Full name'),
                    TextFormField(
                      controller: _name,
                      style: inputStyle,
                      cursorColor: p.accent,
                      textCapitalization: TextCapitalization.words,
                      decoration: _fieldDecoration(
                        p,
                        hint: 'Lead name',
                        icon: Icons.person_outline_rounded,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    const _FieldLabel('Phone'),
                    TextFormField(
                      controller: _phone,
                      style: inputStyle,
                      cursorColor: p.accent,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(15),
                      ],
                      decoration:
                          _fieldDecoration(
                            p,
                            hint: '5X XXX XXXX',
                            icon: Icons.phone_outlined,
                          ).copyWith(
                            prefixText: '${widget.lead.phoneCountryCode}  ',
                            prefixStyle: inputStyle,
                          ),
                      validator: (v) => (v == null || v.trim().length < 7)
                          ? 'Enter a valid phone number'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    const _FieldLabel('Email'),
                    TextFormField(
                      controller: _email,
                      style: inputStyle,
                      cursorColor: p.accent,
                      keyboardType: TextInputType.emailAddress,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      ],
                      decoration: _fieldDecoration(
                        p,
                        hint: 'name@example.com',
                        icon: Icons.email_outlined,
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return null;
                        final ok = RegExp(
                          r'^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$',
                        ).hasMatch(t);
                        return ok ? null : 'Enter a valid email';
                      },
                    ),
                    const SizedBox(height: 14),
                    const _FieldLabel('Notes'),
                    TextFormField(
                      controller: _notes,
                      style: inputStyle,
                      cursorColor: p.accent,
                      minLines: 2,
                      maxLines: 4,
                      decoration: _fieldDecoration(p, hint: 'Optional notes'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _red, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 16),
          _PrimaryButton(
            label: _saving ? 'Saving...' : 'Save changes',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  4) Delete confirmation (soft delete → Trash)
// ─────────────────────────────────────────────
class _DeleteDialog extends StatelessWidget {
  final int count;
  const _DeleteDialog({required this.count});

  @override
  Widget build(BuildContext context) {
    final p = _Pal.of(context);

    return Dialog(
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _red.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: _red,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              count == 1 ? 'Delete this lead?' : 'Delete $count leads?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: p.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              count == 1
                  ? 'It will be moved to Leads Trash. You can restore it later.'
                  : 'They will be moved to Leads Trash. You can restore them later.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.45, color: p.sub),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.text,
                        side: BorderSide(color: p.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
