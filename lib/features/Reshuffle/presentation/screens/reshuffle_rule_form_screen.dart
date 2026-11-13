// ignore_for_file: deprecated_member_use
// reshuffle_rule_form_screen.dart
// فورم إضافة/تعديل rule. ruleId == null → إضافة، غير كده → تعديل (بيجيب الـ rule من GET /:id).
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/features/Reshuffle/provider/reshuffle_service.dart';
import 'package:flutter_application_1/features/leads/presentation/widgets/lead_filter_sheet.dart'; // LeadFilterOptions
import 'package:flutter_application_1/features/leads/providers/admin_leads_filter_service.dart'; // Opt
import 'package:flutter_application_1/features/reshuffle/data/reshuffle_rule_model.dart';
import 'package:flutter_application_1/features/reshuffle/presentation/widgets/reshuffle_widgets.dart';

class ReshuffleRuleFormScreen extends StatefulWidget {
  final String? ruleId;
  const ReshuffleRuleFormScreen({super.key, this.ruleId});

  @override
  State<ReshuffleRuleFormScreen> createState() =>
      _ReshuffleRuleFormScreenState();
}

class _ReshuffleRuleFormScreenState extends State<ReshuffleRuleFormScreen> {
  // ⚠️ اتأكد من الباك: 0 = Sunday ولا Monday؟ (غيّر الترتيب هنا بس لو مختلف)
  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  final _svc = ReshuffleService();
  RsRule _r = RsRule();
  Map<String, List<Opt>> _opts = {};
  bool _loading = true, _saving = false;
  String? _error;

  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _priority = TextEditingController();
  final _maxLeads = TextEditingController();
  final _maxReshuffles = TextEditingController();

  bool get _edit => widget.ruleId != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    for (final c in [_name, _desc, _priority, _maxLeads, _maxReshuffles]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // الاختيارات (stages/مشاريع/يوزرز...) + الـ rule نفسها لو تعديل
      final res = await Future.wait<Object>([
        LeadFilterOptions.load(),
        if (_edit) _svc.get(widget.ruleId!),
      ]);
      _opts = res[0] as Map<String, List<Opt>>;
      if (_edit) _r = res[1] as RsRule;
      _name.text = _r.name;
      _desc.text = _r.description;
      _priority.text = '${_r.priority}';
      _maxLeads.text = '${_r.maxLeadsPerSales}';
      _maxReshuffles.text = '${_r.maxReshuffles}';
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  // ── Helpers ──
  List<Opt> _list(String key) => _opts[key] ?? const <Opt>[];

  String _names(String key, List<String> ids) {
    if (ids.isEmpty) return 'Any';
    final byId = {for (final o in _list(key)) o.id: o.name};
    return ids.map((i) => byId[i] ?? i).join(', ');
  }

  int _mins(String hhmm) {
    final p = hhmm.split(':');
    return (int.tryParse(p[0]) ?? 0) * 60 +
        (int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  }

  Future<void> _pickMany(String title, String key, List<String> value) async {
    final r = await showRsPicker(
      context,
      title: title,
      options: _list(key),
      selected: value,
    );
    if (r != null) {
      setState(
        () => value
          ..clear()
          ..addAll(r),
      );
    }
  }

  /// بيرجّع Opt من الـ id (للـ stages والـ users)
  Opt? _opt(String key, String id) {
    for (final o in _list(key)) {
      if (o.id == id) return o;
    }
    return null;
  }

  Future<void> _pickStage(
    void Function(RsRef?) set, {
    String? current,
    bool clearable = false,
    String title = 'Stage',
  }) async {
    final r = await showRsPicker(
      context,
      title: title,
      options: _list('oldStage'), // قايمة كل الـ stages
      selected: current == null ? const [] : [current],
      single: true,
      clearable: clearable,
    );
    if (r == null) return;
    if (r.isEmpty) {
      setState(() => set(null));
      return;
    }
    final o = _opt('oldStage', r.first);
    if (o != null) setState(() => set(RsRef(o.id, o.name)));
  }

  Future<void> _pickPoolUsers() async {
    final base = _list('sales'); // sales / team leader / manager
    final known = {...base.map((o) => o.id)};
    // لو يوزر في الـ rule مش في القايمة (اتعطّل مثلًا) نضيفه عشان يفضل ظاهر
    final all = [
      ...base,
      for (final u in _r.poolUsers)
        if (!known.contains(u.id)) Opt(u.id, u.name),
    ];
    final r = await showRsPicker(
      context,
      title: 'Sales pool',
      options: all,
      selected: _r.poolUsers.map((u) => u.id).toList(),
    );
    if (r == null) return;
    setState(
      () => _r.poolUsers = [
        for (final id in r) RsRef(id, all.firstWhere((o) => o.id == id).name),
      ],
    );
  }

  Future<void> _pickExhaustedUser() async {
    final r = await showRsPicker(
      context,
      title: 'Exhausted leads go to',
      options: _list('assignedFrom'), // كل اليوزرز
      selected: _r.exhaustedUser == null ? const [] : [_r.exhaustedUser!.id],
      single: true,
      clearable: false,
    );
    if (r == null || r.isEmpty) return;
    final o = _opt('assignedFrom', r.first);
    if (o != null) setState(() => _r.exhaustedUser = RsRef(o.id, o.name));
  }

  Future<void> _pickTime(bool start) async {
    final cur = start ? _r.workingHours.start : _r.workingHours.end;
    final m = _mins(cur);
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (t == null) return;
    final v =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (start) {
        _r.workingHours.start = v;
      } else {
        _r.workingHours.end = v;
      }
    });
  }

  // ── Save ──
  String? _validate() {
    if (_name.text.trim().isEmpty) return 'Rule name is required';
    if (_r.stages.isEmpty || _r.stages.any((s) => s.stage == null)) {
      return 'Add at least one stage and pick a stage for every step';
    }
    final ids = _r.stages.map((s) => s.stage!.id).toList();
    if (ids.toSet().length != ids.length) return 'Each stage can be used once';
    if (_r.stages.any((s) => s.delayValue <= 0 || s.minEntries <= 0)) {
      return 'Delay and min entries must be greater than 0';
    }
    if (_r.poolUsers.isEmpty) return 'Select at least one user in the pool';
    if (_r.onExhausted == 'user' && _r.exhaustedUser == null) {
      return 'Pick the user who receives exhausted leads';
    }
    if (_r.moveToStage != null && ids.contains(_r.moveToStage!.id)) {
      return 'The "move to" stage cannot be one of the rule stages';
    }
    final w = _r.workingHours;
    if (w.enabled) {
      if (w.days.isEmpty) return 'Select at least one working day';
      if (_mins(w.end) <= _mins(w.start)) {
        return 'Working hours end must be after start';
      }
    }
    return null;
  }

  Future<void> _save() async {
    // الحقول النصية/الرقمية بتتقري هنا
    _r.name = _name.text;
    _r.description = _desc.text;
    _r.priority = int.tryParse(_priority.text.trim()) ?? 100;
    _r.maxLeadsPerSales = int.tryParse(_maxLeads.text.trim()) ?? 0;
    _r.maxReshuffles = int.tryParse(_maxReshuffles.text.trim()) ?? 3;

    final err = _validate();
    if (err != null) {
      rsToast(context, err, error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      if (_edit) {
        await _svc.update(widget.ruleId!, _r);
      } else {
        await _svc.create(_r);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        rsToast(context, e.toString(), error: true);
      }
    }
  }

  // ── UI ──
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          RsHeader(
            title: _edit ? 'Edit Rule' : 'New Rule',
            subtitle: 'Stage reshuffle system',
          ),
          Expanded(child: _body()),
        ],
      ),
      bottomNavigationBar: (_loading || _error != null) ? null : _saveBar(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFE5484D)),
              ),
              TextButton(onPressed: _init, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final w = _r.workingHours;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // ───── General ─────
        _Section(
          title: 'General',
          children: [
            _pad(_textField(_name, 'Rule name', Icons.label_rounded)),
            _pad(
              _textField(
                _desc,
                'Description (optional)',
                Icons.notes_rounded,
                lines: 2,
              ),
            ),
            _pad(
              _textField(
                _priority,
                'Priority (lower = runs first)',
                Icons.flag_rounded,
                number: true,
              ),
            ),
          ],
        ),

        // ───── Stages ─────
        _Section(
          title: 'Stages & delay',
          children: [
            for (int i = 0; i < _r.stages.length; i++) _stepCard(i),
            _pad(
              OutlinedButton.icon(
                onPressed: () => setState(() => _r.stages.add(RsStep())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add stage'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.navy,
                  side: const BorderSide(color: AppColors.gold),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),

        // ───── Filters ─────
        _Section(
          title: 'Filters',
          children: [
            _PickTile(
              icon: Icons.domain_rounded,
              title: 'Projects',
              value: _names('projects', _r.projects),
              count: _r.projects.length,
              onTap: () => _pickMany('Projects', 'projects', _r.projects),
            ),
            _PickTile(
              icon: Icons.hub_rounded,
              title: 'Channels',
              value: _names('channel', _r.channels),
              count: _r.channels.length,
              onTap: () => _pickMany('Channels', 'channel', _r.channels),
            ),
            _PickTile(
              icon: Icons.campaign_rounded,
              title: 'Campaigns',
              value: _names('campaigns', _r.campaigns),
              count: _r.campaigns.length,
              onTap: () => _pickMany('Campaigns', 'campaigns', _r.campaigns),
            ),
            _chipsBlock('Lead type', [
              for (final t in const ['Fresh', 'Cold'])
                _chip(t, _r.leadTypes.contains(t), () {
                  setState(() {
                    if (!_r.leadTypes.remove(t)) _r.leadTypes.add(t);
                  });
                }),
            ]),
            _SwitchTile(
              icon: Icons.handshake_rounded,
              title: 'Skip leads with closed deals',
              value: _r.excludeWithClosedDeals,
              onChanged: (v) => setState(() => _r.excludeWithClosedDeals = v),
            ),
          ],
        ),

        // ───── Pool ─────
        _Section(
          title: 'Sales pool',
          children: [
            _PickTile(
              icon: Icons.groups_rounded,
              title: 'Users in pool',
              value: _r.poolUsers.isEmpty
                  ? 'None selected'
                  : _r.poolUsers.map((u) => u.name).join(', '),
              count: _r.poolUsers.length,
              onTap: _pickPoolUsers,
            ),
            _chipsBlock('Distribution', [
              _chip(
                'Round robin',
                _r.poolMode == 'round_robin',
                () => setState(() => _r.poolMode = 'round_robin'),
              ),
              _chip(
                'Least loaded',
                _r.poolMode == 'least_loaded',
                () => setState(() => _r.poolMode = 'least_loaded'),
              ),
            ]),
            _pad(
              _textField(
                _maxLeads,
                'Max leads per sales (0 = no limit)',
                Icons.speed_rounded,
                number: true,
              ),
            ),
          ],
        ),

        // ───── Working hours ─────
        _Section(
          title: 'Working hours',
          children: [
            _SwitchTile(
              icon: Icons.schedule_rounded,
              title: 'Only reshuffle during working hours',
              value: w.enabled,
              onChanged: (v) => setState(() => w.enabled = v),
            ),
            if (w.enabled) ...[
              _PickTile(
                icon: Icons.play_arrow_rounded,
                title: 'From',
                value: w.start,
                count: 0,
                onTap: () => _pickTime(true),
              ),
              _PickTile(
                icon: Icons.stop_rounded,
                title: 'To',
                value: w.end,
                count: 0,
                onTap: () => _pickTime(false),
              ),
              _chipsBlock('Days', [
                for (int d = 0; d < _days.length; d++)
                  _chip(_days[d], w.days.contains(d), () {
                    setState(() {
                      if (!w.days.remove(d)) w.days.add(d);
                      w.days.sort();
                    });
                  }),
              ]),
            ],
          ],
        ),

        // ───── Behavior ─────
        _Section(
          title: 'Behavior',
          children: [
            _chipsBlock('When the lead has new activity', [
              _chip(
                'Restart timer',
                _r.activityPolicy == 'restart',
                () => setState(() => _r.activityPolicy = 'restart'),
              ),
              _chip(
                'Ignore activity',
                _r.activityPolicy == 'ignore',
                () => setState(() => _r.activityPolicy = 'ignore'),
              ),
            ]),
            _SwitchTile(
              icon: Icons.alarm_rounded,
              title: 'Wait for the follow-up date',
              value: _r.respectFollowUp,
              onChanged: (v) => setState(() => _r.respectFollowUp = v),
            ),
            _pad(
              _textField(
                _maxReshuffles,
                'Max reshuffles per lead',
                Icons.repeat_rounded,
                number: true,
              ),
            ),
            _chipsBlock('When reshuffles are exhausted', [
              _chip(
                'Keep as is',
                _r.onExhausted == 'keep',
                () => setState(() => _r.onExhausted = 'keep'),
              ),
              _chip(
                'Unassign',
                _r.onExhausted == 'unassign',
                () => setState(() => _r.onExhausted = 'unassign'),
              ),
              _chip(
                'Assign to user',
                _r.onExhausted == 'user',
                () => setState(() => _r.onExhausted = 'user'),
              ),
            ]),
            if (_r.onExhausted == 'user')
              _PickTile(
                icon: Icons.person_rounded,
                title: 'Exhausted leads go to',
                value: _r.exhaustedUser?.name ?? 'Pick a user',
                count: _r.exhaustedUser == null ? 0 : 1,
                onTap: _pickExhaustedUser,
              ),
          ],
        ),

        // ───── After reshuffle ─────
        _Section(
          title: 'After each reshuffle',
          children: [
            _PickTile(
              icon: Icons.swap_horiz_rounded,
              title: 'Move lead to stage',
              value: _r.moveToStage?.name ?? 'Keep current stage',
              count: _r.moveToStage == null ? 0 : 1,
              onTap: () => _pickStage(
                (s) => _r.moveToStage = s,
                current: _r.moveToStage?.id,
                clearable: true,
                title: 'Move to stage',
              ),
            ),
            _SwitchTile(
              icon: Icons.event_repeat_rounded,
              title: 'Reset creation date',
              value: _r.resetCreationDate,
              onChanged: (v) => setState(() => _r.resetCreationDate = v),
            ),
            _SwitchTile(
              icon: Icons.history_toggle_off_rounded,
              title: 'Clear lead history',
              value: _r.clearHistory,
              onChanged: (v) => setState(() => _r.clearHistory = v),
            ),
          ],
        ),
      ],
    );
  }

  // خطوة واحدة (stage + delay + min entries)
  Widget _stepCard(int i) {
    final s = _r.stages[i];
    return Padding(
      // ObjectKey عشان الـ TextFormField ما يلخبطش لما تتحذف خطوة من النص
      key: ObjectKey(s),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Step ${i + 1}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _r.stages.removeAt(i)),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: _PickTile(
              icon: Icons.stairs_rounded,
              title: 'Stage',
              value: s.stage?.name ?? 'Pick a stage',
              count: s.stage == null ? 0 : 1,
              onTap: () => _pickStage((v) => s.stage = v, current: s.stage?.id),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: '${s.delayValue}',
                  keyboardType: TextInputType.number,
                  decoration: _dec('Move after', Icons.timer_outlined),
                  onChanged: (v) => s.delayValue = int.tryParse(v) ?? 0,
                ),
              ),
              const SizedBox(width: 10),
              Wrap(
                spacing: 6,
                children: [
                  _chip(
                    'Hours',
                    s.delayUnit == 'hours',
                    () => setState(() => s.delayUnit = 'hours'),
                  ),
                  _chip(
                    'Days',
                    s.delayUnit == 'days',
                    () => setState(() => s.delayUnit = 'days'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: '${s.minEntries}',
            keyboardType: TextInputType.number,
            decoration: _dec(
              'Min entries (times the lead entered this stage)',
              Icons.login_rounded,
            ),
            onChanged: (v) => s.minEntries = int.tryParse(v) ?? 0,
          ),
        ],
      ),
    );
  }

  Widget _saveBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.navy,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Text(
                  _edit ? 'Save changes' : 'Create rule',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
        ),
      ),
    );
  }

  // ── Small builders ──
  Widget _pad(Widget c) => Padding(padding: const EdgeInsets.all(14), child: c);

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
    prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
    isDense: true,
    filled: true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
    ),
  );

  Widget _textField(
    TextEditingController c,
    String label,
    IconData icon, {
    bool number = false,
    int lines = 1,
  }) => TextField(
    controller: c,
    maxLines: lines,
    keyboardType: number ? TextInputType.number : TextInputType.text,
    style: const TextStyle(color: AppColors.textPrimary),
    decoration: _dec(label, icon),
  );

  Widget _chip(String title, bool on, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: on ? AppColors.navy : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: on ? Colors.transparent : AppColors.border),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: on ? Colors.white : AppColors.textSecondary,
        ),
      ),
    ),
  );

  Widget _chipsBlock(String label, List<Widget> chips) => Padding(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
//  Section card (نفس ستايل فلتر الـ Leads)
// ─────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                children: [
                  for (int i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i != children.length - 1)
                      const Divider(height: 1, color: AppColors.border),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  const _IconBox(this.icon);

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: AppColors.navy.withOpacity(0.07),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Icon(icon, size: 20, color: AppColors.navy),
  );
}

/// صف قابل للضغط: أيقونة + عنوان + القيمة الحالية + badge بالعدد
class _PickTile extends StatelessWidget {
  final IconData icon;
  final String title, value;
  final int count;
  final VoidCallback onTap;
  const _PickTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = count > 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _IconBox(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? AppColors.navy : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (count > 1)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          _IconBox(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.navy,
            activeTrackColor: AppColors.gold,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
