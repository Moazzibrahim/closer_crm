// ignore_for_file: deprecated_member_use, unnecessary_underscores
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/widgets/lead_action_sheet.dart';
import 'package:flutter_application_1/core/widgets/lead_card_widget.dart';
import 'package:flutter_application_1/features/comments/presentation/widgets/lead_comment_sheet.dart';
import 'package:flutter_application_1/features/crud/data/stages_model.dart';
import 'package:flutter_application_1/features/crud/providers/crud_service.dart';
import 'package:flutter_application_1/features/leads/presentation/screens/lead_details_screen_master.dart';
import 'package:flutter_application_1/features/leads/presentation/widgets/lead_details_widget.dart';
import 'package:flutter_application_1/features/leads/presentation/widgets/lead_filter_sheet.dart';
import 'package:flutter_application_1/features/leads/data/lead_model.dart'; // LeadItem
import 'package:flutter_application_1/features/leads/providers/admin_leads_filter_service.dart';
import 'package:flutter_application_1/features/leads/providers/leads_service.dart';

class LeadsScreen extends StatefulWidget {
  /// لإعادة الاستخدام: LeadsScreen(myLeads: true) أو LeadsScreen(preset: LeadsFilters(projects: ['id']))
  final bool myLeads;
  final LeadsFilters? preset;
  final LeadDetailsConfig detailsConfig; // صلاحيات صفحة التفاصيل
  final bool canAssign, canChangeStage, canDelete;
  final String defaultSort;

  const LeadsScreen({
    super.key,
    this.myLeads = false,
    this.preset,
    this.detailsConfig = LeadDetailsConfig.admin,
    this.canAssign = true,
    this.canChangeStage = true,
    this.canDelete = true, // delete + trash + restore
    this.defaultSort = '-createdAt',
  });

  @override
  State<LeadsScreen> createState() => LeadsScreenState();
}

class LeadsScreenState extends State<LeadsScreen> {
  // شيل الـ underscore
  late final LeadsController _c;
  final _svc = LeadsService();
  final _scroll = ScrollController();
  final _search = TextEditingController();
  Timer? _debounce;

  int _tab = 0; // 0 = active, 1 = trash
  final Set<String> _stageIds = {}; // فاضية = All
  List<({String id, String name, Color color, bool isDeal})> _stages = [];

  // قوائم اختيارات الفلتر (مشاريع، حملات، ...)
  Map<String, List<Opt>> _opts = {};

  final Set<String> _selected = {};
  bool get _selecting => _selected.isNotEmpty;

  void resetFilters() => _resetAndRefresh();

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.maxScrollExtent - pos.pixels < 400) _c.loadMore();
  }

  @override
  void initState() {
    super.initState();
    _c = LeadsController(myLeads: widget.myLeads, preset: _initialFilters());
    _stageIds.addAll(widget.preset?.stages ?? const []);
    _c.refresh();
    _loadStages();
    _loadFilterOptions();
    _scroll.addListener(_maybeLoadMore);
    _c.addListener(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeLoadMore();
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    _c.dispose();
    super.dispose();
  }

  Future<void> _loadStages() async {
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
    } catch (_) {
      /* الشيبس هتفضل All بس */
    }
  }

  // ⚠️ حل مؤقت بالاسم. لو الـ StageModel فيه نوع (type/isDeal) استخدمه بدل كده.
  bool _isDealStage(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '') == 'donedeal';

  Future<void> _loadFilterOptions() async {
    final o = await LeadFilterOptions.load(includeUsers: !widget.myLeads);
    if (mounted) setState(() => _opts = o);
  }

  // ── Search / filters ──
  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(_selected.clear);
      _c.apply((f) => f.keyword = v);
    });
  }

  void _setTab(int i) {
    if (i == 1 && !widget.canDelete) return; // 👈
    setState(() {
      _tab = i;
      _selected.clear();
    });
    _c.apply((f) => f.isActive = i == 0);
  }

  // ضغطة على stage = تضيفه/تشيله. "All" بتمسح الاختيار
  void _toggleStage(String? id) {
    setState(() {
      if (id == null) {
        _stageIds.clear();
      } else if (!_stageIds.remove(id)) {
        _stageIds.add(id);
      }
      _selected.clear();
    });
    _c.apply((f) => f.stages = _stageIds.toList());
  }

  Future<void> _openFilters() async {
    final r = await showLeadFiltersSheet(
      context,
      _c.filters.copy(),
      opts: _opts,
      fields: widget.myLeads
          ? LeadFilterFields.withoutAssign
          : LeadFilterFields.all,
    );
    if (r == null) return;
    setState(_selected.clear);
    await _c.apply((f) => f.copyAdvancedFrom(r));
  }

  LeadsFilters _initialFilters() {
    final f = widget.preset?.copy() ?? LeadsFilters();
    f.sort = widget.defaultSort;
    f.isActive = true;
    return f;
  }

  /// Pull-to-refresh: بيلغي كل الفلاتر (stage + search + advanced) ويرجّع الافتراضي
  Future<void> _resetAndRefresh() async {
    _debounce?.cancel();
    _search.clear();
    setState(() {
      _stageIds
        ..clear()
        ..addAll(widget.preset?.stages ?? const []);
      _selected.clear();
      _tab = 0;
    });

    _c.filters = _initialFilters();
    await _c.refresh();
  }

  // ── Selection ──
  void _toggle(String id) => setState(() {
    if (!_selected.add(id)) _selected.remove(id);
  });

  void _clearSelection() => setState(_selected.clear);

  void _selectAll() => setState(() {
    if (_selected.length == _c.items.length) {
      _selected.clear();
    } else {
      _selected.addAll(_c.items.map((e) => e.id));
    }
  });

  String get _countLabel =>
      _selected.length == 1 ? '1 lead' : '${_selected.length} leads';

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? const Color(0xFFE5484D) : null,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        ),
      );
  }

  /// بينفذ أكشن على الـ API، وبعدها toast + refresh
  Future<void> _run(Future<void> Function() action, String okMsg) async {
    try {
      await action();
      _toast(okMsg);
      _clearSelection();
      await _c.refresh();
    } catch (e) {
      _toast(e.toString(), error: true);
    }
  }

  // ── Actions ──
  // ملاحظة بتتسجل في الـ history (الشيت مفيهوش حقل نص)
  static const _historyNote = 'Lead reassigned';

  Future<void> _onAssign() async {
    if (!widget.canAssign) return;

    // lead واحد بس: نجيب السيلز الحاليين من الـ API عشان تتعلّم بصح
    var current = <String>[];
    if (_selected.length == 1) {
      try {
        final raw = ldUnwrapLead(await _svc.getLead(_selected.first));
        String? idOf(dynamic u) =>
            (u is Map ? (u['_id'] ?? u['id']) : u)?.toString();
        final ids = <String>{};
        for (final s in (raw['sales'] as List? ?? [])) {
          final id = idOf(s);
          if (id != null && id.isNotEmpty) ids.add(id);
        }
        for (final a in (raw['assignedBy'] as List? ?? []).whereType<Map>()) {
          if (a['isCurrent'] != true) continue;
          final id = idOf(a['sales']);
          if (id != null && id.isNotEmpty) ids.add(id);
        }
        current = ids.toList();
      } catch (_) {}
    }
    if (!mounted) return;

    final result = await showAssignSheet(
      context,
      count: _selected.length,
      showHistoryOptions: !widget.myLeads,
      currentIds: current, // 👈
    );
    if (result == null || !mounted) return;
    // ... باقي الدالة زي ما هو

    await _run(() async {
      final ids = _selected.toList();

      // الـ history/التاريخ الأول، والـ assign آخر حاجة
      if (result.clearHistory || result.resetCreationDate) {
        await Future.wait(
          ids.map((id) async {
            if (result.clearHistory) {
              await _svc.clearHistory(id, notes: _historyNote);
            }
            if (result.resetCreationDate) {
              await _svc.resetCreationDate(
                id,
                result.creationDate ?? DateTime.now(),
                notes: _historyNote,
              );
            }
          }),
        );
      }

      // replace (PATCH) بس للـ leads اللي عندها سيلز، الباقي add (POST)
      final replaceIds = <String>[];
      final addIds = <String>[];
      for (final id in ids) {
        final lead = _c.items.firstWhere((e) => e.id == id);
        if (result.replace && lead.salesman.isNotEmpty) {
          replaceIds.add(id);
        } else {
          addIds.add(id);
        }
      }

      if (replaceIds.isNotEmpty) {
        await _svc.bulkAssign(replaceIds, result.salesIds, mode: 'replace');
      }
      if (addIds.isNotEmpty) {
        await _svc.bulkAssign(addIds, result.salesIds, mode: 'add');
      }
    }, 'Updated assignment for $_countLabel');
  }

  Future<void> _onChangeStage() async {
    if (!widget.canChangeStage) return;

    final currentId = _selected.length == 1
        ? _c.items.firstWhere((e) => e.id == _selected.first).stageId
        : null;
    final result = await showChangeStageSheet(
      context,
      count: _selected.length,
      currentStageId: currentId,
      stages: [
        for (final s in _stages)
          StageOpt(s.id, s.name, s.color, isDeal: s.isDeal),
      ],
      // ⚠️ استبدلها بفحص الرول الحقيقي (Super Admin / Admin بس)
      // showHistoryOptions: !widget.myLeads,
      // مشاريع الـ Done Deal (من نفس قايمة فلتر المشاريع)
      projects: [
        for (final o in _opts['projects'] ?? const <Opt>[])
          (id: o.id, name: o.name),
      ],
    );
    if (result == null || !mounted) return;

    await _run(() async {
      await Future.wait(
        _selected.toList().map((id) => _applyStage(id, result)),
      );
    }, 'Moved $_countLabel to "${result.stage}"');
  }

  /// بيطبّق تغيير الـ stage على lead واحد.
  /// الترتيب مهم: الـ history/التاريخ الأول، والـ stage + الكومنت آخر حاجة
  /// عشان الكومنت الجديد ما يتمسحش مع الـ history.
  Future<void> _applyStage(String id, StageChange r) async {
    await _svc.updateStage(
      id,
      stageId: r.stageId,
      notes: r.note.isEmpty ? null : r.note,
      deal: r.deal,
    );
  }

  /// كومنت بس من غير تغيير stage (نص أو صوت)
  Future<void> _onComment(LeadItem lead) async {
    final added = await showLeadCommentSheet(
      context,
      leadId: lead.id,
      leadName: lead.name,
      lastComment: lead.lastComment,
      currentStageId: lead.stageId,
      stages: [
        for (final s in _stages)
          StageOpt(s.id, s.name, s.color, isDeal: s.isDeal),
      ],
      projects: [
        for (final o in _opts['projects'] ?? const <Opt>[])
          (id: o.id, name: o.name),
      ],
    );
    if (!added || !mounted) return;
    _toast('Comment added');
    await _c.refresh();
  }

  Future<void> _onEdit() async {
    if (_selected.length != 1) {
      _toast('Select one lead to edit its information');
      return;
    }
    final lead = _c.items.firstWhere((e) => e.id == _selected.first);
    final saved = await showEditLeadSheet(
      context,
      lead: LeadEditData(
        id: lead.id,
        name: lead.name,
        phoneCountryCode: lead.phoneCountryCode ?? '',
        phone: lead.phone,
        email: lead.email,
        notes: lead.notes,
      ),
    );
    if (!saved || !mounted) return;
    _toast('Lead information updated');
    _clearSelection();
    await _c.refresh();
  }

  Future<void> _onRestore() async {
    if (!widget.canDelete) return;

    final ids = _selected.toList();
    await _run(
      () => Future.wait(ids.map(_svc.activateLead)),
      '${ids.length == 1 ? '1 lead' : '${ids.length} leads'} restored',
    );
  }

  Future<void> _onDelete() async {
    if (!widget.canDelete) return;
    final ok = await showDeleteLeadsDialog(context, count: _selected.length);
    if (!ok || !mounted) return;

    final ids = _selected.toList();
    await _run(
      () => Future.wait(ids.map(_svc.deactivateLead)),
      '${ids.length == 1 ? '1 lead' : '${ids.length} leads'} moved to trash',
    );
  }

  // ── UI ──
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSelection();
      },
      child: Scaffold(
        backgroundColor: dark ? AppColors.navy : AppColors.background,
        body: ListenableBuilder(
          listenable: _c,
          builder: (context, _) => Stack(
            children: [
              Column(
                children: [
                  Stack(
                    children: [
                      _Header(
                        dark: dark,
                        title: widget.myLeads ? 'My Leads' : 'Leads',
                        total: _c.totalItems,
                        search: _search,
                        onSearch: _onSearch,
                        onFilter: _openFilters,
                        filterDot:
                            _c.filters.advancedCount -
                                (_c.filters.sort == widget.defaultSort &&
                                        widget.defaultSort != '-createdAt'
                                    ? 1
                                    : 0) >
                            0,
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: !_selecting,
                          child: AnimatedOpacity(
                            opacity: _selecting ? 1 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: _SelectionHeader(
                              count: _selected.length,
                              total: _c.items.length,
                              onClose: _clearSelection,
                              onSelectAll: _selectAll,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _resetAndRefresh,
                      child: CustomScrollView(
                        controller: _scroll,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                              child: _Tabs(
                                selected: _tab,
                                dark: dark,
                                showTrash:
                                    widget.canDelete, // 👈 الـ Trash للأدمن بس
                                // التاب الحالي = نتايج الفلتر، التاب التاني بيفضل إجمالي
                                activeCount: _tab == 0
                                    ? _c.totalItems
                                    : _c.totalActive,
                                trashCount: _tab == 1
                                    ? _c.totalItems
                                    : _c.totalInactive,
                                onChanged: _setTab,
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 56,
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                scrollDirection: Axis.horizontal,
                                itemCount: _stages.length + 1,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (_, i) {
                                  final id = i == 0 ? null : _stages[i - 1].id;
                                  return _FilterChip(
                                    label: i == 0 ? 'All' : _stages[i - 1].name,
                                    // All مختارة لما مفيش stages متحددة
                                    selected: id == null
                                        ? _stageIds.isEmpty
                                        : _stageIds.contains(id),
                                    dark: dark,
                                    onTap: () => _toggleStage(id),
                                  );
                                },
                              ),
                            ),
                          ),
                          ..._listSlivers(dark),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: IgnorePointer(
                  ignoring: !_selecting,
                  child: AnimatedSlide(
                    offset: _selecting ? Offset.zero : const Offset(0, 1.5),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: _selecting ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: _SelectionActionBar(
                        dark: dark,
                        trash: _tab == 1,
                        canEdit: _selected.length == 1,
                        onAssign: _onAssign,
                        onStage: _onChangeStage,
                        onEdit: _onEdit,
                        onDelete: _onDelete,
                        onRestore: _onRestore,
                        canAssign: widget.canAssign,
                        canChangeStage: widget.canChangeStage,
                        canDelete: widget.canDelete,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _listSlivers(bool dark) {
    final sub = dark ? Colors.white60 : AppColors.textSecondary;

    if (_c.loading && _c.items.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_c.error != null && _c.items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _c.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFE5484D)),
                  ),
                  TextButton(onPressed: _c.refresh, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      ];
    }
    if (_c.items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              'No leads found',
              style: TextStyle(color: sub, fontSize: 15),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
        sliver: SliverList.separated(
          itemCount: _c.items.length + (_c.loadingMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            if (i >= _c.items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final lead = _c.items[i];
            return LeadCard(
              lead: lead,
              dark: dark,
              selecting: _selecting,
              selected: _selected.contains(lead.id),
              onTap: () async {
                if (_selecting) {
                  _toggle(lead.id);
                } else {
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LeadDetailsScreen(
                        leadId: lead.id,
                        initial: lead,
                        config: widget.detailsConfig,
                      ),
                    ),
                  );
                  if (changed == true && mounted) _c.refresh();
                }
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _toggle(lead.id);
              },
              onNote: () => _onComment(lead),
            );
          },
        ),
      ),
    ];
  }
}

// ─────────────────────────────────────────────
//  Header
// ─────────────────────────────────────────────
class _Header extends StatelessWidget {
  final bool dark, filterDot;
  final String title;
  final int total;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final VoidCallback onFilter;
  const _Header({
    required this.dark,
    required this.title,
    required this.total,
    required this.search,
    required this.onSearch,
    required this.onFilter,
    required this.filterDot,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navy, AppColors.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 16, 20),
          child: Column(
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$total total leads',
                        style: TextStyle(
                          color: AppColors.goldLight.withOpacity(0.9),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _HeaderIcon(
                    icon: Icons.tune_rounded,
                    dot: filterDot,
                    onTap: onFilter,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: Colors.black54,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: search,
                        onChanged: onSearch,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(color: Colors.black),
                        cursorColor: AppColors.navy,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: 'Search name, email or phone',
                          hintStyle: TextStyle(
                            color: Colors.black45,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final bool dot;
  final VoidCallback? onTap;
  const _HeaderIcon({required this.icon, this.dot = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          if (dot)
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.navy, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Tabs
// ─────────────────────────────────────────────
class _Tabs extends StatelessWidget {
  final int selected, activeCount, trashCount;
  final bool dark, showTrash; // 👈
  final ValueChanged<int> onChanged;
  const _Tabs({
    required this.selected,
    required this.dark,
    required this.activeCount,
    required this.trashCount,
    required this.onChanged,
    this.showTrash = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? AppColors.navyLight : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dark
              ? AppColors.goldLight.withOpacity(0.15)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          _TabPill(
            label: 'All Leads',
            count: '$activeCount',
            active: selected == 0,
            dark: dark,
            onTap: () => onChanged(0),
          ),
          if (showTrash)
            _TabPill(
              label: 'Leads Trash',
              count: '$trashCount',
              active: selected == 1,
              dark: dark,
              onTap: () => onChanged(1),
            ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label, count;
  final bool active, dark;
  final VoidCallback onTap;
  const _TabPill({
    required this.label,
    required this.count,
    required this.active,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = dark ? Colors.white60 : AppColors.textSecondary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [AppColors.navy, AppColors.navyLight],
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : inactive,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.gold
                      : (dark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.06)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: active ? AppColors.navy : inactive,
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected, dark;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? (dark ? AppColors.gold : AppColors.navy)
              : (dark ? AppColors.navyLight : AppColors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : (dark
                      ? AppColors.goldLight.withOpacity(0.15)
                      : AppColors.border),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected
                ? (dark ? AppColors.navy : Colors.white)
                : (dark ? Colors.white70 : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Selection header + action bar
// ─────────────────────────────────────────────
class _SelectionHeader extends StatelessWidget {
  final int count, total;
  final VoidCallback onClose, onSelectAll;
  const _SelectionHeader({
    required this.count,
    required this.total,
    required this.onClose,
    required this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    final allSelected = count == total && total > 0;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navy, AppColors.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 20),
          child: Row(
            children: [
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count selected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'of $total loaded leads',
                      style: TextStyle(
                        color: AppColors.goldLight.withOpacity(0.9),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onSelectAll,
                style: TextButton.styleFrom(foregroundColor: AppColors.gold),
                icon: Icon(
                  allSelected
                      ? Icons.deselect_rounded
                      : Icons.select_all_rounded,
                  size: 20,
                ),
                label: Text(
                  allSelected ? 'Clear' : 'Select all',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionActionBar extends StatelessWidget {
  final bool dark, canEdit, trash, canAssign, canChangeStage, canDelete;
  final VoidCallback onAssign, onStage, onEdit, onDelete, onRestore;
  const _SelectionActionBar({
    required this.dark,
    required this.canEdit,
    required this.onAssign,
    required this.onStage,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
    this.canAssign = true,
    this.canChangeStage = true,
    this.canDelete = true,
    this.trash = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: dark ? AppColors.navyLight : AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: dark
              ? AppColors.goldLight.withOpacity(0.18)
              : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.35 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: trash
            ? [
                Expanded(
                  child: _BarAction(
                    icon: Icons.restore_rounded,
                    label: 'Restore',
                    color: const Color(0xFF10B981),
                    dark: dark,
                    onTap: onRestore,
                  ),
                ),
              ]
            : [
                if (canAssign)
                  Expanded(
                    child: _BarAction(
                      icon: Icons.person_add_alt_1_rounded,
                      label: 'Assign',
                      color: dark ? AppColors.gold : AppColors.navy,
                      dark: dark,
                      onTap: onAssign,
                    ),
                  ),
                if (canChangeStage)
                  Expanded(
                    child: _BarAction(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Stage',
                      color: const Color(0xFFF59E0B),
                      dark: dark,
                      onTap: onStage,
                    ),
                  ),
                Expanded(
                  child: _BarAction(
                    icon: Icons.edit_rounded,
                    label: 'Edit',
                    color: const Color(0xFF2563EB),
                    dark: dark,
                    enabled: canEdit,
                    onTap: onEdit,
                  ),
                ),
                if (canDelete)
                  Expanded(
                    child: _BarAction(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      color: const Color(0xFFEF4444),
                      dark: dark,
                      onTap: onDelete,
                    ),
                  ),
              ],
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool dark, enabled;
  final VoidCallback onTap;
  const _BarAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.dark,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.35,
        duration: const Duration(milliseconds: 180),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: dark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
