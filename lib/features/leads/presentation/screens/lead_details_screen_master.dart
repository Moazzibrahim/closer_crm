// ignore_for_file: deprecated_member_use, unnecessary_underscores, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/widgets/lead_action_sheet.dart';
import 'package:flutter_application_1/features/comments/data/last_comment_model.dart';
import 'package:flutter_application_1/features/comments/presentation/screens/all_comments_screen.dart';
import 'package:flutter_application_1/features/comments/presentation/widgets/last_comment_card.dart';
import 'package:flutter_application_1/features/comments/presentation/widgets/lead_comment_sheet.dart';
import 'package:flutter_application_1/features/comments/providers/comments_service.dart';
import 'package:flutter_application_1/features/crud/data/stages_model.dart';
import 'package:flutter_application_1/features/crud/providers/crud_service.dart';
import 'package:flutter_application_1/features/leads/data/lead_model.dart';
import 'package:flutter_application_1/features/leads/presentation/widgets/edit_done_deal_widget.dart';
import 'package:flutter_application_1/features/leads/presentation/widgets/lead_details_widget.dart';
import 'package:flutter_application_1/features/leads/presentation/widgets/lead_filter_sheet.dart';
import 'package:flutter_application_1/features/leads/providers/admin_leads_filter_service.dart';
import 'package:flutter_application_1/features/leads/providers/leads_service.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────
//  إعدادات الصفحة لكل role: إيه اللي يظهر وإيه اللي يتعمل
// ─────────────────────────────────────────────
class LeadDetailsConfig {
  final bool canChangeStage;
  final bool canAssign;
  final bool canComment;
  final bool canCall;
  final bool showAssignHistory;
  final bool canSeeSubmissions;

  /// الـ history sections + Added By للـ admin بس
  final bool canSeeHistory;

  final bool allowHistoryOptions;
  final Set<String> hiddenRows;
  final bool canCommentWithoutStage;
  final bool canAddDeal; // زرار Add deal
  final bool canSeeDealDetails; // كل بيانات الـ Deal: الأدمن بس
  final bool canEditDeal; // 👈 جديد: تعديل الـ deal
  final bool canDeleteDeal; // 👈 جديد: حذف الـ deal (الأدمن بس)

  const LeadDetailsConfig({
    this.canChangeStage = true,
    this.canAssign = true,
    this.canComment = true,
    this.canCall = true,
    this.showAssignHistory = true,
    this.allowHistoryOptions = false,
    this.canSeeSubmissions = false,
    this.canCommentWithoutStage = false, // الافتراضي: لازم يغيّر stage
    this.canSeeHistory = false, // الافتراضي مخفي لأي role
    this.canAddDeal = true,
    this.canEditDeal = true, // 👈 لكل الرولز
    this.canDeleteDeal = false, // 👈 الافتراضي ممنوع
    this.canSeeDealDetails = true, // 👈 كل الرولز تشوف كل التفاصيل
    this.hiddenRows = const {},
  });

  static const admin = LeadDetailsConfig(
    allowHistoryOptions: true,
    canSeeSubmissions: true,
    canSeeHistory: true,
    canChangeStage: true,
    canCommentWithoutStage: true,
    //  canSeeDealDetails: true,
    canDeleteDeal: true, // 👈 الأدمن بس
  );
  static const manager = LeadDetailsConfig(
    hiddenRows: {'Added By'},
    canChangeStage: false,
    showAssignHistory: false,
  );
  static const teamLeader = LeadDetailsConfig(
    hiddenRows: {'Added By'},
    canChangeStage: false,
    showAssignHistory: false,
  );
  static const sales = LeadDetailsConfig(
    canChangeStage: false,
    canAssign: false,
    showAssignHistory: false,
    hiddenRows: {'Added By', 'Sales'},
  );
  static const marketer = LeadDetailsConfig(
    canChangeStage: false,
    canAssign: false,
    canComment: false,
    // canAddDeal: false, // الماركتر مالوش يضيف deal
    showAssignHistory: false,
  );
}

// ─────────────────────────────────────────────
//  الفتح:
//  final changed = await Navigator.push<bool>(context, MaterialPageRoute(
//    builder: (_) => LeadDetailsScreen(leadId: id, initial: lead,
//                                      config: LeadDetailsConfig.sales)));
//  بترجّع true لو حصل تغيير (عشان الليست تعمل refresh)
// ─────────────────────────────────────────────
class LeadDetailsScreen extends StatefulWidget {
  final String leadId;
  final LeadItem? initial;
  final LeadDetailsConfig config;

  // 👇 نفس باراميترات LeadsScreen الخاصة بالـ assign
  final bool allowAssignTeamLeader;
  final String? teamOwnerId;
  final bool teamOwnerIsManager;
  final String? teamOwnerName;
  final bool canResetCreationDate;
  final bool useUserLookup;

  const LeadDetailsScreen({
    super.key,
    required this.leadId,
    this.initial,
    this.config = const LeadDetailsConfig(),
    this.allowAssignTeamLeader = true,
    this.teamOwnerId,
    this.teamOwnerIsManager = false,
    this.teamOwnerName,
    this.canResetCreationDate = true,
    this.useUserLookup = false,
  });

  @override
  State<LeadDetailsScreen> createState() => _LeadDetailsScreenState();
}

class _LeadDetailsScreenState extends State<LeadDetailsScreen> {
  final _leads = LeadsService();
  final _commentsSvc = CommentsService();

  Map<String, dynamic>? _raw; // الـ JSON الكامل للـ lead
  LeadItem? _item;
  List<LastComment> _comments = [];
  List<({String id, String name, Color color, bool isDeal})> _stages = [];
  List<Opt> _projects = [];

  String? _error;
  bool _changed = false; // للـ refresh في الليست

  LeadDetailsConfig get _cfg => widget.config;

  // ids السيلز الحاليين للـ lead (من sales، وfallback من assignedBy اللي isCurrent)
  ({List<String> ids, Map<String, String> names}) get _currentSales {
    final ids = <String>{};
    final names = <String, String>{};

    String? idOf(dynamic u) =>
        (u is Map ? (u['_id'] ?? u['id']) : u)?.toString();

    void add(dynamic u) {
      // الشكل: { user: {...}, isCurrent, assignedAs }
      if (u is Map && u['user'] != null) {
        if (u['isCurrent'] == false) return;
        u = u['user'];
      }
      final id = idOf(u);
      if (id == null || id.isEmpty) return;
      ids.add(id);
      if (u is Map) {
        final n =
            (u['fullName'] ??
                    u['name'] ??
                    '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}')
                .toString()
                .trim();
        if (n.isNotEmpty) names[id] = n;
      }
    }

    final s = _raw?['sales'];
    if (s is List) {
      s.forEach(add);
    } else if (s != null) {
      add(s);
    }

    for (final a in (_raw?['assignedBy'] as List? ?? []).whereType<Map>()) {
      if (a['isCurrent'] == true) add(a['sales']);
    }
    return (ids: ids.toList(), names: names);
  }

  // ── Deals / Linked ──
  List<Map> get _deals =>
      (_raw?['closedDeals'] as List? ?? []).whereType<Map>().toList();

  List<Map> get _linked =>
      (_raw?['linkedContacts'] as List? ?? []).whereType<Map>().toList();

  // لو الليد ده نفسه linked على ليد أصلي
  Map? get _linkedTo =>
      _raw?['linkedTo'] is Map ? _raw!['linkedTo'] as Map : null;

  String _money(dynamic v) => v is num
      ? v
            .toStringAsFixed(0)
            .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')
      : '';

  String _pct(dynamic v) => v is num ? '$v%' : '';
  String _date(dynamic v) => fmtLeadDate(DateTime.tryParse('${v ?? ''}'));

  Future<void> _openLead(String id) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LeadDetailsScreen(
          leadId: id,
          config: widget.config,
          allowAssignTeamLeader: widget.allowAssignTeamLeader,
          teamOwnerId: widget.teamOwnerId,
          teamOwnerIsManager: widget.teamOwnerIsManager,
          teamOwnerName: widget.teamOwnerName,
          canResetCreationDate: widget.canResetCreationDate,
          useUserLookup: widget.useUserLookup,
        ),
      ),
    );
    if (changed == true) {
      _changed = true;
      await _load();
    }
  }

  // 👈 اتصال بالرقم التاني
  Future<void> _callPhone(String full) async {
    final phone = full.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.isEmpty) return;
    try {
      await launchUrl(
        Uri(scheme: 'tel', path: phone),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  Future<void> _addDeal() async {
    final lead = _item;
    if (lead == null) return;

    if (_stages.isEmpty) await _loadStages();
    final dealStages = [
      for (final s in _stages.where((s) => s.isDeal))
        StageOpt(s.id, s.name, s.color, isDeal: true),
    ];
    if (dealStages.isEmpty) {
      _snack('No deal stages found', error: true);
      return;
    }

    final r = await showAddDealSheet(
      context,
      dealStages: dealStages,
      projects: [for (final o in _projects) (id: o.id, name: o.name)],
      defaultStageId: lead.stageId,
    );
    if (r == null || !mounted) return;

    try {
      await _leads.addDeal(
        lead.id,
        mode: r.mode == DealMode.merge ? 'merge' : 'newContact',
        stageId: r.stageId,
        deal: r.deal,
        contact: r.contact,
      );
      _changed = true;
      _snack(
        r.mode == DealMode.merge
            ? 'Deal added'
            : 'Deal added to a new linked contact',
      );
      await _load(); // يجيب closedDeals + linkedContacts محدثين
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  // ── تعديل deal ──
  Future<void> _editDeal(Map d) async {
    if (!_cfg.canEditDeal) return;
    final dealId = '${d['_id'] ?? d['id'] ?? ''}';
    if (dealId.isEmpty) {
      _snack('Deal id not found', error: true);
      return;
    }
    final body = await showEditDealSheet(context, d); // الحقول اللي اتغيرت بس
    if (body == null || !mounted) return;
    try {
      await _leads.updateDeal(widget.leadId, dealId, body);
      _changed = true; // عشان الليست اللي قبلها تعمل refresh
      _snack('Deal updated');
      await _load(); // يجيب الداتا محدثة
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  // ── حذف deal (الأدمن بس) ──
  Future<void> _deleteDeal(Map d) async {
    if (!_cfg.canDeleteDeal) return; // حماية إضافية
    final dealId = '${d['_id'] ?? d['id'] ?? ''}';
    if (dealId.isEmpty) {
      _snack('Deal id not found', error: true);
      return;
    }
    // تأكيد قبل الحذف
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete deal?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFE5484D)),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _leads.deleteDeal(widget.leadId, dealId);
      _changed = true;
      _snack('Deal deleted');
      await _load();
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  // ── Deal widgets ──

  // صف label/value صغير جوه كارت الـ Deal (الفاضي بيتشال)
  Widget _dealRow(LdTheme t, String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9.5,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w600,
                color: t.sub,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: t.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dealCard(LdTheme t, Map d) {
    final full = _cfg.canSeeDealDetails; // الأدمن بس بيشوف كل التفاصيل

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الهيدر: الوحدة + الـ stage
            // الهيدر: الوحدة + الـ stage + أزرار التعديل/الحذف
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${d['unitNumber'] ?? '-'} • ${d['unitType'] ?? ''}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: t.text,
                    ),
                  ),
                ),
                if (d['stage'] is Map)
                  Text(
                    ldS(d['stage']),
                    style: TextStyle(
                      color: ldHex((d['stage'] as Map)['color']?.toString()),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                if (_cfg.canEditDeal) // 👈 كل الرولز
                  InkWell(
                    onTap: () => _editDeal(d),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: t.accent,
                      ),
                    ),
                  ),
                if (_cfg.canDeleteDeal) // 👈 الأدمن بس
                  InkWell(
                    onTap: () => _deleteDeal(d),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Color(0xFFE5484D),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              ldS(d['project']),
              style: TextStyle(fontSize: 12.5, color: t.text),
            ),
            const SizedBox(height: 6),

            if (!full) ...[
              // العرض المختصر لباقي الـ roles
              Text(
                'Price ${_money(d['unitPrice'])}',
                style: TextStyle(fontSize: 12.5, color: t.text),
              ),
              if ('${d['contactName'] ?? ''}'.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'For: ${d['contactName']}',
                    style: TextStyle(fontSize: 12, color: t.text),
                  ),
                ),
            ] else ...[
              // كل البيانات للأدمن
              Divider(height: 18, color: t.border),
              _dealRow(t, 'Developer', ldS(d['developer'])),
              _dealRow(t, 'Closed by (Sales)', ldPersonName(d['sales'])),
              _dealRow(t, 'Unit price', _money(d['unitPrice'])),
              _dealRow(t, 'Amount paid', _money(d['amountPaid'])),
              _dealRow(t, 'Commission %', _pct(d['companyCommissionRatio'])),
              _dealRow(t, 'Commission', _money(d['companyCommissionMoney'])),
              _dealRow(t, 'Cashback %', _pct(d['cashbackRatio'])),
              _dealRow(t, 'Cashback', _money(d['cashbackMoney'])),
              _dealRow(t, 'Net commission', _money(d['netCommission'])),
              _dealRow(
                t,
                'Closed at',
                d['closedAt'] == null ? '' : _date(d['closedAt']),
              ),
              if ('${d['contactName'] ?? ''}'.isNotEmpty ||
                  '${d['contactPhone'] ?? ''}'.isNotEmpty) ...[
                _dealRow(t, 'Contact name', '${d['contactName'] ?? ''}'),
                _dealRow(
                  t,
                  'Contact phone',
                  '${d['contactPhoneCountryCode'] ?? ''} ${d['contactPhone'] ?? ''}'
                      .trim(),
                ),
              ],
              Divider(height: 18, color: t.border),
              _dealRow(t, 'Added by', ldPersonName(d['addedBy'])),
              _dealRow(
                t,
                'Created',
                d['createdAt'] == null ? '' : _date(d['createdAt']),
              ),
              if (d['editedBy'] != null) ...[
                _dealRow(t, 'Edited by', ldPersonName(d['editedBy'])),
                _dealRow(
                  t,
                  'Edited at',
                  d['editedAt'] == null ? '' : _date(d['editedAt']),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _dealsSection(LdTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LdSectionTitle(
          'Deals (${_deals.length})',
          trailing: _cfg.canAddDeal
              ? TextButton.icon(
                  onPressed: _addDeal,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add deal'),
                  style: TextButton.styleFrom(foregroundColor: t.accent),
                )
              : null,
        ),
        for (final d in _deals) _dealCard(t, d),
      ],
    );
  }

  Widget _linkedSection(LdTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LdSectionTitle('Linked Contacts (${_linked.length})'),
        for (final c in _linked)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openLead('${c['_id']}'),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link_rounded, size: 20, color: t.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${c['name'] ?? ''}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: t.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${c['phoneCountryCode'] ?? ''} ${c['phone'] ?? ''}'
                            '${c['currentStage'] is Map ? '  •  ${ldS(c['currentStage'])}' : ''}',
                            style: TextStyle(fontSize: 12.5, color: t.sub),
                          ),
                          // deals بتاعة الـ contact ده
                          for (final d
                              in (c['closedDeals'] as List? ?? [])
                                  .whereType<Map>())
                            Text(
                              '${d['unitNumber'] ?? ''} • ${_money(d['unitPrice'])}',
                              style: TextStyle(fontSize: 12, color: t.text),
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: t.sub),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // لو الليد ده نفسه linked على ليد أصلي
  Widget _linkedToBanner(LdTheme t) {
    final o = _linkedTo!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openLead('${o['_id']}'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.gold.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.link_rounded, size: 18, color: t.text),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Linked to ${ldS(o)} (tap to open)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: t.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _item = widget.initial;
    _load();
    if (_cfg.canChangeStage || _cfg.canComment || _cfg.canAddDeal) {
      _loadStages(); // canAddDeal عشان زرار Add deal محتاج الـ stages
    }
  }

  // id → name للـ projects / campaigns / channel الموجودين في الـ lead
  Map<String, String> get _idNames {
    final j = _raw ?? {};
    final m = <String, String>{};
    void add(dynamic o) {
      if (o is Map && o['_id'] != null) m['${o['_id']}'] = ldS(o);
    }

    for (final p in (j['projects'] as List? ?? [])) {
      add(p);
    }
    for (final c in (j['campaigns'] as List? ?? [])) {
      add(c);
    }
    add(j['channel']);
    return m;
  }

  // ── Loading ──
  Future<void> _load() async {
    try {
      // الليد والكومنتات بالتوازي
      final res = await Future.wait([
        _leads.getLead(widget.leadId),
        _commentsSvc.getComments(widget.leadId),
      ]);
      final raw = ldUnwrapLead(res[0]);
      if (!mounted) return;
      setState(() {
        _raw = raw;
        _item = LeadItem.fromJson(raw);
        _comments = ldParseComments(res[1]);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _loadStages() async {
    // 1) الـ stages لوحدها، من غير ما تستنى أي حاجة تانية
    try {
      final r = await CrudService(
        Endpoints.stages,
      ).getAll(params: {'limit': 200});
      final list = StagesResponse.fromJson(r).data
          .where((s) => s.active)
          .map(
            (s) => (
              id: s.id!,
              name: s.displayName,
              color: s.colorValue,
              isDeal: _isDealStage(s.displayName),
            ),
          )
          .toList();
      if (mounted) setState(() => _stages = list);
    } catch (e, st) {
      debugPrint('❌ load stages failed: $e\n$st');
    }

    // 2) مشاريع الـ Done Deal منفصلة، لو فشلت الـ stages تفضل شغالة
    try {
      final p = await LeadFilterOptions.loadProjects();
      if (mounted) setState(() => _projects = p);
    } catch (e) {
      debugPrint('❌ load projects failed: $e');
    }
  }

  // ⚠️ حل مؤقت بالاسم (زي leads_screen)
  bool _isDealStage(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '') == 'donedeal';

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? const Color(0xFFE5484D) : AppColors.navy,
        ),
      );
  }

  // ── Actions ──
  Future<void> _addComment() async {
    final lead = _item;
    if (lead == null) return;

    // الـ non-admin محتاج الـ stages عشان يقدر يبعت، فنحاول تاني لو فشلت
    if (!_cfg.canCommentWithoutStage && _stages.isEmpty) await _loadStages();
    if (!_cfg.canCommentWithoutStage && _stages.isEmpty) {
      _snack('Could not load stages, try again', error: true);
      return;
    }

    final added = await showLeadCommentSheet(
      context,
      leadId: lead.id,
      leadName: lead.name,
      lastComment: _comments.isEmpty ? null : _comments.first,
      currentStageId: lead.stageId,
      canSkipStage: _cfg.canCommentWithoutStage,
      stages: [
        for (final s in _stages)
          StageOpt(s.id, s.name, s.color, isDeal: s.isDeal),
      ],
      projects: [for (final o in _projects) (id: o.id, name: o.name)],
    );
    if (!added || !mounted) return;
    _changed = true;
    _snack('Comment added');
    await _load();
  }

  Future<void> _changeStage({bool dealOnly = false}) async {
    // 👈
    final lead = _item;
    if (lead == null) return;

    if (_stages.isEmpty) await _loadStages();
    if (_stages.isEmpty) {
      _snack('Could not load stages, try again', error: true);
      return;
    }
    if (dealOnly && !_stages.any((s) => s.isDeal)) {
      // 👈
      _snack('No deal stages found', error: true);
      return;
    }

    final r = await showChangeStageSheet(
      context,
      count: 1,
      currentStageId: lead.stageId,
      stages: [
        for (final s in _stages)
          StageOpt(s.id, s.name, s.color, isDeal: s.isDeal),
      ],
      projects: [for (final o in _projects) (id: o.id, name: o.name)],
      dealOnly: dealOnly, // 👈
    );
    // ... باقي الدالة زي ما هي (updateStage بيبعت stage + deal من غير notes)
    if (r == null || !mounted) return;

    try {
      await _leads.updateStage(
        lead.id,
        stageId: r.stageId,
        notes: r.note.isEmpty ? null : r.note,
        deal: r.deal,
      );

      _changed = true;
      _snack('Stage changed to "${r.stage}"');
      await _load();
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  Future<void> _assign() async {
    final lead = _item;
    if (lead == null) return;

    final cur = _currentSales;
    final current = cur.ids;

    final canHistory =
        _cfg.allowHistoryOptions &&
        (_raw?['permissions'] as Map?)?['canClearHistory'] == true;

    if (canHistory && _stages.isEmpty) await _loadStages();

    final r = await showAssignSheet(
      context,
      count: 1,
      showHistoryOptions: canHistory,
      currentIds: current,
      currentNames: cur.names,
      stages: canHistory
          ? [
              for (final s in _stages)
                StageOpt(s.id, s.name, s.color, isDeal: s.isDeal),
            ]
          : const [],
      // 👇 نفس اللي في LeadsScreen
      allowTeamLeader: widget.allowAssignTeamLeader,
      allowResetCreationDate: widget.canResetCreationDate,
      teamOwnerId: widget.teamOwnerId,
      teamOwnerName: widget.teamOwnerName,
      teamOwnerIsManager: widget.teamOwnerIsManager,
      allowAddToCurrent: widget.teamOwnerId == null,
      useUserLookup: widget.useUserLookup,
    );
    if (r == null || !mounted) return;
    // ... باقي الدالة (bulkAssignActions) زي ما هي
    try {
      await _leads.bulkAssignActions(
        [lead.id],
        salesIds: r.salesIds,
        mode: (r.replace && current.isNotEmpty) ? 'replace' : 'add',
        assignedAs: r.target == AssignTarget.teamLeader
            ? 'teamLeader'
            : 'sales',
        stageId: r.stage?.id,
        resetDate: r.resetCreationDate ? r.creationDate : null,
        clearHistoryNotes: r.clearHistory ? 'Lead reassigned' : null,
      );

      _changed = true;
      _snack('Assigned to ${r.names}');
      await _load();
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  Future<void> _openAllComments() async {
    final lead = _item;
    if (lead == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AllCommentsScreen(
          canSkipStage: _cfg.canCommentWithoutStage,
          lead: lead,
          canComment: _cfg.canComment,
          stages: [
            for (final s in _stages)
              StageOpt(s.id, s.name, s.color, isDeal: s.isDeal),
          ],
          projects: [for (final o in _projects) (id: o.id, name: o.name)],
        ),
      ),
    );
    if (changed == true) {
      _changed = true;
      await _load();
    }
  }

  // ── Derived data ──
  List<LdAssignEntry> get _assignHistory {
    final list = (_raw?['assignedBy'] as List? ?? []).whereType<Map>().toList();
    // الحاليين الأول، وبعدهم الأحدث
    list.sort((a, b) {
      final c =
          (b['isCurrent'] == true ? 1 : 0) - (a['isCurrent'] == true ? 1 : 0);
      if (c != 0) return c;
      return '${b['assignedAt']}'.compareTo('${a['assignedAt']}');
    });
    return [
      for (final a in list)
        LdAssignEntry(
          ldPersonName(a['sales']),
          // manual → اللي عمل الـ assign، غير كده نعرض الـ via
          ldPersonName(a['by']).isNotEmpty
              ? ldPersonName(a['by'])
              : '${a['via'] ?? ''}',
          fmtLeadDate(DateTime.tryParse('${a['assignedAt'] ?? ''}')),
          a['isCurrent'] == true,
        ),
    ].where((e) => e.name.isNotEmpty).toList();
  }

  // ISO strings بتترتب صح كنص → الأحدث الأول
  List<LdTimelineEntry> get _stagesHistory {
    final list = (_raw?['stages'] as List? ?? []).whereType<Map>().toList()
      ..sort((a, b) => '${b['stageDate']}'.compareTo('${a['stageDate']}'));
    return [
      for (final s in list)
        LdTimelineEntry(
          // في الـ details الـ stage جاية object (في الليست id بس)
          title: s['stage'] is Map ? ldS(s['stage']) : 'Unknown stage',
          color: s['stage'] is Map
              ? ldHex((s['stage'] as Map)['color']?.toString())
              : AppColors.gold,
          current: s['isCurrent'] == true,
          meta: [
            if (ldPersonName(s['changedBy']).isNotEmpty)
              'by ${ldPersonName(s['changedBy'])}',
            fmtLeadDate(DateTime.tryParse('${s['stageDate'] ?? ''}')),
          ].join('  •  '),
          notes: '${s['notes'] ?? ''}'.trim(),
        ),
    ];
  }

  List<LdTimelineEntry> get _creationHistory {
    final list =
        (_raw?['creationDates'] as List? ?? []).whereType<Map>().toList()
          ..sort((a, b) => '${b['changedAt']}'.compareTo('${a['changedAt']}'));
    return [
      for (final c in list)
        LdTimelineEntry(
          // العنوان = تاريخ الإنشاء نفسه، والـ meta = مين غيّره وإمتى
          title: fmtLeadDate(DateTime.tryParse('${c['date'] ?? ''}')),
          color: AppColors.gold,
          current: c['isCurrent'] == true,
          meta: [
            if (ldPersonName(c['changedBy']).isNotEmpty)
              'by ${ldPersonName(c['changedBy'])}',
            'changed ${fmtLeadDate(DateTime.tryParse('${c['changedAt'] ?? ''}'))}',
          ].join('  •  '),
          notes: '${c['notes'] ?? ''}'.trim(),
        ),
    ];
  }

  List<LdRow> get _rows {
    final j = _raw ?? {};
    final lead = _item!;
    final projects = (j['projects'] as List? ?? []).whereType<Map>().toList();
    final developer = projects
        .map((p) => ldS(p['developer']))
        .where((e) => e.isNotEmpty)
        .toSet()
        .join(', ');
    final budget = j['budget'];
    final budgetText = budget is num
        ? budget
              .toStringAsFixed(0)
              .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')
        : '';
    final location = [
      ldNames(j['cities']),
      ldNames(j['regions']),
      ldNames(j['areas']),
    ].where((e) => e.isNotEmpty).join(' • ');

    final rows = <LdRow>[
      LdRow(Icons.hub_rounded, 'Channel', ldS(j['channel'])),
      LdRow(Icons.badge_rounded, 'Sales', lead.salesman),
      LdRow(Icons.domain_rounded, 'Project', ldNames(j['projects'])),
      LdRow(Icons.apartment_rounded, 'Developer', developer),
      LdRow(Icons.place_rounded, 'Location', location),
      LdRow(Icons.work_rounded, 'Job Description', ldS(j['jobDescription'])),
      LdRow(Icons.email_rounded, 'Email', lead.email ?? '', copy: true),
      LdRow(
        Icons.phone_android_rounded,
        'Phone 2',
        lead.fullPhone2, // 👈 من الموديل (الفاضي بيتشال تلقائي)
        copy: true,
        // 👈 زرار Call للأدوار اللي مسموح لها بالاتصال
        actionLabel: (_cfg.canCall && lead.hasPhone2) ? 'Call' : null,
        onAction: (_cfg.canCall && lead.hasPhone2)
            ? () => _callPhone(lead.fullPhone2)
            : null,
      ),
      LdRow(Icons.campaign_rounded, 'Campaign', ldNames(j['campaigns'])),
      LdRow(
        Icons.link_rounded,
        'Campaign Link',
        ldS(j['campaignLink']),
        copy: true,
      ),
      LdRow(
        Icons.forum_rounded,
        'Communication Way',
        ldS(j['communicationWay']),
      ),
      LdRow(Icons.local_fire_department_rounded, 'Lead Type', lead.leadType),
      LdRow(Icons.payments_rounded, 'Budget', budgetText),
      LdRow(Icons.person_pin_rounded, 'Added By', ldPersonName(j['addedBy'])),
      LdRow(
        Icons.event_rounded,
        'Creation Date',
        lead.created == null ? '' : fmtLeadDate(lead.created),
      ),
      LdRow(
        Icons.assignment_turned_in_rounded,
        'Total Submissions',
        '${j['totalSubmissions'] ?? ''}',
        actionLabel: ((j['totalSubmissions'] as num?) ?? 0) > 1 ? 'View' : null,
        onAction: ((j['totalSubmissions'] as num?) ?? 0) > 1
            ? () => showLdSubmissionsSheet(
                context,
                (j['allVersions'] as List? ?? []).whereType<Map>().toList(),
                names: _idNames,
              )
            : null,
      ),
      LdRow(Icons.notes_rounded, 'Notes', lead.notes ?? ''),
    ];
    // فاضي أو متخفي في الـ config → يتشال
    return rows
        .where(
          (r) =>
              r.value.trim().isNotEmpty &&
              !_cfg.hiddenRows.contains(r.label) &&
              (r.label != 'Total Submissions' || _cfg.canSeeSubmissions) &&
              // Added By للـ admin بس
              (r.label != 'Added By' || _cfg.canSeeHistory),
        )
        .toList();
  }

  // ── UI ──
  void _back() => Navigator.of(context).pop(_changed);

  @override
  Widget build(BuildContext context) {
    final t = LdTheme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(backgroundColor: t.bg, body: _body(t)),
    );
  }

  Widget _body(LdTheme t) {
    // لسه مفيش حاجة نعرضها
    if (_item == null) {
      return Column(
        children: [
          LdHeader(item: null, onBack: _back),
          Expanded(
            child: _error != null
                ? LdErrorView(message: _error!, onRetry: _load)
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    final lead = _item!;

    // كل الـ history sections للـ admin بس
    final history = (_cfg.canSeeHistory && _cfg.showAssignHistory)
        ? _assignHistory
        : const <LdAssignEntry>[];

    final stagesHistory = _cfg.canSeeHistory
        ? _stagesHistory
        : const <LdTimelineEntry>[];

    // الـ API هو اللي بيحدد مين يشوف تاريخ الإنشاء + لازم يكون admin
    final canSeeCreation =
        _cfg.canSeeHistory &&
        (_raw?['permissions'] as Map?)?['canSeeCreationHistory'] == true;
    final creationHistory = canSeeCreation
        ? _creationHistory
        : const <LdTimelineEntry>[];

    // الأزرار السريعة حسب الصلاحيات
    final actions = <Widget>[
      if (_cfg.canChangeStage)
        LdActionButton(
          icon: Icons.swap_horiz_rounded,
          label: 'Change Stage',
          onTap: _changeStage,
        ),
      if (_cfg.canAssign)
        LdActionButton(
          icon: Icons.person_add_alt_1_rounded,
          label: 'Assign',
          gold: true,
          onTap: _assign,
        ),
      if (_cfg.canComment)
        LdActionButton(
          icon: Icons.add_comment_rounded,
          label: 'Comment',
          onTap: _addComment,
        ),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.zero,
        children: [
          LdHeader(item: lead, onBack: _back, canCall: _cfg.canCall),

          // لو الليد ده linked على ليد أصلي
          if (_linkedTo != null) _linkedToBanner(t),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFE5484D),
                  fontSize: 12.5,
                ),
              ),
            ),

          // ── Quick actions ──
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  for (int i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: actions[i]),
                  ],
                ],
              ),
            ),

          // ── Lead info ──
          const LdSectionTitle('Lead Information'),
          LdInfoCard(rows: _rows, onCopied: () => _snack('Copied')),

          // ── Questions & Answers (بتظهر بس لو فيه داتا) ──
          if (lead.qa.isNotEmpty) ...[
            const LdSectionTitle('Questions & Answers'),
            LdQACard(items: lead.qa),
          ],

          // ── Deals + Linked contacts ──
          if (_deals.isNotEmpty) _dealsSection(t),
          if (_linked.isNotEmpty) _linkedSection(t),

          // ── Assign history ──
          if (history.isNotEmpty) ...[
            const LdSectionTitle('Assign History'),
            LdHistoryCard(items: history),
          ],

          // ── Stages history ──
          if (stagesHistory.isNotEmpty) ...[
            const LdSectionTitle('Stages History'),
            LdTimelineCard(items: stagesHistory),
          ],

          // ── Creation dates ──
          if (creationHistory.isNotEmpty) ...[
            const LdSectionTitle('Creation Dates'),
            LdTimelineCard(items: creationHistory),
          ],

          // ── Comments ──
          LdSectionTitle(
            'Comments',
            trailing: TextButton(
              onPressed: _openAllComments,
              style: TextButton.styleFrom(
                foregroundColor: t.accent,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'All Comments (${_comments.length})',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _comments.isEmpty
                ? LdEmptyComments(onTap: _cfg.canComment ? _addComment : null)
                : LastCommentCard(comment: _comments.first, leadId: lead.id),
          ),

          // ── Buttons تحت الكومنتات ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                if (_cfg.canComment) ...[
                  Expanded(
                    child: LdBottomBtn(
                      icon: Icons.add_comment_rounded,
                      label: 'Add comment',
                      filled: true,
                      onTap: _addComment,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: LdBottomBtn(
                    icon: Icons.forum_rounded,
                    label: 'All comments',
                    onTap: _openAllComments,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}
