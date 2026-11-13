// ignore_for_file: deprecated_member_use, unnecessary_underscores
// leads_filter_sheet.dart
// فلتر الـ Leads كـ widget مستقل. استخدمه في أي رول وحدد الحقول اللي تظهر بـ `fields`.
//
// مثال:
//   final opts = await LeadFilterOptions.load();
//   final r = await showLeadFiltersSheet(
//     context, controller.filters.copy(),
//     opts: opts,
//     fields: LeadFilterFields.withoutAssign, // مثلاً للسيلز
//   );
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/features/crud/providers/crud_service.dart';
import 'package:flutter_application_1/features/leads/providers/admin_leads_filter_service.dart';

/// الحقول اللي ممكن تظهر في الفلتر
enum LeadFilterField {
  leadType,
  countryCode,
  phone,
  projects,
  propertyTypes,
  developers,
  campaigns,
  channel,
  communicationWay,
  cities,
  regions,
  areas,
  sales,
  assignedFrom,
  assignedBy,
  assignedTo, // 👈 جديد (للتيم ليدر / المانجر)
  oldStage,
  unassigned,
  toDistribute,
  assignDate,
  hasClosedDeals,
  transferred,
  linkedDeals,
  budget,
  createdDate,
  activityDate,
  followUpDate,
  stale,
  sort,
}

class LeadFilterFields {
  LeadFilterFields._();
  static const Set<LeadFilterField> all = {...LeadFilterField.values};

  // تيم ليدر / مانجر: Assigned to بدون Assigned by
  static final Set<LeadFilterField> team = {...LeadFilterField.values}
    ..remove(LeadFilterField.assignedBy);

  static final Set<LeadFilterField> withoutAssign = {...LeadFilterField.values}
    ..removeAll({
      LeadFilterField.sales,
      LeadFilterField.assignedFrom,
      LeadFilterField.assignedBy,
      LeadFilterField.assignedTo, // 👈
      LeadFilterField.unassigned,
      LeadFilterField.toDistribute,
      LeadFilterField.assignDate,
    });
}

// ─────────────────────────────────────────────
//  تحميل الاختيارات (مشاريع، حملات، ...)
//  (اللوجيك زي ما هو بدون أي تغيير)
// ─────────────────────────────────────────────
class LeadFilterOptions {
  LeadFilterOptions._();

  // الأدوار المسموحة في فلتر الـ Sales
  static const _salesRoles = {'sales', 'teamleader', 'manager'};

  /// المشاريع بس (request واحد بدل 7)
  static Future<List<Opt>> loadProjects() => _load(Endpoints.projects);

  static String _roleOf(Map e) {
    final r = e['role'];
    final raw = r is Map
        ? (r['name'] ?? r['slug'] ?? r['title'] ?? '')
        : (r ?? '');
    return '$raw'.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
  }

  static Future<List<Opt>> _load(String endpoint) async {
    try {
      final r = await CrudService(endpoint).getAll(params: {'limit': 200});
      return (r['data'] as List? ?? [])
          .whereType<Map>()
          .map(
            (e) => Opt(
              '${e['_id'] ?? e['id']}',
              '${e['name'] ?? e['displayName'] ?? e['fullName'] ?? ''}',
            ),
          )
          .where((o) => o.name.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Opt>> _loadSales() async {
    try {
      final r = await CrudService(
        Endpoints.allUsers,
      ).getAll(params: {'limit': 1000});
      return (r['data'] as List? ?? [])
          .whereType<Map>()
          .where((e) => _salesRoles.contains(_roleOf(e)))
          .map((e) {
            final name =
                '${e['name'] ?? e['fullName'] ?? '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'}'
                    .trim();
            return Opt('${e['_id'] ?? e['id']}', name);
          })
          .where((o) => o.name.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// [includeSales] = false لو الرول مالوش فلتر Sales (يوفر request)
  static Future<List<Opt>> _loadUsers({bool salesOnly = false}) async {
    try {
      final r = await CrudService(
        Endpoints.allUsers,
      ).getAll(params: {'limit': 1000});
      return (r['data'] as List? ?? [])
          .whereType<Map>()
          .where((e) => !salesOnly || _salesRoles.contains(_roleOf(e)))
          .map((e) {
            final name =
                '${e['name'] ?? e['fullName'] ?? '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'}'
                    .trim();
            return Opt('${e['_id'] ?? e['id']}', name);
          })
          .where((o) => o.name.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// [includeUsers] = false لو الرول مالوش فلاتر assignment (يوفر request)
  static Future<Map<String, List<Opt>>> load({bool includeUsers = true}) async {
    final res = await Future.wait([
      _load(Endpoints.projects), // 0
      _load(Endpoints.campaigns), // 1
      _load(Endpoints.channels), // 2
      _load(Endpoints.communicationWays), // 3
      _load(Endpoints.cities), // 4
      _load(Endpoints.regions), // 5
      _load(Endpoints.areas), // 6
      _load(Endpoints.propertyTypes), // 7
      _load(Endpoints.developers), // 8
      _load(Endpoints.stages), // 9 (لـ oldStage)
      includeUsers ? _loadUsers() : Future.value(<Opt>[]), // 10 كل اليوزرز
      includeUsers
          ? _loadUsers(salesOnly: true)
          : Future.value(<Opt>[]), // 11 سيلز بس
    ]);
    final allUsers = res[10];
    return {
      'projects': res[0],
      'campaigns': res[1],
      'channel': res[2],
      'communicationWay': res[3],
      'cities': res[4],
      'regions': res[5],
      'areas': res[6],
      'propertyTypes': res[7],
      'developers': res[8],
      'oldStage': res[9],
      'sales': res[11], // سيلز بس
      'assignedFrom': allUsers,
      'assignedBy': allUsers,
    };
  }
}

// ─────────────────────────────────────────────
//  Sheet
// ─────────────────────────────────────────────
Future<LeadsFilters?> showLeadFiltersSheet(
  BuildContext context,
  LeadsFilters current, {
  required Map<String, List<Opt>> opts,
  Set<LeadFilterField> fields = const {...LeadFilterField.values},
}) {
  return showModalBottomSheet<LeadsFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        LeadsFilterSheet(initial: current, opts: opts, fields: fields),
  );
}

// ألوان مشتركة للتصميم (بتتحسب مرة من الـ brightness)
class _Pal {
  final bool dark;
  _Pal(this.dark);

  Color get sheet => dark ? AppColors.navyLight : AppColors.background;
  Color get card => dark ? AppColors.navy : AppColors.white;
  Color get border => dark ? Colors.white12 : AppColors.border;
  Color get text => dark ? Colors.white : AppColors.textPrimary;
  Color get sub => dark ? Colors.white60 : AppColors.textSecondary;
  Color get accent => dark ? AppColors.goldLight : AppColors.navy;
}

class LeadsFilterSheet extends StatefulWidget {
  final LeadsFilters initial;
  final Map<String, List<Opt>> opts;
  final Set<LeadFilterField> fields;
  const LeadsFilterSheet({
    super.key,
    required this.initial,
    required this.opts,
    this.fields = const {...LeadFilterField.values},
  });

  @override
  State<LeadsFilterSheet> createState() => _LeadsFilterSheetState();
}

class _LeadsFilterSheetState extends State<LeadsFilterSheet> {
  late final LeadsFilters f = widget.initial;
  late final _min = TextEditingController(text: f.budgetMin?.toString() ?? '');
  late final _max = TextEditingController(text: f.budgetMax?.toString() ?? '');
  late final _phone = TextEditingController(text: f.phone ?? '');

  bool _has(LeadFilterField x) => widget.fields.contains(x);
  bool _hasAny(List<LeadFilterField> xs) => xs.any(_has);

  static const _sorts = {
    '-createdAt': 'Newest first',
    'createdAt': 'Oldest first',
    '-nextFollowUpAt': 'Follow-up: latest first', // 👈
    'nextFollowUpAt': 'Follow-up: soonest first', // 👈
    '-budget': 'Budget: high → low',
    'budget': 'Budget: low → high',
    'name': 'Name A → Z',
    '-totalSubmissions': 'Most submissions',
  };

  static const _stales = {
    'noComment': 'No comment',
    'untouched': 'Untouched',
    'unassignedOld': 'Unassigned (old)',
  };

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _phone.dispose();
    super.dispose();
  }

  // ── Helpers ──
  InputDecoration _fieldDec(_Pal p, String label, {IconData? icon}) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: p.sub, fontSize: 13),
        prefixIcon: icon == null ? null : Icon(icon, size: 18, color: p.sub),
        isDense: true,
        filled: true,
        fillColor: p.dark ? Colors.white10 : AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
      );

  Widget _pick(
    _Pal p,
    IconData icon,
    String title,
    String key,
    List<String> value, {
    bool single = false,
  }) {
    final options = widget.opts[key] ?? const <Opt>[];
    final names = options
        .where((o) => value.contains(o.id))
        .map((o) => o.name)
        .toList();
    return _TileRow(
      pal: p,
      icon: icon,
      title: title,
      subtitle: names.isEmpty ? 'Any' : names.join(', '),
      count: value.length,
      enabled: options.isNotEmpty,
      onTap: () async {
        final r = await _showPicker(context, title, options, value, single);
        if (r != null) {
          setState(
            () => value
              ..clear()
              ..addAll(r),
          );
        }
      },
    );
  }

  Widget _switchTile(
    _Pal p,
    IconData icon,
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    child: Row(
      children: [
        _IconBox(icon: icon, pal: p),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: p.text,
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

  // chip واحد (بيستخدم للـ Lead type و Stale)
  Widget _chip(_Pal p, String title, bool on, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: on
                ? (p.dark ? AppColors.gold : AppColors.navy)
                : (p.dark ? Colors.white10 : AppColors.background),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? Colors.transparent : p.border),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: on ? (p.dark ? AppColors.navy : Colors.white) : p.sub,
            ),
          ),
        ),
      );

  // بلوك فيه عنوان صغير + chips
  Widget _chipsBlock(_Pal p, String label, List<Widget> chips) => Padding(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: p.sub,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    ),
  );

  Future<void> _pickRange(
    String? from,
    String? to,
    void Function(String? from, String? to) set, {
    bool allowFuture = false,
  }) async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: allowFuture
          ? now.add(const Duration(days: 365))
          : now.add(const Duration(days: 1)),
      initialDateRange: (from != null && to != null)
          ? DateTimeRange(start: DateTime.parse(from), end: DateTime.parse(to))
          : null,
    );
    if (r == null) return;
    String fmt(DateTime d) => d.toIso8601String().substring(0, 10);
    setState(() => set(fmt(r.start), fmt(r.end)));
  }

  Widget _rangeTile(
    _Pal p,
    IconData icon,
    String title,
    String? from,
    String? to,
    void Function(String?, String?) set, {
    bool allowFuture = false,
  }) => _TileRow(
    pal: p,
    icon: icon,
    title: title,
    subtitle: from == null ? 'Any date' : '$from → $to',
    count: from == null ? 0 : 1,
    onTap: () => _pickRange(from, to, set, allowFuture: allowFuture),
    onClear: from == null ? null : () => setState(() => set(null, null)),
  );

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = _Pal(dark);
    final activeCount = f.advancedCount;

    final showLead = _hasAny([
      LeadFilterField.leadType,
      LeadFilterField.countryCode,
      LeadFilterField.phone,
      LeadFilterField.oldStage,
      LeadFilterField.hasClosedDeals,
      LeadFilterField.transferred,
      LeadFilterField.linkedDeals,
    ]);
    final showSource = _hasAny([
      LeadFilterField.projects,
      LeadFilterField.propertyTypes,
      LeadFilterField.developers,
      LeadFilterField.campaigns,
      LeadFilterField.channel,
      LeadFilterField.communicationWay,
    ]);
    final showLocation = _hasAny([
      LeadFilterField.cities,
      LeadFilterField.regions,
      LeadFilterField.areas,
    ]);
    final showAssign = _hasAny([
      LeadFilterField.sales,
      LeadFilterField.assignedFrom,
      LeadFilterField.assignedBy,
      LeadFilterField.assignedTo, // 👈
      LeadFilterField.assignDate,
      LeadFilterField.unassigned,
      LeadFilterField.toDistribute,
    ]);
    final showRange = _hasAny([
      LeadFilterField.budget,
      LeadFilterField.createdDate,
      LeadFilterField.activityDate,
      LeadFilterField.followUpDate,
      LeadFilterField.stale,
    ]);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: p.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: p.dark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.navy, AppColors.navyLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gold.withOpacity(0.5)),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: AppColors.gold,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: p.text,
                        ),
                      ),
                      Text(
                        activeCount == 0
                            ? 'No filters applied'
                            : '$activeCount active',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: activeCount == 0 ? p.sub : AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(
                    context,
                    LeadsFilters(isActive: f.isActive),
                  ),
                  style: TextButton.styleFrom(foregroundColor: p.sub),
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text(
                    'Reset',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          // ── Content ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ───── Lead ─────
                  if (showLead)
                    _Section(
                      pal: p,
                      title: 'Lead',
                      children: [
                        if (_has(LeadFilterField.leadType))
                          _chipsBlock(p, 'Lead type', [
                            _chip(
                              p,
                              'All',
                              f.leadType == null,
                              () => setState(() => f.leadType = null),
                            ),
                            _chip(
                              p,
                              'Fresh',
                              f.leadType == 'Fresh',
                              () => setState(() => f.leadType = 'Fresh'),
                            ),
                            _chip(
                              p,
                              'Cold',
                              f.leadType == 'Cold',
                              () => setState(() => f.leadType = 'Cold'),
                            ),
                          ]),
                        if (_has(LeadFilterField.countryCode))
                          _CountryRow(
                            pal: p,
                            value: f.countryCodes,
                            onChanged: (v) => setState(
                              () => f.countryCodes
                                ..clear()
                                ..addAll(v),
                            ),
                          ),
                        if (_has(LeadFilterField.phone))
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: TextField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              style: TextStyle(color: p.text),
                              decoration: _fieldDec(
                                p,
                                'Phone contains',
                                icon: Icons.phone_rounded,
                              ),
                            ),
                          ),
                        if (_has(LeadFilterField.oldStage))
                          _pick(
                            p,
                            Icons.history_rounded,
                            'Old stage',
                            'oldStage',
                            f.oldStages,
                          ),
                        if (_has(LeadFilterField.hasClosedDeals))
                          _switchTile(
                            p,
                            Icons.handshake_rounded,
                            'Has closed deals',
                            f.hasClosedDeals,
                            (v) => setState(() => f.hasClosedDeals = v),
                          ),
                        // if (_has(LeadFilterField.transferred))
                        //   _switchTile(
                        //     p,
                        //     Icons.swap_horiz_rounded,
                        //     'Transferred',
                        //     f.transferred,
                        //     (v) => setState(() => f.transferred = v),
                        //   ),
                        // if (_has(LeadFilterField.linkedDeals))
                        //   _switchTile(
                        //     p,
                        //     Icons.link_rounded,
                        //     'Linked deals',
                        //     f.linkedDeals,
                        //     (v) => setState(() => f.linkedDeals = v),
                        //   ),
                      ],
                    ),

                  // ───── Source ─────
                  if (showSource)
                    _Section(
                      pal: p,
                      title: 'Source',
                      children: [
                        if (_has(LeadFilterField.projects))
                          _pick(
                            p,
                            Icons.domain_rounded,
                            'Projects',
                            'projects',
                            f.projects,
                          ),
                        if (_has(LeadFilterField.propertyTypes))
                          _pick(
                            p,
                            Icons.apartment_rounded,
                            'Property types',
                            'propertyTypes',
                            f.propertyTypes,
                          ),
                        if (_has(LeadFilterField.developers))
                          _pick(
                            p,
                            Icons.engineering_rounded,
                            'Developer',
                            'developers',
                            f.developers,
                          ),
                        if (_has(LeadFilterField.campaigns))
                          _pick(
                            p,
                            Icons.campaign_rounded,
                            'Campaign',
                            'campaigns',
                            f.campaigns,
                          ),
                        if (_has(LeadFilterField.channel))
                          _pick(
                            p,
                            Icons.hub_rounded,
                            'Channel',
                            'channel',
                            f.channel,
                          ),
                        if (_has(LeadFilterField.communicationWay))
                          _pick(
                            p,
                            Icons.forum_rounded,
                            'Communication way',
                            'communicationWay',
                            f.communicationWay,
                          ),
                      ],
                    ),

                  // ───── Location ─────
                  if (showLocation)
                    _Section(
                      pal: p,
                      title: 'Location',
                      children: [
                        if (_has(LeadFilterField.cities))
                          _pick(
                            p,
                            Icons.location_city_rounded,
                            'Cities',
                            'cities',
                            f.cities,
                          ),
                        if (_has(LeadFilterField.regions))
                          _pick(
                            p,
                            Icons.map_rounded,
                            'Regions',
                            'regions',
                            f.regions,
                          ),
                        if (_has(LeadFilterField.areas))
                          _pick(
                            p,
                            Icons.place_rounded,
                            'Areas',
                            'areas',
                            f.areas,
                          ),
                      ],
                    ),

                  // ───── Assignment ─────
                  if (showAssign)
                    _Section(
                      pal: p,
                      title: 'Assignment',
                      children: [
                        if (_has(LeadFilterField.sales))
                          _pick(
                            p,
                            Icons.badge_rounded,
                            'Sales',
                            'sales',
                            f.sales,
                          ),
                        if (_has(LeadFilterField.assignedFrom))
                          _pick(
                            p,
                            Icons.call_made_rounded,
                            'Assigned from',
                            'assignedFrom',
                            f.assignedFrom,
                          ),
                        if (_has(LeadFilterField.assignedTo))
                          _pick(
                            p,
                            Icons.call_received_rounded,
                            'Assigned to',
                            'assignedTo',
                            f.assignedTo,
                          ),
                        if (_has(LeadFilterField.assignedBy))
                          _pick(
                            p,
                            Icons.assignment_ind_rounded,
                            'Assigned by',
                            'assignedBy',
                            f.assignedBy,
                          ),
                        if (_has(LeadFilterField.assignDate))
                          _rangeTile(
                            p,
                            Icons.event_available_rounded,
                            'Assign date',
                            f.assignDateFrom,
                            f.assignDateTo,
                            (a, b) {
                              f.assignDateFrom = a;
                              f.assignDateTo = b;
                            },
                          ),
                        if (_has(LeadFilterField.unassigned))
                          _switchTile(
                            p,
                            Icons.person_off_rounded,
                            'Unassigned only',
                            f.unassigned,
                            (v) => setState(() => f.unassigned = v),
                          ),
                        if (_has(LeadFilterField.toDistribute))
                          _switchTile(
                            p,
                            Icons.share_rounded,
                            'To distribute',
                            f.toDistribute,
                            (v) => setState(() => f.toDistribute = v),
                          ),
                      ],
                    ),

                  // ───── Budget & Date ─────
                  if (showRange)
                    _Section(
                      pal: p,
                      title: 'Budget & Date',
                      children: [
                        if (_has(LeadFilterField.budget))
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _min,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: p.text),
                                    decoration: _fieldDec(
                                      p,
                                      'Min budget',
                                      icon: Icons.south_rounded,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _max,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: p.text),
                                    decoration: _fieldDec(
                                      p,
                                      'Max budget',
                                      icon: Icons.north_rounded,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_has(LeadFilterField.createdDate))
                          _rangeTile(
                            p,
                            Icons.date_range_rounded,
                            'Created date',
                            f.createdFrom,
                            f.createdTo,
                            (a, b) {
                              f.createdFrom = a;
                              f.createdTo = b;
                            },
                          ),
                        if (_has(LeadFilterField.activityDate))
                          _rangeTile(
                            p,
                            Icons.bolt_rounded,
                            'Last activity',
                            f.activityFrom,
                            f.activityTo,
                            (a, b) {
                              f.activityFrom = a;
                              f.activityTo = b;
                            },
                          ),
                        if (_has(LeadFilterField.followUpDate))
                          _rangeTile(
                            p,
                            Icons.alarm_rounded,
                            'Follow-up date',
                            f.followUpFrom,
                            f.followUpTo,
                            (a, b) {
                              f.followUpFrom = a;
                              f.followUpTo = b;
                            },
                            allowFuture: true,
                          ),
                        if (_has(LeadFilterField.stale))
                          _chipsBlock(p, 'Stale leads', [
                            _chip(
                              p,
                              'All',
                              f.stale == null,
                              () => setState(() => f.stale = null),
                            ),
                            for (final e in _stales.entries)
                              _chip(
                                p,
                                e.value,
                                f.stale == e.key,
                                () => setState(() => f.stale = e.key),
                              ),
                          ]),
                      ],
                    ),

                  // ───── Sort ─────
                  if (_has(LeadFilterField.sort))
                    _Section(
                      pal: p,
                      title: 'Sort',
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: DropdownButtonFormField<String>(
                            value: _sorts.containsKey(f.sort)
                                ? f.sort
                                : null, // 👈
                            isExpanded: true,
                            borderRadius: BorderRadius.circular(14),
                            dropdownColor: p.card,
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: p.sub,
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: p.text,
                            ),
                            decoration: _fieldDec(
                              p,
                              'Sort by',
                              icon: Icons.sort_rounded,
                            ),
                            items: [
                              for (final e in _sorts.entries)
                                DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => f.sort = v ?? '-createdAt'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // ── Apply bar ──
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).viewInsets.bottom +
                  MediaQuery.of(context).padding.bottom +
                  12,
            ),
            decoration: BoxDecoration(
              color: p.card,
              border: Border(top: BorderSide(color: p.border)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  if (_has(LeadFilterField.budget)) {
                    f.budgetMin = num.tryParse(_min.text.trim());
                    f.budgetMax = num.tryParse(_max.text.trim());
                  }
                  if (_has(LeadFilterField.phone)) {
                    final t = _phone.text.trim();
                    f.phone = t.isEmpty ? null : t;
                  }
                  Navigator.pop(context, f);
                },
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  activeCount == 0 ? 'Apply' : 'Apply ($activeCount)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
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

// ─────────────────────────────────────────────
//  Section card: عنوان صغير + كارت فيه الصفوف بينهم divider
// ─────────────────────────────────────────────
class _Section extends StatelessWidget {
  final _Pal pal;
  final String title;
  final List<Widget> children;
  const _Section({
    required this.pal,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
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
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: pal.sub,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: pal.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(pal.dark ? 0.2 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            // ClipRRect عشان الـ ripple ما يخرجش برا الحواف
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                children: [
                  for (int i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i != children.length - 1)
                      Divider(height: 1, indent: 64, color: pal.border),
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

// أيقونة جوه مربع
class _IconBox extends StatelessWidget {
  final IconData icon;
  final _Pal pal;
  const _IconBox({required this.icon, required this.pal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: pal.accent.withOpacity(pal.dark ? 0.15 : 0.09),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 20, color: pal.accent),
    );
  }
}

// ─────────────────────────────────────────────
//  صف قابل للضغط: أيقونة + عنوان + ملخص الاختيار + badge بالعدد
// ─────────────────────────────────────────────
class _TileRow extends StatelessWidget {
  final _Pal pal;
  final IconData icon;
  final String title, subtitle;
  final int count;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _TileRow({
    required this.pal,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.onTap,
    this.enabled = true,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final selected = count > 0;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _IconBox(icon: icon, pal: pal),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: pal.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected ? pal.accent : pal.sub,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected && onClear == null)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
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
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(Icons.close_rounded, size: 18, color: pal.sub),
                  ),
                ),
              Icon(Icons.chevron_right_rounded, size: 22, color: pal.sub),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Picker (multi / single) + search
//  (نفس اللوجيك: Clear بترجّع [] و Done بترجّع المختار)
// ─────────────────────────────────────────────
Future<List<String>?> _showPicker(
  BuildContext context,
  String title,
  List<Opt> options,
  List<String> initial,
  bool single,
) {
  final sel = {...initial};
  var q = '';
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final p = _Pal(Theme.of(ctx).brightness == Brightness.dark);
        final shown = options
            .where((o) => o.name.toLowerCase().contains(q.toLowerCase()))
            .toList();
        return _PickerShell(
          pal: p,
          title: title,
          hint: 'Search $title',
          selectedCount: sel.length,
          heightFactor: 0.75,
          onSearch: (v) => setS(() => q = v),
          onClear: () => Navigator.pop(ctx, <String>[]),
          onDone: () => Navigator.pop(ctx, sel.toList()),
          list: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            itemCount: shown.length,
            itemBuilder: (_, i) {
              final o = shown[i];
              return _CheckTile(
                pal: p,
                title: o.name,
                value: sel.contains(o.id),
                onChanged: (on) => setS(() {
                  if (single) sel.clear();
                  on == true ? sel.add(o.id) : sel.remove(o.id);
                }),
              );
            },
          ),
        );
      },
    ),
  );
}

// ─────────────────────────────────────────────
//  Country code row
// ─────────────────────────────────────────────
class _CountryRow extends StatelessWidget {
  final _Pal pal;
  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  const _CountryRow({
    required this.pal,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _TileRow(
      pal: pal,
      icon: Icons.flag_rounded,
      title: 'Country code',
      subtitle: value.isEmpty ? 'Any' : value.join(', '),
      count: value.length,
      onTap: () async {
        final r = await _showCountryPicker(context, value);
        if (r != null) onChanged(r);
      },
    );
  }
}

Future<List<String>?> _showCountryPicker(
  BuildContext context,
  List<String> initial,
) {
  final all = CountryService().getAll()
    ..sort((a, b) => a.name.compareTo(b.name));
  final sel = {...initial};
  var q = '';

  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final p = _Pal(Theme.of(ctx).brightness == Brightness.dark);
        final shown = all.where((c) {
          final s = q.toLowerCase();
          return c.name.toLowerCase().contains(s) ||
              c.phoneCode.contains(s.replaceAll('+', ''));
        }).toList();

        return _PickerShell(
          pal: p,
          title: 'Country code',
          hint: 'Search country or code',
          selectedCount: sel.length,
          heightFactor: 0.8,
          onSearch: (v) => setS(() => q = v),
          onClear: () => Navigator.pop(ctx, <String>[]),
          onDone: () => Navigator.pop(ctx, sel.toList()),
          list: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            itemCount: shown.length,
            itemBuilder: (_, i) {
              final c = shown[i];
              final code = '+${c.phoneCode}';
              return _CheckTile(
                pal: p,
                title: c.name,
                subtitle: code,
                leading: Text(
                  c.flagEmoji,
                  style: const TextStyle(fontSize: 24),
                ),
                value: sel.contains(code),
                onChanged: (on) => setS(() {
                  on == true ? sel.add(code) : sel.remove(code);
                }),
              );
            },
          ),
        );
      },
    ),
  );
}

// ─────────────────────────────────────────────
//  هيكل مشترك للـ pickers: handle + عنوان + سيرش + قايمة + Clear/Done
// ─────────────────────────────────────────────
class _PickerShell extends StatelessWidget {
  final _Pal pal;
  final String title, hint;
  final int selectedCount;
  final double heightFactor;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear, onDone;
  final Widget list;
  const _PickerShell({
    required this.pal,
    required this.title,
    required this.hint,
    required this.selectedCount,
    required this.heightFactor,
    required this.onSearch,
    required this.onClear,
    required this.onDone,
    required this.list,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * heightFactor,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: pal.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: pal.dark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: pal.text,
                    ),
                  ),
                ),
                if (selectedCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$selectedCount selected',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              onChanged: onSearch,
              style: TextStyle(color: pal.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: pal.sub, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: pal.sub),
                filled: true,
                fillColor: pal.card,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: pal.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: pal.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.gold,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: list),
          // Footer
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: pal.card,
              border: Border(top: BorderSide(color: pal.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: onClear,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: pal.sub,
                        side: BorderSide(color: pal.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: onDone,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.navy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// صف اختيار بـ checkbox بتصميم موحد (للـ pickers)
class _CheckTile extends StatelessWidget {
  final _Pal pal;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool?> onChanged;
  const _CheckTile({
    required this.pal,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: value ? AppColors.gold.withOpacity(0.14) : pal.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onChanged(!value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: value ? AppColors.gold : pal.border,
                width: value ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: pal.text,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(fontSize: 12, color: pal.sub),
                        ),
                    ],
                  ),
                ),
                Checkbox(
                  value: value,
                  onChanged: onChanged,
                  activeColor: AppColors.gold,
                  checkColor: AppColors.navy,
                  side: BorderSide(color: pal.sub, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
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
