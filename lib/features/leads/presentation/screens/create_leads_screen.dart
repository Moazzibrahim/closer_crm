// create_lead_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/features/auth/providers/auth_service.dart';
import 'package:flutter_application_1/features/crud/data/campaigns_model.dart';
import 'package:flutter_application_1/features/crud/data/channels_model.dart';
import 'package:flutter_application_1/features/crud/data/commway_model.dart';
import 'package:flutter_application_1/features/crud/data/projects_model.dart';
import 'package:flutter_application_1/features/crud/data/stages_model.dart';
import 'package:flutter_application_1/features/crud/data/users_model.dart';
import 'package:flutter_application_1/features/crud/providers/crud_service.dart';
// ⚠️ عدّل المسار ده لمكان leads_service.dart عندك
import 'package:flutter_application_1/features/leads/providers/leads_service.dart';
import 'package:country_picker/country_picker.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

// ─────────────────────────────────────────────
//  Create Lead (مربوط بالـ API)
//
//  الفتح (مثلاً من زرار + في الـ nav bar):
//  final created = await Navigator.of(context, rootNavigator: true).push<bool>(
//    MaterialPageRoute(builder: (_) => const CreateLeadScreen()),
//  );
//  لو created == true اعمل refresh للـ leads list.
// ─────────────────────────────────────────────

// عنصر عام للـ dropdowns / الـ multi-select (id + اسم + لون اختياري)
class _Opt {
  final String id, label;
  final Color? color;
  const _Opt(this.id, this.label, {this.color});
}

class _T {
  final bool dark;
  const _T(this.dark);
  Color get bg => dark ? const Color(0xFF121212) : AppColors.background;
  Color get card => dark ? const Color(0xFF1E1E1E) : AppColors.white;
  Color get field => dark ? const Color(0xFF262626) : AppColors.background;
  Color get text => dark ? Colors.white : AppColors.textPrimary;
  Color get sub => dark ? Colors.white54 : AppColors.textSecondary;
  Color get border => dark ? Colors.white10 : AppColors.border;
  Color get accent => dark ? AppColors.goldLight : AppColors.navy;
}

const Color _danger = Color(0xFFE5484D);

// صف سؤال وإجابة واحد
class _QARow {
  final q = TextEditingController();
  final a = TextEditingController();
  void dispose() {
    q.dispose();
    a.dispose();
  }
}

// ─────────────────────────────────────────────
//  Main Screen
// ─────────────────────────────────────────────
class CreateLeadScreen extends StatefulWidget {
  final bool isAdmin;
  final String? fixedSalesId; // 👈 للسيلز: الليد على نفسه ومفيش dropdown
  final String? teamLeaderId; // 👈 للتيم ليدر: يشوف نفسه + فريقه بس

  const CreateLeadScreen({
    super.key,
    this.isAdmin = false,
    this.fixedSalesId,
    this.teamLeaderId,
  });

  @override
  State<CreateLeadScreen> createState() => _CreateLeadScreenState();
}

class _CreateLeadScreenState extends State<CreateLeadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _svc = LeadsService();

  // Text controllers
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _phone2 = TextEditingController(); // optional
  final _email = TextEditingController();
  final _budget = TextEditingController();
  final _notes = TextEditingController(); // optional

  // Country codes
  // Country (ISO code)
  String _iso1 = 'AE';
  String _iso2 = 'AE';

  // Selections (كلها ids)
  String? _sales;
  String? _channel;
  String? _commWay;
  String? _stage;
  final Set<String> _projectIds = {};
  final Set<String> _campaignIds = {};

  // Lead type: true = Fresh, false = Cold
  bool _isFresh = true;

  // Lookups من الـ API
  List<_Opt> _salesOpts = [];
  List<_Opt> _channelOpts = [];
  List<_Opt> _commWayOpts = [];
  List<_Opt> _stageOpts = [];
  List<_Opt> _projectOpts = [];
  List<_Opt> _campaignOpts = [];
  // الأسئلة والإجابات (للأدمن بس)
  final List<_QARow> _qaRows = [];

  bool _loading = true;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sales = widget.fixedSalesId; // 👈
    _loadLookups();
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _phone2, _email, _budget, _notes]) {
      c.dispose();
    }
    for (final r in _qaRows) {
      r.dispose();
    }
    super.dispose();
  }

  // ---------- Lookups ----------
  Future<void> _loadLookups() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Future<Map<String, dynamic>> get(String path) =>
          CrudService(path).getAll(params: {'limit': 200});

      final needUsers = widget.fixedSalesId == null;

      final r = await Future.wait<Map<String, dynamic>>([
        get(Endpoints.projects),
        get(Endpoints.campaigns),
        get(Endpoints.channels),
        get(Endpoints.communicationWays),
        get(Endpoints.stages),
        if (needUsers) AuthService().getAllUsers(),
      ]);

      int byLabel(_Opt a, _Opt b) =>
          a.label.toLowerCase().compareTo(b.label.toLowerCase());

      // بنعرض الـ active بس
      _projectOpts =
          ProjectsResponse.fromJson(r[0]).data
              .where((p) => p.active)
              .map((p) => _Opt(p.id!, p.displayName))
              .toList()
            ..sort(byLabel);

      _campaignOpts =
          CampaignsResponse.fromJson(r[1]).data
              .where((c) => c.active)
              .map((c) => _Opt(c.id!, c.displayName))
              .toList()
            ..sort(byLabel);
      _channelOpts =
          ChannelsResponse.fromJson(r[2]).data
              .where((c) => c.active)
              .map((c) => _Opt(c.id!, c.displayName))
              .toList()
            ..sort(byLabel);
      _commWayOpts =
          CommunicationWaysResponse.fromJson(r[3]).data
              .where((c) => c.active)
              .map((c) => _Opt(c.id!, c.displayName))
              .toList()
            ..sort(byLabel);
      // الـ stages بنسيبها بترتيب الـ API (غالبًا هو ترتيب الـ pipeline) ومعاها لونها
      _stageOpts = StagesResponse.fromJson(r[4]).data
          .where((s) => s.active)
          .map((s) => _Opt(s.id!, s.displayName, color: s.colorValue))
          .toList();
      // الـ Sales: Sales + Team Leader بس (الـ active منهم)
      if (needUsers) {
        final tlId = widget.teamLeaderId;
        _salesOpts =
            (r[5]['data'] as List? ?? [])
                .whereType<Map>()
                .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e)))
                .where((u) {
                  if (u.id == null || !u.active) return false;
                  if (u.role != 'Sales' && u.role != 'Team Leader') {
                    return false;
                  }
                  // التيم ليدر: نفسه + اللي تحته بس
                  if (tlId != null) {
                    return u.id == tlId || u.teamLeaderId == tlId;
                  }
                  return true;
                })
                .map(
                  (u) => _Opt(
                    u.id!,
                    u.fullName.isEmpty
                        ? (u.email ?? 'Unnamed')
                        : '${u.fullName}  •  ${u.role}',
                  ),
                )
                .toList()
              ..sort(byLabel);
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  // ── Validators ──
  // ── Validators ──
  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

  /// بيتحقق من الرقم حسب الدولة المختارة (الطول + الصيغة)
  String? _phoneCheck(String? v, String iso, {required bool required}) {
    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return required ? 'Phone is required' : null;

    final country = Country.parse(iso);
    try {
      final p = PhoneNumber.parse(
        digits,
        destinationCountry: IsoCode.values.byName(iso),
      );
      if (!p.isValid()) return 'Invalid phone number for ${country.name}';
      return null;
    } catch (_) {
      return 'Invalid phone number for ${country.name}';
    }
  }

  /// الرقم بعد التنظيف (من غير الصفر البادئ) عشان يتبعت للـ API
  String _normalizePhone(String v, String iso) {
    final digits = v.replaceAll(RegExp(r'\D'), '');
    try {
      return PhoneNumber.parse(
        digits,
        destinationCountry: IsoCode.values.byName(iso),
      ).nsn;
    } catch (_) {
      return digits;
    }
  }

  String? _emailV(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email is required';
    if (s.length > 254) return 'Email is too long';
    final ok = RegExp(
      r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@"
      r'[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
      r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*'
      r'\.[A-Za-z]{2,}$',
    ).hasMatch(s);
    if (!ok || s.contains('..')) {
      return 'Enter a valid email (name@example.com)';
    }
    return null;
  }

  String? _dropV(String? v, String label) => v == null ? 'Select $label' : null;

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? _danger : AppColors.navy,
      ),
    );
  }

  void _addQA() => setState(() => _qaRows.add(_QARow()));

  void _removeQA(int i) {
    final row = _qaRows.removeAt(i);
    setState(() {});
    // نعمل dispose بعد الـ frame عشان الـ TextField لسه متبني
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  Widget _qaItem(int i) {
    final t = _T(Theme.of(context).brightness == Brightness.dark);
    final r = _qaRows[i];
    return Container(
      key: ObjectKey(r), // مهم عشان الحذف من النص ما يلخبطش الـ controllers
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.field,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Q&A ${i + 1}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: t.sub,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _removeQA(i),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 18, color: _danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _TextF(
            controller: r.q,
            label: 'Question',
            icon: Icons.help_outline_rounded,
            validator: (v) => _required(v, 'Question'),
          ),
          const SizedBox(height: 10),
          _TextF(
            controller: r.a,
            label: 'Answer',
            icon: Icons.question_answer_rounded,
            validator: (v) => _required(v, 'Answer'),
          ),
        ],
      ),
    );
  }

  // ── Create ──
  Future<void> _create() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    final phone2 = _phone2.text.trim();
    final notes = _notes.text.trim();
    final qa = [
      for (final r in _qaRows)
        {'question': r.q.text.trim(), 'answer': r.a.text.trim()},
    ];

    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'email': _email.text.trim().toLowerCase(),
      'phoneCountryCode': '+${Country.parse(_iso1).phoneCode}',
      'phone': _normalizePhone(_phone.text, _iso1),
      // الرقم التاني اختياري
      if (phone2.isNotEmpty) ...{
        'phone2CountryCode': '+${Country.parse(_iso2).phoneCode}',
        'phone2': _normalizePhone(phone2, _iso2),
      },
      // ... باقي الحقول زي ما هي
      'projects': _projectIds.toList(),
      'campaigns': _campaignIds.toList(),
      'channel': _channel,
      'communicationWay': _commWay,
      'leadType': _isFresh ? 'Fresh' : 'Cold',
      'budget': int.parse(_budget.text.trim()),
      if (notes.isNotEmpty) 'notes': notes,
      'stage': _stage,
      'sales': _sales,
      if (qa.isNotEmpty) 'qa': qa, // 👈
    };

    try {
      await _svc.createLead(body);
      if (!mounted) return;
      _snack('Lead created successfully');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(e.toString(), error: true);
    }
  }

  // ---------- UI ----------
  Widget _phoneRow({
    required TextEditingController controller,
    required String label,
    required String iso,
    required ValueChanged<String> onIso,
    required bool required,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: _CodeF(
            iso: iso,
            onChanged: (c) {
              onIso(c.countryCode);
              // أعد التحقق من الرقم بعد تغيير الدولة لو فيه رقم مكتوب
              if (controller.text.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _formKey.currentState?.validate(),
                );
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TextF(
            controller: controller,
            label: label,
            icon: Icons.phone_rounded,
            keyboard: TextInputType.phone,
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(
                15,
              ), // الحد الأقصى في المعيار الدولي
            ],
            validator: (v) => _phoneCheck(v, iso, required: required),
          ),
        ),
      ],
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        children: [
          // Contact info
          _Section(
            title: 'Contact Info',
            icon: Icons.contact_phone_rounded,
            children: [
              _TextF(
                controller: _name,
                label: 'Full Name',
                icon: Icons.person_rounded,
                capitalization: TextCapitalization.words,
                validator: (v) => _required(v, 'Name'),
              ),
              _phoneRow(
                controller: _phone,
                label: 'Phone Number',
                iso: _iso1,
                onIso: (v) => setState(() => _iso1 = v),
                required: true,
              ),
              _phoneRow(
                controller: _phone2,
                label: 'Phone 2 (optional)',
                iso: _iso2,
                onIso: (v) => setState(() => _iso2 = v),
                required: false,
              ),
              _TextF(
                controller: _email,
                label: 'Email',
                icon: Icons.email_rounded,
                keyboard: TextInputType.emailAddress,
                formatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                validator: _emailV,
              ),
            ],
          ),

          // Source & assignment
          _Section(
            title: 'Source & Assignment',
            icon: Icons.hub_rounded,
            children: [
              if (widget.fixedSalesId == null)
                _DropF(
                  label: 'Sales Name',
                  icon: Icons.badge_rounded,
                  items: _salesOpts,
                  value: _sales,
                  onChanged: (v) => setState(() => _sales = v),
                  validator: (v) => _dropV(v, 'a sales'),
                ),
              _DropF(
                label: 'Channel',
                icon: Icons.share_rounded,
                items: _channelOpts,
                value: _channel,
                onChanged: (v) => setState(() => _channel = v),
                validator: (v) => _dropV(v, 'a channel'),
              ),
              _DropF(
                label: 'Communication Way',
                icon: Icons.forum_rounded,
                items: _commWayOpts,
                value: _commWay,
                onChanged: (v) => setState(() => _commWay = v),
                validator: (v) => _dropV(v, 'a communication way'),
              ),
              _DropF(
                label: 'Stage',
                icon: Icons.flag_rounded,
                items: _stageOpts,
                value: _stage,
                onChanged: (v) => setState(() => _stage = v),
                validator: (v) => _dropV(v, 'a stage'),
              ),
              _MultiF(
                label: 'Projects',
                icon: Icons.domain_rounded,
                items: _projectOpts,
                selected: _projectIds,
                onChanged: (s) => setState(() {
                  _projectIds
                    ..clear()
                    ..addAll(s);
                }),
                validator: (s) =>
                    s.isEmpty ? 'Select at least one project' : null,
              ),
              _MultiF(
                label: 'Campaigns',
                icon: Icons.campaign_rounded,
                items: _campaignOpts,
                selected: _campaignIds,
                onChanged: (s) => setState(() {
                  _campaignIds
                    ..clear()
                    ..addAll(s);
                }),
                validator: (s) =>
                    s.isEmpty ? 'Select at least one campaign' : null,
              ),
            ],
          ),

          // Lead details
          _Section(
            title: 'Lead Details',
            icon: Icons.description_rounded,
            children: [
              _TextF(
                controller: _budget,
                label: 'Budget',
                icon: Icons.payments_rounded,
                keyboard: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => _required(v, 'Budget'),
              ),
              _TextF(
                controller: _notes,
                label: 'Notes (optional)',
                icon: Icons.sticky_note_2_rounded,
                lines: 3,
              ),
              _LeadTypeSwitch(
                isFresh: _isFresh,
                onChanged: (v) => setState(() => _isFresh = v),
              ),
            ],
          ),
          // Questions & Answers (أدمن بس)
          _Section(
            title: 'Questions & Answers',
            icon: Icons.quiz_rounded,
            children: [
              for (int i = 0; i < _qaRows.length; i++) _qaItem(i),
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _addQA,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'Add question',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.gold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
                style: const TextStyle(color: _danger),
              ),
              TextButton(onPressed: _loadLookups, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    return _form();
  }

  @override
  Widget build(BuildContext context) {
    final t = _T(Theme.of(context).brightness == Brightness.dark);
    final ready = !_loading && _error == null;

    return Scaffold(
      backgroundColor: t.bg,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            const _Header(),

            // ── Form ──
            Expanded(child: _body()),

            // ── Bottom buttons ──
            if (ready)
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: t.card,
                    border: Border(top: BorderSide(color: t.border)),
                  ),
                  child: Row(
                    children: [
                      // Cancel
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).maybePop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: t.sub,
                              side: BorderSide(color: t.border, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Create
                      Expanded(
                        flex: 3,
                        child: InkWell(
                          onTap: _saving ? null : _create,
                          borderRadius: BorderRadius.circular(16),
                          child: Opacity(
                            opacity: _saving ? 0.7 : 1,
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.navy, AppColors.navyLight],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.gold,
                                  width: 1.4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.navy.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: _saving
                                  ? const Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.goldLight,
                                        ),
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.person_add_alt_1_rounded,
                                          size: 20,
                                          color: AppColors.goldLight,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Create Lead',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Header
// ─────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final t = _T(Theme.of(context).brightness == Brightness.dark);
    final top = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, top + 10, 16, 20),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: t.dark
              ? [const Color(0xFF1A1F2E), AppColors.navy]
              : [AppColors.navy, AppColors.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: AppColors.goldLight,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create Lead',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Fill in the lead information',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold.withOpacity(0.5)),
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: AppColors.goldLight,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Section card
// ─────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final t = _T(Theme.of(context).brightness == Brightness.dark);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(t.dark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: t.accent),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: t.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // مسافة ثابتة بين الحقول
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Shared input decoration (icon اختياري)
// ─────────────────────────────────────────────
InputDecoration _dec(_T t, String label, IconData? icon) {
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c, width: w),
  );

  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(fontSize: 13.5, color: t.sub),
    floatingLabelStyle: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: t.dark ? AppColors.goldLight : AppColors.navy,
    ),
    prefixIcon: icon == null ? null : Icon(icon, size: 20, color: t.accent),
    filled: true,
    fillColor: t.field,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    border: b(t.border),
    enabledBorder: b(t.border),
    focusedBorder: b(AppColors.gold, 1.6),
    errorBorder: b(_danger),
    focusedErrorBorder: b(_danger, 1.6),
    errorStyle: const TextStyle(fontSize: 11.5),
  );
}

// ── Text field ──
class _TextF extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator; // null = optional
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;
  final TextCapitalization capitalization;
  final int lines;

  const _TextF({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.keyboard,
    this.formatters,
    this.capitalization = TextCapitalization.none,
    this.lines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final t = _T(Theme.of(context).brightness == Brightness.dark);

    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: lines > 1 ? TextInputType.multiline : keyboard,
      inputFormatters: formatters,
      textCapitalization: capitalization,
      minLines: lines,
      maxLines: lines,
      cursorColor: AppColors.gold,
      style: TextStyle(fontSize: 14.5, color: t.text),
      decoration: _dec(t, label, icon),
    );
  }
}

// ── Country code dropdown ──
// ── Country code picker (كل الدول + search) ──
class _CodeF extends StatelessWidget {
  final String iso;
  final ValueChanged<Country> onChanged;
  const _CodeF({required this.iso, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = _T(Theme.of(context).brightness == Brightness.dark);
    final c = Country.parse(iso);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showCountryPicker(
        context: context,
        showPhoneCode: true,
        favorite: const ['AE', 'SA', 'EG'], // بتظهر فوق
        onSelect: onChanged,
        countryListTheme: CountryListThemeData(
          backgroundColor: t.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          bottomSheetHeight: MediaQuery.of(context).size.height * 0.8,
          textStyle: TextStyle(fontSize: 14.5, color: t.text),
          searchTextStyle: TextStyle(color: t.text),
          inputDecoration: _dec(
            t,
            'Search country or code',
            Icons.search_rounded,
          ),
        ),
      ),
      child: InputDecorator(
        decoration: _dec(t, 'Code', null).copyWith(
          suffixIcon: Icon(Icons.keyboard_arrow_down_rounded, color: t.sub),
        ),
        child: Text(
          '${c.flagEmoji} +${c.phoneCode}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: t.text,
          ),
        ),
      ),
    );
  }
}

// ── Dropdown field (values = ids) ──
// ── Dropdown field (values = ids) + Search ──
class _DropF extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<_Opt> items;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const _DropF({
    required this.label,
    required this.icon,
    required this.items,
    required this.value,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final t = _T(Theme.of(context).brightness == Brightness.dark);

    // لو القيمة مش في القايمة (اتشالت مثلاً) نرجّعها null عشان ما يكراشش
    _Opt? current;
    for (final e in items) {
      if (e.id == value) {
        current = e;
        break;
      }
    }
    final safeValue = current?.id;
    return FormField<String>(
      initialValue: safeValue,
      validator: (_) => validator?.call(safeValue),
      builder: (state) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          FocusScope.of(context).unfocus();
          final r = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) =>
                _SingleSheet(title: label, items: items, selected: safeValue),
          );
          if (r != null) {
            onChanged(r);
            state.didChange(r);
            // لو كان فيه error ظاهر، نعيد التحقق بعد ما الـ parent يتبني بالقيمة الجديدة
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (state.mounted && state.hasError) state.validate();
            });
          }
        },
        child: InputDecorator(
          isEmpty: current == null,
          decoration: _dec(t, label, icon).copyWith(
            errorText: state.errorText,
            suffixIcon: Icon(Icons.keyboard_arrow_down_rounded, color: t.sub),
          ),
          child: current == null
              ? const SizedBox.shrink()
              : Row(
                  children: [
                    // نقطة لون (للـ stages)
                    if (current.color != null) ...[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: current.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        current.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14.5, color: t.text),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Single-select bottom sheet with search ──
class _SingleSheet extends StatefulWidget {
  final String title;
  final List<_Opt> items;
  final String? selected;
  const _SingleSheet({
    required this.title,
    required this.items,
    required this.selected,
  });

  @override
  State<_SingleSheet> createState() => _SingleSheetState();
}

class _SingleSheetState extends State<_SingleSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = _T(Theme.of(context).brightness == Brightness.dark);
    final list = widget.items
        .where((i) => i.label.toLowerCase().contains(_q.toLowerCase()))
        .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: t.text,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: t.sub),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => setState(() => _q = v),
              cursorColor: AppColors.gold,
              style: TextStyle(color: t.text),
              decoration: _dec(t, 'Search', Icons.search_rounded),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nothing found',
                        style: TextStyle(color: t.sub),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final o = list[i];
                        final isSel = o.id == widget.selected;
                        return ListTile(
                          onTap: () => Navigator.pop(context, o.id),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          leading: o.color == null
                              ? null
                              : Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: o.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                          horizontalTitleGap: 8,
                          minLeadingWidth: 10,
                          title: Text(
                            o.label,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: isSel
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSel ? t.accent : t.text,
                            ),
                          ),
                          trailing: isSel
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.gold,
                                )
                              : null,
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

// ─────────────────────────────────────────────
//  Multi-select field (Projects / Campaigns)
// ─────────────────────────────────────────────
class _MultiF extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<_Opt> items;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final String? Function(Set<String>)? validator;

  const _MultiF({
    required this.label,
    required this.icon,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final t = _T(Theme.of(context).brightness == Brightness.dark);
    final chosen = items.where((i) => selected.contains(i.id)).toList();

    return FormField<Set<String>>(
      initialValue: selected,
      validator: (_) => validator?.call(selected),
      builder: (state) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final r = await showModalBottomSheet<Set<String>>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) =>
                _MultiSheet(title: label, items: items, selected: selected),
          );
          if (r != null) {
            onChanged(r);
            state.didChange(r);
          }
        },
        child: InputDecorator(
          isEmpty: chosen.isEmpty,
          decoration: _dec(t, label, icon).copyWith(
            errorText: state.errorText,
            suffixIcon: Icon(Icons.keyboard_arrow_down_rounded, color: t.sub),
          ),
          child: chosen.isEmpty
              ? const SizedBox.shrink()
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in chosen)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          c.label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: t.accent,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _MultiSheet extends StatefulWidget {
  final String title;
  final List<_Opt> items;
  final Set<String> selected;
  const _MultiSheet({
    required this.title,
    required this.items,
    required this.selected,
  });

  @override
  State<_MultiSheet> createState() => _MultiSheetState();
}

class _MultiSheetState extends State<_MultiSheet> {
  late final Set<String> _sel = {...widget.selected};
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = _T(Theme.of(context).brightness == Brightness.dark);
    final list = widget.items
        .where((i) => i.label.toLowerCase().contains(_q.toLowerCase()))
        .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.title} (${_sel.length})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: t.text,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _sel.isEmpty ? null : () => setState(_sel.clear),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => setState(() => _q = v),
              style: TextStyle(color: t.text),
              decoration: _dec(t, 'Search', Icons.search_rounded),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nothing found',
                        style: TextStyle(color: t.sub),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final o = list[i];
                        return CheckboxListTile(
                          value: _sel.contains(o.id),
                          onChanged: (on) => setState(() {
                            on == true ? _sel.add(o.id) : _sel.remove(o.id);
                          }),
                          title: Text(
                            o.label,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: t.text,
                            ),
                          ),
                          activeColor: AppColors.gold,
                          checkColor: AppColors.navy,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _sel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Lead type switch (Fresh / Cold)
// ─────────────────────────────────────────────
class _LeadTypeSwitch extends StatelessWidget {
  final bool isFresh;
  final ValueChanged<bool> onChanged;
  const _LeadTypeSwitch({required this.isFresh, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = _T(Theme.of(context).brightness == Brightness.dark);

    Widget option(String label, IconData icon, bool value) {
      final selected = isFresh == value;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(value);
          },
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? AppColors.goldLight : t.sub,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : t.sub,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'LEAD TYPE',
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: t.sub,
            ),
          ),
        ),
        Container(
          height: 50,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: t.field,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.border),
          ),
          child: Stack(
            children: [
              // المؤشر المتحرك
              AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment: isFresh
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.navy, AppColors.navyLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gold, width: 1.2),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  option('Fresh', Icons.fiber_new_rounded, true),
                  option('Cold', Icons.ac_unit_rounded, false),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
