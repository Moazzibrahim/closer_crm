// stages_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/features/crud/data/stage_type_model.dart';
import 'package:flutter_application_1/features/crud/data/stages_model.dart';
import 'package:flutter_application_1/features/crud/providers/crud_service.dart';
// ⚠️ لازم يكون عندك Endpoints.stages و Endpoints.stageTypes في api_constants.dart

const _danger = Color(0xFFE5484D);
const _success = Color(0xFF2E9E6B);

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtDate(DateTime? d) =>
    d == null ? '' : '${d.day} ${_months[d.month - 1]} ${d.year}';

// ألوان جاهزة للاختيار السريع
const _palette = [
  '#4C6FFF', '#F2545B', '#2ECC71', '#E67E22', '#9B59B6',
  '#34495E', '#EC4899', '#95A5A6', '#F1C40F', '#1ABC9C',
];

final _hexRe = RegExp(r'^#[0-9A-Fa-f]{6}$');

// ─────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────
class StagesScreen extends StatefulWidget {
  const StagesScreen({super.key});
  @override
  State<StagesScreen> createState() => _StagesScreenState();
}

class _StagesScreenState extends State<StagesScreen> {
  final _api = CrudService(Endpoints.stages);

  List<StageModel> _stages = [];
  StagesPagination? _pagination;
  bool _loading = true;
  String? _error;

  String _query = '';
  bool? _showActive; // null = All
  String? _typeFilter; // stage type id (null = كل الأنواع)
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
      final res = StagesResponse.fromJson(body);
      _stages = res.data;
      _pagination = res.pagination;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  // الأنواع الموجودة فعلًا في الداتا (للـ filter chips)
  List<StageTypeRef> get _typesInData {
    final map = <String, StageTypeRef>{};
    for (final s in _stages) {
      final t = s.stageType;
      if (t?.id != null) map[t!.id!] = t;
    }
    return map.values.toList();
  }

  List<StageModel> get _filtered {
    final q = _query.toLowerCase();
    return _stages.where((s) {
      if (_showActive != null && s.active != _showActive) return false;
      if (_typeFilter != null && s.stageType?.id != _typeFilter) return false;
      if (q.isEmpty) return true;
      return s.name.toLowerCase().contains(q) ||
          (s.note ?? '').toLowerCase().contains(q) ||
          (s.stageType?.name ?? '').toLowerCase().contains(q);
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
  Future<void> _openForm([StageModel? stage]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StageFormSheet(stage: stage, api: _api),
    );
    if (saved == true) {
      _snack(stage == null ? 'Stage added' : 'Stage updated');
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
  Future<void> _delete(StageModel s) async {
    final ok = await _confirm(
      title: 'Delete stage',
      message: '"${s.displayName}" will be deleted. Continue?',
      action: 'Delete',
      actionColor: _danger,
    );
    if (!ok) return;
    try {
      await _api.delete(s.id!);
      _snack('Stage deleted');
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
          ? 'Activate ${ids.length} stage(s)?'
          : '${ids.length} stage(s) will be deactivated. You can restore them later.',
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
    final sel = _stages.where((s) => _selected.contains(s.id)).toList();
    final activeOnes = sel.where((s) => s.active).toList();
    if (activeOnes.isNotEmpty) {
      _setActive(activeOnes.map((s) => s.id!).toList(), false);
    } else {
      _setActive(sel.map((s) => s.id!).toList(), true);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final list = _filtered;
    final selecting = _selected.isNotEmpty;
    final types = _typesInData;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.background,
      appBar: AppBar(
        title: Text(
          selecting ? '${_selected.length} selected' : 'Stages',
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
                _stages.any((s) => _selected.contains(s.id) && s.active)
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
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Stage',
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
                hintText: 'Search stage, type or note',
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
          // فلتر بالـ stage type (بيظهر لو في أكتر من نوع)
          if (types.length > 1)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _chip(
                    'All types',
                    _typeFilter == null,
                    () => setState(() => _typeFilter = null),
                  ),
                  for (final t in types)
                    _chip(
                      t.name,
                      _typeFilter == t.id,
                      () => setState(() => _typeFilter = t.id),
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
    final total = _pagination?.totalItems ?? _stages.length;
    final active =
        _pagination?.totalActive ?? _stages.where((s) => s.active).length;
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

  Widget _body(List<StageModel> list, bool isDark) {
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
          'No stages found',
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
          final s = list[i];
          final id = s.id!;
          return _StageCard(
            stage: s,
            selected: _selected.contains(id),
            isDark: isDark,
            // لو في selection شغّال الضغطة بتعمل toggle، غير كده بتفتح الـ edit
            onTap: () => _selected.isNotEmpty ? _toggle(id) : _openForm(s),
            onLongPress: () => _toggle(id),
            onAction: (a) {
              switch (a) {
                case 'edit':
                  _openForm(s);
                case 'toggle':
                  _setActive([id], !s.active);
                case 'delete':
                  _delete(s);
              }
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Stage card
// ─────────────────────────────────────────────
class _StageCard extends StatelessWidget {
  final StageModel stage;
  final bool selected, isDark;
  final VoidCallback onTap, onLongPress;
  final ValueChanged<String> onAction;

  const _StageCard({
    required this.stage,
    required this.selected,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final s = stage;
    final c = s.colorValue;
    final subtitle = [
      if (s.addedByName != null) 'Added by ${s.addedByName}',
      if (s.createdAt != null) _fmtDate(s.createdAt),
    ].join('  •  ');

    return Opacity(
      opacity: s.active ? 1 : 0.6,
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
                // أيقونة بلون الـ stage، ولو selected بنعرض check
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.gold.withOpacity(0.18) : c.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    selected ? Icons.check_rounded : Icons.flag_rounded,
                    color: selected ? AppColors.gold : c,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      if (s.stageType != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          s.stageType!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.goldLight
                                : AppColors.navy,
                          ),
                        ),
                      ],
                      if (s.note != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          s.note!,
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
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _pill(
                            s.active ? 'Active' : 'Inactive',
                            (s.active ? _success : _danger).withOpacity(0.15),
                            s.active ? _success : _danger,
                          ),
                          _colorPill('Color', c),
                          _colorPill('Late', s.lateColorValue),
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
                      child: Text(s.active ? 'Deactivate' : 'Activate'),
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

  // pill فيها نقطة بلون الـ color / lateColor
  Widget _colorPill(String text, Color dot) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: dot.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white70 : AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
//  Add / Edit bottom sheet
// ─────────────────────────────────────────────
class _StageFormSheet extends StatefulWidget {
  final StageModel? stage; // null = add
  final CrudService api;
  const _StageFormSheet({this.stage, required this.api});

  @override
  State<_StageFormSheet> createState() => _StageFormSheetState();
}

class _StageFormSheetState extends State<_StageFormSheet> {
  final _key = GlobalKey<FormState>();
  bool get _isEdit => widget.stage != null;

  late final _name = TextEditingController(text: widget.stage?.name);
  late final _note = TextEditingController(text: widget.stage?.note);
  late final _color = TextEditingController(
    text: (widget.stage?.color ?? '#4C6FFF').toUpperCase(),
  );
  late final _late = TextEditingController(
    text: (widget.stage?.lateColor ?? '#F2545B').toUpperCase(),
  );

  // الـ stage types للـ dropdown (بتتحمل من الـ API)
  List<StageTypeRef> _types = [];
  String? _typeId;
  bool _typesLoading = true;
  String? _typesError;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _typeId = widget.stage?.stageType?.id;
    _loadTypes();
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _color.dispose();
    _late.dispose();
    super.dispose();
  }

  Future<void> _loadTypes() async {
    setState(() {
      _typesLoading = true;
      _typesError = null;
    });
    try {
      final body = await CrudService(Endpoints.stageTypes)
          .getAll(params: {'limit': 200});
      final res = StageTypesResponse.fromJson(body);
      // الـ active بس + النوع الحالي للـ stage (حتى لو بقى inactive) عشان الـ edit
      final list = res.data
          .where((t) => t.active || t.id == _typeId)
          .map((t) => StageTypeRef(id: t.id, name: t.displayName, active: t.active))
          .toList();
      if (mounted) setState(() => _types = list);
    } catch (e) {
      if (mounted) setState(() => _typesError = e.toString());
    }
    if (mounted) setState(() => _typesLoading = false);
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);

    final note = _note.text.trim();
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'stageType': _typeId,
      // في الـ edit بنبعتها دايمًا (عشان تتمسح لو فضّيتها)، وفي الـ add بس لو مكتوبة
      if (_isEdit || note.isNotEmpty) 'note': note,
      'color': _color.text.trim().toUpperCase(),
      'lateColor': _late.text.trim().toUpperCase(),
      if (!_isEdit) 'isActive': true, // الـ stage الجديد بيتعمل active
    };

    try {
      if (_isEdit) {
        await widget.api.update(widget.stage!.id!, body);
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

  // اختيار لون: عنوان + معاينة + hex field + swatches جاهزة
  Widget _colorPicker(String label, TextEditingController ctrl, bool isDark) {
    final current = ctrl.text.trim().toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: hexToColor(ctrl.text),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white24 : AppColors.border,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: ctrl,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                validator: (v) => _hexRe.hasMatch((v ?? '').trim())
                    ? null
                    : 'Use #RRGGBB',
                decoration: _dec('Hex', Icons.palette_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final h in _palette)
              GestureDetector(
                onTap: () => setState(() => ctrl.text = h),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: hexToColor(h),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: current == h
                          ? (isDark ? Colors.white : AppColors.navy)
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: current == h
                      ? const Icon(Icons.check_rounded,
                          size: 16, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _typeField() {
    if (_typesLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_typesError != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              _typesError!,
              style: const TextStyle(color: _danger, fontSize: 12.5),
            ),
          ),
          TextButton(onPressed: _loadTypes, child: const Text('Retry')),
        ],
      );
    }
    return DropdownButtonFormField<String>(
      value: _types.any((t) => t.id == _typeId) ? _typeId : null,
      isExpanded: true,
      decoration: _dec('Stage type', Icons.account_tree_rounded),
      validator: (v) => v == null ? 'Required' : null,
      items: _types
          .map(
            (t) => DropdownMenuItem(
              value: t.id,
              child: Text(t.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _typeId = v),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
        child: SingleChildScrollView(
          child: Form(
            key: _key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isEdit ? 'Edit Stage' : 'Add Stage',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  autofocus: !_isEdit,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                  decoration: _dec('Name (e.g. Fresh Lead)', Icons.flag_rounded),
                ),
                const SizedBox(height: 12),
                _typeField(),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _dec('Note', Icons.notes_rounded),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _colorPicker('Color', _color, isDark),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _colorPicker('Late color', _late, isDark),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_saving || _typesLoading) ? null : _submit,
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
                            _isEdit ? 'Save changes' : 'Create stage',
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