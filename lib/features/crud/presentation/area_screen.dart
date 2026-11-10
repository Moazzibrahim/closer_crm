// areas_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/features/crud/data/areas_model..dart';
import 'package:flutter_application_1/features/crud/data/regions_model.dart';
import 'package:flutter_application_1/features/crud/providers/crud_service.dart';
// ⚠️ حط areas_model.dart في نفس فولدر projects_model.dart (أو عدّل المسار)
// ⚠️ لازم يكون عندك Endpoints.areas و Endpoints.regions في api_constants.dart

const _danger = Color(0xFFE5484D);
const _success = Color(0xFF2E9E6B);

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _fmtDate(DateTime? d) =>
    d == null ? '' : '${d.day} ${_months[d.month - 1]} ${d.year}';

// ─────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────
class AreasScreen extends StatefulWidget {
  const AreasScreen({super.key});
  @override
  State<AreasScreen> createState() => _AreasScreenState();
}

class _AreasScreenState extends State<AreasScreen> {
  final _api = CrudService(Endpoints.areas);

  List<AreaModel> _areas = [];
  AreasPagination? _pagination;
  bool _loading = true;
  String? _error;

  String _query = '';
  bool? _showActive; // null = All
  final Set<String> _selected = {};

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
      final res = AreasResponse.fromJson(body);
      _areas = res.data;
      _pagination = res.pagination;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  // البحث بالاسم أو الـ region أو الـ location
  List<AreaModel> get _filtered {
    final q = _query.toLowerCase();
    return _areas.where((a) {
      if (_showActive != null && a.active != _showActive) return false;
      if (q.isEmpty) return true;
      return a.name.toLowerCase().contains(q) ||
          a.regionName.toLowerCase().contains(q) ||
          (a.location ?? '').toLowerCase().contains(q);
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
  Future<void> _openForm([AreaModel? area]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AreaFormSheet(area: area, api: _api),
    );
    if (saved == true) {
      _snack(area == null ? 'Area added' : 'Area updated');
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
  Future<void> _delete(AreaModel a) async {
    final ok = await _confirm(
      title: 'Delete area',
      message: '"${a.displayName}" will be deleted. Continue?',
      action: 'Delete',
      actionColor: _danger,
    );
    if (!ok) return;
    try {
      await _api.delete(a.id!);
      _snack('Area deleted');
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
          ? 'Activate ${ids.length} area(s)?'
          : '${ids.length} area(s) will be deactivated. You can restore them later.',
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
    final sel = _areas.where((a) => _selected.contains(a.id)).toList();
    final activeOnes = sel.where((a) => a.active).toList();
    if (activeOnes.isNotEmpty) {
      _setActive(activeOnes.map((a) => a.id!).toList(), false);
    } else {
      _setActive(sel.map((a) => a.id!).toList(), true);
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
          selecting ? '${_selected.length} selected' : 'Areas',
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
                _areas.any((a) => _selected.contains(a.id) && a.active)
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
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text(
          'Add Area',
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
                hintText: 'Search area, region or location',
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
    final total = _pagination?.totalItems ?? _areas.length;
    final active =
        _pagination?.totalActive ?? _areas.where((a) => a.active).length;
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

  Widget _body(List<AreaModel> list, bool isDark) {
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
          'No areas found',
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
          final a = list[i];
          final id = a.id!;
          return _AreaCard(
            area: a,
            selected: _selected.contains(id),
            isDark: isDark,
            // لو في selection شغّال الضغطة بتعمل toggle، غير كده بتفتح الـ edit
            onTap: () => _selected.isNotEmpty ? _toggle(id) : _openForm(a),
            onLongPress: () => _toggle(id),
            onAction: (act) {
              switch (act) {
                case 'edit':
                  _openForm(a);
                case 'toggle':
                  _setActive([id], !a.active);
                case 'delete':
                  _delete(a);
              }
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Area card
// ─────────────────────────────────────────────
class _AreaCard extends StatelessWidget {
  final AreaModel area;
  final bool selected, isDark;
  final VoidCallback onTap, onLongPress;
  final ValueChanged<String> onAction;

  const _AreaCard({
    required this.area,
    required this.selected,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final a = area;
    final subtitle = [
      if (a.addedByName != null) 'Added by ${a.addedByName}',
      if (a.createdAt != null) _fmtDate(a.createdAt),
    ].join('  •  ');

    return Opacity(
      opacity: a.active ? 1 : 0.6,
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // أيقونة المنطقة، ولو selected بنعرض check
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    selected ? Icons.check_rounded : Icons.place_rounded,
                    color: selected
                        ? AppColors.gold
                        : (isDark ? AppColors.goldLight : AppColors.navy),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      // الـ location النصي
                      if (a.location != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          a.location!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (a.regionName.isNotEmpty)
                            _pill(
                              a.regionName,
                              AppColors.gold.withOpacity(0.2),
                              isDark ? AppColors.goldLight : AppColors.navy,
                            ),
                          _pill(
                            a.active ? 'Active' : 'Inactive',
                            (a.active ? _success : _danger).withOpacity(0.15),
                            a.active ? _success : _danger,
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
                      child: Text(a.active ? 'Deactivate' : 'Activate'),
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

// ─────────────────────────────────────────────
//  Add / Edit bottom sheet
// ─────────────────────────────────────────────
class _AreaFormSheet extends StatefulWidget {
  final AreaModel? area; // null = add
  final CrudService api;
  const _AreaFormSheet({this.area, required this.api});

  @override
  State<_AreaFormSheet> createState() => _AreaFormSheetState();
}

class _AreaFormSheetState extends State<_AreaFormSheet> {
  final _key = GlobalKey<FormState>();
  bool get _isEdit => widget.area != null;

  late final _name = TextEditingController(text: widget.area?.name);
  late final _location = TextEditingController(text: widget.area?.location);
  late String? _regionId = widget.area?.region?.id;

  // ---- Regions (للـ dropdown) ----
  List<RegionModel> _regions = [];
  bool _regionsLoading = true;
  String? _regionsError;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    setState(() {
      _regionsLoading = true;
      _regionsError = null;
    });
    try {
      final body = await CrudService(
        Endpoints.regions,
      ).getAll(params: {'limit': 200});
      // بنستخدم RegionsResponse نفسه (بيشيل أي عنصر من غير id)
      final all = RegionsResponse.fromJson(body).data;
      // الـ active بس + الـ region الحالي للمنطقة حتى لو بقى inactive
      _regions = all.where((r) => r.active || r.id == _regionId).toList();
    } catch (e) {
      _regionsError = e.toString();
    }
    if (mounted) setState(() => _regionsLoading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);

    final loc = _location.text.trim();
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'region': _regionId,
      // في الـ edit بنبعته دايمًا (عشان يتمسح لو فضّاه)، وفي الـ add بس لو مكتوب
      if (_isEdit || loc.isNotEmpty) 'location': loc,
      if (!_isEdit) 'isActive': true, // المنطقة الجديدة بتتعمل active
    };

    try {
      if (_isEdit) {
        await widget.api.update(widget.area!.id!, body);
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

  Widget _regionField() {
    if (_regionsLoading) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_regionsError != null) {
      return Row(
        children: [
          Expanded(
            child: Text(_regionsError!, style: const TextStyle(color: _danger)),
          ),
          TextButton(onPressed: _loadRegions, child: const Text('Retry')),
        ],
      );
    }
    return DropdownButtonFormField<String>(
      value: _regions.any((r) => r.id == _regionId) ? _regionId : null,
      isExpanded: true,
      decoration: _dec('Region', Icons.map_rounded),
      validator: (v) => v == null ? 'Required' : null,
      items: _regions
          .map(
            (r) => DropdownMenuItem(
              value: r.id,
              child: Text(r.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _regionId = v),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
        child: SingleChildScrollView(
          child: Form(
            key: _key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isEdit ? 'Edit Area' : 'Add Area',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                  decoration: _dec('Area name', Icons.place_rounded),
                ),
                const SizedBox(height: 12),
                _regionField(),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _location,
                  maxLines: 2,
                  textInputAction: TextInputAction.done,
                  decoration: _dec(
                    'Location (address)',
                    Icons.pin_drop_rounded,
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
                            _isEdit ? 'Save changes' : 'Create area',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
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
