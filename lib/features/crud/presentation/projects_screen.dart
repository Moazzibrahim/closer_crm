// projects_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/constants/location_picker_service.dart';
import 'package:flutter_application_1/features/crud/data/areas_model..dart';
import 'package:flutter_application_1/features/crud/data/cities_model.dart';
import 'package:flutter_application_1/features/crud/data/developers_model.dart';
import 'package:flutter_application_1/features/crud/data/projects_model.dart';
import 'package:flutter_application_1/features/crud/data/property_type_model.dart';
import 'package:flutter_application_1/features/crud/providers/crud_service.dart';
import 'package:latlong2/latlong.dart';
// ⚠️ حط location_picker_screen.dart جنب الملف ده (أو عدّل المسار)

const _danger = Color(0xFFE5484D);
const _success = Color(0xFF2E9E6B);

// ⚠️ القيم دي لازم تطابق الـ enum عند الباك إند — عدّلها لو مختلفة
const _statuses = ['Off-Plan', 'Under Construction', 'Ready'];

// ─────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});
  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final _api = CrudService(Endpoints.projects);

  List<ProjectModel> _projects = [];
  ProjectsPagination? _pagination;
  bool _loading = true;
  String? _error;

  String _query = '';
  bool? _showActive; // null = All
  final Set<String> _selected = {};
  List<DeveloperModel> _developers = [];
  List<CityModel> _cities = [];
  List<AreaModel> _areas = [];
  List<RefModel> _types = []; // property types (لسه بـ RefModel)
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await _api.getAll(params: {'limit': 200});
      final res = ProjectsResponse.fromJson(body);
      _projects = res.data;
      _pagination = res.pagination;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  List<ProjectModel> get _filtered {
    final q = _query.toLowerCase();
    return _projects.where((p) {
      if (_showActive != null && p.active != _showActive) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          (p.developer?.name ?? '').toLowerCase().contains(q) ||
          (p.city?.name ?? '').toLowerCase().contains(q) ||
          (p.area?.name ?? '').toLowerCase().contains(q);
    }).toList();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? _danger : AppColors.navy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------- Actions ----------
  Future<void> _openForm([ProjectModel? project]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProjectFormSheet(project: project, api: _api),
    );
    if (saved == true) {
      _snack(project == null ? 'Project added' : 'Project updated');
      _load();
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    Color? actionColor,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action,
              style: TextStyle(
                color: actionColor ?? AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // حذف ناعم (soft delete)
  Future<void> _delete(ProjectModel p) async {
    final ok = await _confirm(
      title: 'Delete project',
      message: '"${p.displayName}" will be deleted. Continue?',
      action: 'Delete',
      actionColor: _danger,
    );
    if (!ok) return;
    try {
      await _api.delete(p.id!);
      _snack('Project deleted');
      _load();
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  // Activate / Deactivate (واحد أو أكتر)
  Future<void> _setActive(List<String> ids, bool active) async {
    if (ids.isEmpty) return;
    final ok = await _confirm(
      title: active ? 'Activate' : 'Deactivate',
      message: active
          ? 'Activate ${ids.length} project(s)?'
          : '${ids.length} project(s) will be deactivated. You can restore them later.',
      action: active ? 'Activate' : 'Deactivate',
      actionColor: active ? AppColors.navy : _danger,
    );
    if (!ok) return;
    try {
      await _api.bulkSetActive(ids, active: active);
      setState(_selected.clear);
      _snack(active ? 'Activated' : 'Deactivated');
      _load();
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  void _toggle(String id) => setState(
    () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
  );

  // لو في active وسط المحدد → Deactivate الـ active بس، غير كده Activate الكل
  void _bulkAction() {
    final sel = _projects.where((p) => _selected.contains(p.id)).toList();
    final activeOnes = sel.where((p) => p.active).toList();
    if (activeOnes.isNotEmpty) {
      _setActive(activeOnes.map((p) => p.id!).toList(), false);
    } else {
      _setActive(sel.map((p) => p.id!).toList(), true);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final list = _filtered;
    final selecting = _selected.isNotEmpty;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.background,
      appBar: AppBar(
        title: Text(
          selecting ? '${_selected.length} selected' : 'Projects',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: isDark ? const Color(0xFF121212) : AppColors.white,
        foregroundColor: isDark ? AppColors.goldLight : AppColors.navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: selecting
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(_selected.clear),
              )
            : null,
        actions: [
          if (selecting)
            IconButton(
              icon: Icon(
                _projects.any((p) => _selected.contains(p.id) && p.active)
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
              ),
              onPressed: _bulkAction,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navy,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_home_work_rounded),
        label: const Text(
          'Add Project',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          _stats(isDark),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search project, developer, city or area',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white10 : AppColors.border,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white10 : AppColors.border,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chip('All', _showActive == null, () => _setFilter(null)),
                _chip('Active', _showActive == true, () => _setFilter(true)),
                _chip(
                  'Inactive',
                  _showActive == false,
                  () => _setFilter(false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _body(list, isDark)),
        ],
      ),
    );
  }

  void _setFilter(bool? v) => setState(() {
    _showActive = v;
    _selected.clear();
  });

  Widget _stats(bool isDark) {
    final total = _pagination?.totalItems ?? _projects.length;
    final active =
        _pagination?.totalActive ?? _projects.where((p) => p.active).length;
    final inactive = _pagination?.totalInactive ?? (total - active);

    Widget item(String label, int value, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          item('Total', total, isDark ? AppColors.goldLight : AppColors.navy),
          const SizedBox(width: 8),
          item('Active', active, _success),
          const SizedBox(width: 8),
          item('Inactive', inactive, _danger),
        ],
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback tap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: on ? Colors.white : AppColors.textSecondary,
        ),
      ),
      selected: on,
      showCheckmark: false,
      selectedColor: AppColors.navy,
      onSelected: (_) => tap(),
    ),
  );

  Widget _body(List<ProjectModel> list, bool isDark) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: _danger)),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'No projects found',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final p = list[i];
          final id = p.id!;
          return _ProjectCard(
            project: p,
            selected: _selected.contains(id),
            isDark: isDark,
            // لو في selection شغّال الضغطة بتعمل toggle، غير كده بتفتح الـ edit
            onTap: () => _selected.isNotEmpty ? _toggle(id) : _openForm(p),
            onLongPress: () => _toggle(id),
            onAction: (a) {
              switch (a) {
                case 'edit':
                  _openForm(p);
                case 'toggle':
                  _setActive([id], !p.active);
                case 'delete':
                  _delete(p);
              }
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Project card
// ─────────────────────────────────────────────
class _ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final bool selected, isDark;
  final VoidCallback onTap, onLongPress;
  final ValueChanged<String> onAction;

  const _ProjectCard({
    required this.project,
    required this.selected,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = project;
    final subtitle = [
      p.developer?.name,
      p.location,
    ].where((e) => e != null && e.isNotEmpty).join('  •  ');

    return Opacity(
      opacity: p.active ? 1 : 0.6,
      child: Material(
        color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? AppColors.gold
                    : (isDark ? Colors.white10 : AppColors.border),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _thumb(p),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              p.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (p.featured) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: AppColors.gold,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle.isEmpty ? '—' : subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.priceRange,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.goldLight : AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (p.completionStatus != null)
                            _pill(
                              p.completionStatus!,
                              AppColors.gold.withOpacity(0.2),
                              isDark ? AppColors.goldLight : AppColors.navy,
                            ),
                          _pill(
                            p.active ? 'Active' : 'Inactive',
                            (p.active ? _success : _danger).withOpacity(0.15),
                            p.active ? _success : _danger,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: onAction,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(p.active ? 'Deactivate' : 'Activate'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: _danger)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // صورة المشروع، ولو مفيش (أو فشلت) بنعرض الحرف الأول. ولو selected بنعرض check
  Widget _thumb(ProjectModel p) {
    final fallback = Text(
      p.initial,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: isDark ? AppColors.goldLight : AppColors.navy,
      ),
    );
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: AppColors.gold)
          : p.thumb.isEmpty
          ? fallback
          : Image.network(
              p.thumb,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg),
    ),
  );
}

// صف واحد من الـ external links (label + url)
class _LinkRow {
  final TextEditingController label, url;
  _LinkRow([String l = '', String u = ''])
    : label = TextEditingController(text: l),
      url = TextEditingController(text: u);
  void dispose() {
    label.dispose();
    url.dispose();
  }
}

// ─────────────────────────────────────────────
//  Add / Edit bottom sheet
// ─────────────────────────────────────────────
class _ProjectFormSheet extends StatefulWidget {
  final ProjectModel? project; // null = add
  final CrudService api;
  const _ProjectFormSheet({this.project, required this.api});

  @override
  State<_ProjectFormSheet> createState() => _ProjectFormSheetState();
}

class _ProjectFormSheetState extends State<_ProjectFormSheet> {
  final _key = GlobalKey<FormState>();
  bool get _isEdit => widget.project != null;
  ProjectModel? get _p => widget.project;

  // ---- Controllers ----
  late final _name = TextEditingController(text: _p?.name);
  late final _startPrice = TextEditingController(
    text: _numText(_p?.startPrice),
  );
  late final _maxPrice = TextEditingController(text: _numText(_p?.maxPrice));
  late final _minArea = TextEditingController(text: _numText(_p?.minArea));
  late final _maxArea = TextEditingController(text: _numText(_p?.maxArea));
  late final _description = TextEditingController(text: _p?.description);
  late final _amenities = TextEditingController(text: _p?.amenities.join(', '));
  late final _images = TextEditingController(text: _p?.images.join(', '));
  late final _brochure = TextEditingController(text: _p?.brochureUrl);
  late final _video = TextEditingController(text: _p?.videoUrl);
  late final _planDesc = TextEditingController(
    text: _p?.paymentPlan.description,
  );
  late final _downPct = TextEditingController(
    text: _numText(_p?.paymentPlan.downPaymentPercentage),
  );
  late final _years = TextEditingController(
    text: _numText(_p?.paymentPlan.installmentYears?.toDouble()),
  );

  // ---- Coordinates + External links ----
  // الموقع المختار من الخريطة (null = مفيش)
  late LatLng? _location = (_p?.lat != null && _p?.lng != null)
      ? LatLng(_p!.lat!, _p!.lng!)
      : null;
  late final List<_LinkRow> _links = (_p?.externalLinks ?? [])
      .map((l) => _LinkRow(l.label, l.url))
      .toList();

  // ---- Selections ----
  late String? _developerId = _p?.developer?.id;
  late String? _cityId = _p?.city?.id;
  late String? _areaId = _p?.area?.id;
  late final Set<String> _typeIds = {
    ...?_p?.propertyTypes.map((e) => e.id).whereType<String>(),
  };
  late String? _status = _p?.completionStatus;
  late DateTime? _delivery = _p?.deliveryDate;
  late bool _featured = _p?.featured ?? false;

  // ---- Lookups (developers / cities / areas / property types) ----
  // ⚠️ تأكد من أسماء الـ Endpoints دي عندك في api_constants.dart

  // بعد
  List<DeveloperModel> _developers = [];
  List<CityModel> _cities = [];
  List<AreaModel> _areas = [];
  List<PropertyTypeModel> _types = []; // كان RefModel
  bool _lookupsLoading = true;
  String? _lookupsError;

  bool _saving = false;

  static String _numText(double? v) => v == null
      ? ''
      : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<Map<String, dynamic>> _get(String path) =>
      CrudService(path).getAll(params: {'limit': 200});

  // بنجيب الـ active بس + العنصر المختار حاليًا (حتى لو بقى inactive في الـ edit)
  Future<void> _loadLookups() async {
    setState(() {
      _lookupsLoading = true;
      _lookupsError = null;
    });
    try {
      final r = await Future.wait([
        _get(Endpoints.developers),
        _get(Endpoints.cities),
        _get(Endpoints.areas),
        _get(Endpoints.propertyTypes),
      ]);

      int byName(String a, String b) =>
          a.toLowerCase().compareTo(b.toLowerCase());

      _developers =
          DevelopersResponse.fromJson(r[0]).data
              .where((d) => d.id != null && (d.active || d.id == _developerId))
              .toList()
            ..sort((a, b) => byName(a.displayName, b.displayName));

      _cities =
          CitiesResponse.fromJson(r[1]).data
              .where((c) => c.id != null && (c.active || c.id == _cityId))
              .toList()
            ..sort((a, b) => byName(a.displayName, b.displayName));

      _areas =
          AreasResponse.fromJson(r[2]).data
              .where((a) => a.id != null && (a.active || a.id == _areaId))
              .toList()
            ..sort((a, b) => byName(a.displayName, b.displayName));

      _types =
          PropertyTypesResponse.fromJson(r[3]).data
              .where(
                (t) => t.id != null && (t.active || _typeIds.contains(t.id)),
              )
              .toList()
            ..sort((a, b) => byName(a.displayName, b.displayName));
    } catch (e) {
      _lookupsError = e.toString();
    }
    if (mounted) setState(() => _lookupsLoading = false);
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _startPrice,
      _maxPrice,
      _minArea,
      _maxArea,
      _description,
      _amenities,
      _images,
      _brochure,
      _video,
      _planDesc,
      _downPct,
      _years,
    ]) {
      c.dispose();
    }
    for (final l in _links) {
      l.dispose();
    }
    super.dispose();
  }

  // ---------- helpers ----------
  List<String> _split(String s) =>
      s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  num? _num(TextEditingController c) => num.tryParse(c.text.trim());

  // الباك إند مستني yyyy-MM-dd (زي "2027-06-01")
  String _dateOnly(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // يفتح الخريطة ويرجّع الموقع المختار
  Future<void> _pickLocation() async {
    final r = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LocationPickerScreen(initial: _location),
      ),
    );
    if (r != null) setState(() => _location = r);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _delivery ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 15),
    );
    if (d != null) setState(() => _delivery = d);
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);

    final plan = <String, dynamic>{
      'description': _planDesc.text.trim(),
      'downPaymentPercentage': _num(_downPct),
      'installmentYears': _num(_years)?.toInt(),
    }..removeWhere((k, v) => v == null || (v is String && v.isEmpty));

    // external links: بنتجاهل أي صف من غير URL
    final links = _links
        .where((l) => l.url.text.trim().isNotEmpty)
        .map((l) => {'label': l.label.text.trim(), 'url': l.url.text.trim()})
        .toList();

    // coordinates: بتتبعت بس لو اتحدد موقع على الخريطة
    final coords = _location == null
        ? null
        : {'lat': _location!.latitude, 'lng': _location!.longitude};

    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'developer': _developerId,
      'city': _cityId,
      'area': _areaId,
      'propertyTypes': _typeIds.toList(),
      'startPrice': _num(_startPrice),
      'maxPrice': _num(_maxPrice),
      'minArea': _num(_minArea),
      'maxArea': _num(_maxArea),
      'completionStatus': _status,
      'deliveryDate': _delivery == null ? null : _dateOnly(_delivery!),
      'description': _description.text.trim(),
      'amenities': _split(_amenities.text),
      'images': _split(_images.text),
      'brochureUrl': _brochure.text.trim(),
      'videoUrl': _video.text.trim(),
      'featured': _featured,
      if (plan.isNotEmpty) 'paymentPlan': plan,
      'externalLinks': links,
      'coordinates': coords,
      if (!_isEdit) 'isActive': true, // المشروع الجديد بيتعمل active
    }..removeWhere((k, v) => v == null || (v is String && v.isEmpty));

    try {
      if (_isEdit) {
        await widget.api.update(_p!.id!, body);
      } else {
        await widget.api.create(body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: _danger),
      );
    }
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _reqNum(String? v) =>
      (v == null || num.tryParse(v.trim()) == null) ? 'Required' : null;

  // رقم اختياري: فاضي مسموح، لكن لو مكتوب لازم يكون رقم
  String? _optNum(String? v) =>
      (v == null || v.trim().isEmpty || num.tryParse(v.trim()) != null)
      ? null
      : 'Invalid number';

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        t,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
      ),
    ),
  );

  Widget _gap() => const SizedBox(height: 12);

  Widget _dropdown({
    required String label,
    required IconData icon,
    required List<_Opt> items,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: items.any((e) => e.id == value) ? value : null,
      isExpanded: true,
      decoration: _dec(label, icon),
      validator: (v) => v == null ? 'Required' : null,
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e.id,
              child: Text(e.label, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _typesPicker(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white24 : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.apartment_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                'Property types (${_typeIds.length} selected)',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_types.isEmpty)
            const Text(
              'No property types available',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in _types)
                  FilterChip(
                    label: Text(
                      t.displayName, // كان t.name
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _typeIds.contains(t.id)
                            ? AppColors.navy
                            : AppColors.textSecondary,
                      ),
                    ),
                    selected: _typeIds.contains(t.id),
                    showCheckmark: true,
                    checkmarkColor: AppColors.navy,
                    selectedColor: AppColors.gold,
                    onSelected: (on) => setState(() {
                      on ? _typeIds.add(t.id!) : _typeIds.remove(t.id);
                    }),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _formBody(bool isDark) {
    final dateText = _delivery == null
        ? 'Delivery date'
        : '${_delivery!.year}-${_delivery!.month.toString().padLeft(2, '0')}-${_delivery!.day.toString().padLeft(2, '0')}';

    return Form(
      key: _key,
      child: Column(
        children: [
          // ===== Basic =====
          TextFormField(
            controller: _name,
            validator: _req,
            textInputAction: TextInputAction.next,
            decoration: _dec('Project name', Icons.home_work_rounded),
          ),
          _gap(),
          _dropdown(
            label: 'Developer',
            icon: Icons.business_rounded,
            items: _developers
                .map((d) => _Opt(d.id, d.name))
                .toList(), // Developer
            value: _developerId,
            onChanged: (v) => setState(() => _developerId = v),
          ),
          _gap(),
          _dropdown(
            label: 'City',
            icon: Icons.location_city_rounded,
            items: _cities.map((c) => _Opt(c.id, c.name)).toList(), // City
            value: _cityId,
            onChanged: (v) => setState(() => _cityId = v),
          ),
          _gap(),
          _dropdown(
            label: 'Area',
            icon: Icons.map_rounded,
            items: _areas.map((a) => _Opt(a.id, a.name)).toList(), // Area
            value: _areaId,
            onChanged: (v) => setState(() => _areaId = v),
          ),
          _gap(),
          _typesPicker(isDark),

          // ===== Pricing & size =====
          _section('Pricing & size'),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _startPrice,
                  keyboardType: TextInputType.number,
                  validator: _reqNum,
                  decoration: _dec('Start price', Icons.payments_rounded),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _maxPrice,
                  keyboardType: TextInputType.number,
                  validator: _optNum,
                  decoration: _dec('Max price', Icons.payments_outlined),
                ),
              ),
            ],
          ),
          _gap(),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _minArea,
                  keyboardType: TextInputType.number,
                  validator: _optNum,
                  decoration: _dec('Min area', Icons.square_foot_rounded),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _maxArea,
                  keyboardType: TextInputType.number,
                  validator: _optNum,
                  decoration: _dec('Max area', Icons.square_foot_rounded),
                ),
              ),
            ],
          ),

          // ===== Status =====
          _section('Status & delivery'),
          DropdownButtonFormField<String>(
            // لو الحالة الحالية مش في القايمة بنضيفها عشان الـ dropdown ما يكراشش
            value: _status,
            decoration: _dec('Completion status', Icons.flag_rounded),
            items: {
              ..._statuses,
              if (_status != null) _status!,
            }.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _status = v),
          ),
          _gap(),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: _dec('Delivery date', Icons.event_rounded).copyWith(
                suffixIcon: _delivery == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() => _delivery = null),
                      ),
              ),
              child: Text(
                dateText,
                style: TextStyle(
                  color: _delivery == null ? AppColors.textSecondary : null,
                ),
              ),
            ),
          ),
          _gap(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.gold,
            title: const Text(
              'Featured',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            value: _featured,
            onChanged: (v) => setState(() => _featured = v),
          ),

          // ===== Payment plan =====
          _section('Payment plan'),
          TextFormField(
            controller: _planDesc,
            decoration: _dec('Description (e.g. 60/40)', Icons.percent_rounded),
          ),
          _gap(),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _downPct,
                  keyboardType: TextInputType.number,
                  validator: _optNum,
                  decoration: _dec('Down payment %', Icons.pie_chart_rounded),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _years,
                  keyboardType: TextInputType.number,
                  validator: _optNum,
                  decoration: _dec('Years', Icons.calendar_month_rounded),
                ),
              ),
            ],
          ),

          // ===== Details & media =====
          _section('Details & media'),
          TextFormField(
            controller: _description,
            maxLines: 3,
            decoration: _dec('Description', Icons.notes_rounded),
          ),
          _gap(),
          TextFormField(
            controller: _amenities,
            decoration: _dec('Amenities (comma separated)', Icons.pool_rounded),
          ),
          _gap(),
          TextFormField(
            controller: _images,
            keyboardType: TextInputType.url,
            decoration: _dec(
              'Image URLs (comma separated)',
              Icons.image_rounded,
            ),
          ),
          _gap(),
          TextFormField(
            controller: _brochure,
            keyboardType: TextInputType.url,
            decoration: _dec('Brochure URL', Icons.picture_as_pdf_rounded),
          ),
          _gap(),
          TextFormField(
            controller: _video,
            keyboardType: TextInputType.url,
            decoration: _dec('Video URL', Icons.play_circle_rounded),
          ),

          // ===== Coordinates =====
          _section('Location'),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickLocation,
            child: InputDecorator(
              decoration: _dec('Location on map', Icons.place_rounded).copyWith(
                suffixIcon: _location == null
                    ? const Icon(Icons.map_rounded)
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() => _location = null),
                      ),
              ),
              child: Text(
                _location == null
                    ? 'Pick location on map'
                    : '${_location!.latitude},  ${_location!.longitude}',
                style: TextStyle(
                  color: _location == null ? AppColors.textSecondary : null,
                ),
              ),
            ),
          ),

          // ===== External links =====
          _section('External links'),
          for (var i = 0; i < _links.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _links[i].label,
                      decoration: _dec('Label', Icons.label_rounded),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _links[i].url,
                      keyboardType: TextInputType.url,
                      decoration: _dec('URL', Icons.link_rounded),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline_rounded,
                      color: _danger,
                    ),
                    onPressed: () => setState(() {
                      _links.removeAt(i).dispose();
                    }),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _links.add(_LinkRow())),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add link'),
              style: TextButton.styleFrom(foregroundColor: AppColors.navy),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _isEdit ? 'Save changes' : 'Create project',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content;
    if (_lookupsLoading) {
      content = const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_lookupsError != null) {
      content = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(_lookupsError!, style: const TextStyle(color: _danger)),
            TextButton(onPressed: _loadLookups, child: const Text('Retry')),
          ],
        ),
      );
    } else {
      content = _formBody(isDark);
    }

    return Container(
      // الشيت ياخد max 92% من الشاشة، وبيسكرول جواه
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEdit ? 'Edit Project' : 'Add Project',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Flexible(child: SingleChildScrollView(child: content)),
          ],
        ),
      ),
    );
  }
}

// عنصر عام للـ dropdown (id + اسم للعرض)
class _Opt {
  final String? id;
  final String label;
  const _Opt(this.id, this.label);
}
