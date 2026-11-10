// stage_types_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/utils/dio_client.dart';
import 'package:flutter_application_1/features/crud/data/stage_type_model.dart';
import 'package:flutter_application_1/features/crud/providers/crud_service.dart';
// ⚠️ حط stage_types_model.dart في نفس فولدر projects_model.dart (أو عدّل المسار)
// ⚠️ لازم يكون عندك Endpoints.stageTypes في api_constants.dart

const _danger = Color(0xFFE5484D);
const _success = Color(0xFF2E9E6B);

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtDate(DateTime? d) =>
    d == null ? '' : '${d.day} ${_months[d.month - 1]} ${d.year}';

// الـ options الجاهزة اللي بتظهر في الـ dropdown وقت الإضافة — عدّل القايمة براحتك
const _presetOptions = [
  'Low Budget',
  'Broker',
  'Not Interested',
  'Wrong Number',
  'Duplicate Lead',
  'Already Purchased Elsewhere',
  'Timing Not Right',
  'Competitor Offer',
  'Unresponsive / No Answer',
  'Changed Mind',
  'Financial Issues',
  'Location Mismatch',
  'Unqualified Lead',
  'Language Barrier',
];

// ═════════════════════════════════════════════
//  Options API  (إضافة / تعديل / تفعيل / إيقاف / حذف option)
// ═════════════════════════════════════════════
// ⚠️ الـ paths والـ verbs هنا افتراض مبني على '/stagetype/{id}/options/{optionId}'
// لو في حاجة مختلفة في الـ Postman عدّلها هنا بس — مكان واحد.
class _OptionsApi {
  final String base; // Endpoints.stageTypes
  _OptionsApi(this.base);
  final Dio _dio = DioClient.instance.dio;

  Future<void> _run(Future<dynamic> Function() call) async {
    try {
      await call();
    } catch (e) {
      throw DioClient.parse(e);
    }
  }

  // POST   {base}/{id}/options                      body: {label}
  Future<void> add(String id, String label) =>
      _run(() => _dio.post('$base/$id/options', data: {'label': label}));

  // PUT    {base}/{id}/options/{optionId}           body: {label}
  Future<void> rename(String id, String optId, String label) => _run(
    () => _dio.put('$base/$id/options/$optId', data: {'label': label}),
  );

  // PUT    {base}/{id}/options/{optionId}/activate | deactivate
  Future<void> setActive(String id, String optId, bool active) => _run(
    () => _dio.put(
      '$base/$id/options/$optId/${active ? 'activate' : 'deactivate'}',
    ),
  );

  // DELETE {base}/{id}/options/{optionId}
  Future<void> delete(String id, String optId) =>
      _run(() => _dio.delete('$base/$id/options/$optId'));
}

// ─────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────
class StageTypesScreen extends StatefulWidget {
  const StageTypesScreen({super.key});
  @override
  State<StageTypesScreen> createState() => _StageTypesScreenState();
}

class _StageTypesScreenState extends State<StageTypesScreen> {
  final _api = CrudService(Endpoints.stageTypes);

  List<StageTypeModel> _types = [];
  StageTypesPagination? _pagination;
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

  // silent = تحديث في الخلفية (من غير spinner) بعد تعديل الـ options
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final body = await _api.getAll(params: {'limit': 200});
      final res = StageTypesResponse.fromJson(body);
      _types = res.data;
      _pagination = res.pagination;
    } catch (e) {
      if (!silent) _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  // البحث بالاسم أو الملاحظة أو أي option
  List<StageTypeModel> get _filtered {
    final q = _query.toLowerCase();
    return _types.where((t) {
      if (_showActive != null && t.active != _showActive) return false;
      if (q.isEmpty) return true;
      return t.name.toLowerCase().contains(q) ||
          (t.note ?? '').toLowerCase().contains(q) ||
          t.options.any((o) => o.label.toLowerCase().contains(q));
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
  Future<void> _openForm([StageTypeModel? type]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StageTypeFormSheet(type: type, api: _api),
    );
    if (saved == true) {
      _snack(type == null ? 'Stage type added' : 'Stage type updated');
      _load();
    }
  }

  Future<void> _openOptions(StageTypeModel type) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionsSheet(
        type: type,
        api: _api,
        onChanged: () => _load(silent: true),
      ),
    );
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
  Future<void> _delete(StageTypeModel t) async {
    final ok = await _confirm(
      title: 'Delete stage type',
      message: '"${t.displayName}" will be deleted. Continue?',
      action: 'Delete',
      actionColor: _danger,
    );
    if (!ok) return;
    try {
      await _api.delete(t.id!);
      _snack('Stage type deleted');
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
          ? 'Activate ${ids.length} stage type(s)?'
          : '${ids.length} stage type(s) will be deactivated. You can restore them later.',
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
    final sel = _types.where((t) => _selected.contains(t.id)).toList();
    final activeOnes = sel.where((t) => t.active).toList();
    if (activeOnes.isNotEmpty) {
      _setActive(activeOnes.map((t) => t.id!).toList(), false);
    } else {
      _setActive(sel.map((t) => t.id!).toList(), true);
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
          selecting ? '${_selected.length} selected' : 'Stage Types',
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
                _types.any((t) => _selected.contains(t.id) && t.active)
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
          'Add Stage Type',
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
                hintText: 'Search stage type, note or option',
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
    final total = _pagination?.totalItems ?? _types.length;
    final active =
        _pagination?.totalActive ?? _types.where((t) => t.active).length;
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

  Widget _body(List<StageTypeModel> list, bool isDark) {
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
          'No stage types found',
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
          final t = list[i];
          final id = t.id!;
          return _StageTypeCard(
            type: t,
            selected: _selected.contains(id),
            isDark: isDark,
            // لو في selection شغّال الضغطة بتعمل toggle، غير كده بتفتح الـ edit
            onTap: () => _selected.isNotEmpty ? _toggle(id) : _openForm(t),
            onLongPress: () => _toggle(id),
            onAction: (a) {
              switch (a) {
                case 'edit':
                  _openForm(t);
                case 'options':
                  _openOptions(t);
                case 'toggle':
                  _setActive([id], !t.active);
                case 'delete':
                  _delete(t);
              }
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Stage type card
// ─────────────────────────────────────────────
class _StageTypeCard extends StatelessWidget {
  final StageTypeModel type;
  final bool selected, isDark;
  final VoidCallback onTap, onLongPress;
  final ValueChanged<String> onAction;

  const _StageTypeCard({
    required this.type,
    required this.selected,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final t = type;
    final subtitle = [
      if (t.addedByName != null) 'Added by ${t.addedByName}',
      if (t.createdAt != null) _fmtDate(t.createdAt),
    ].join('  •  ');

    // أول 3 options active: "Broker, Not Interested, Wrong Number +11"
    final act = t.activeOptions;
    final preview = act.isEmpty
        ? ''
        : act.take(3).map((o) => o.label).join(', ') +
              (act.length > 3 ? '  +${act.length - 3}' : '');

    return Opacity(
      opacity: t.active ? 1 : 0.6,
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
                // أيقونة الـ stage type، ولو selected بنعرض check
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    selected ? Icons.check_rounded : Icons.account_tree_rounded,
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
                        t.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      if (t.note != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          t.note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          preview,
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
                          _pill(
                            '${t.options.length} option${t.options.length == 1 ? '' : 's'}',
                            AppColors.gold.withOpacity(0.2),
                            isDark ? AppColors.goldLight : AppColors.navy,
                          ),
                          _pill(
                            t.active ? 'Active' : 'Inactive',
                            (t.active ? _success : _danger).withOpacity(0.15),
                            t.active ? _success : _danger,
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
                    const PopupMenuItem(
                      value: 'options',
                      child: Text('Manage options'),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(t.active ? 'Deactivate' : 'Activate'),
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
class _StageTypeFormSheet extends StatefulWidget {
  final StageTypeModel? type; // null = add
  final CrudService api;
  const _StageTypeFormSheet({this.type, required this.api});

  @override
  State<_StageTypeFormSheet> createState() => _StageTypeFormSheetState();
}

class _StageTypeFormSheetState extends State<_StageTypeFormSheet> {
  final _key = GlobalKey<FormState>();
  bool get _isEdit => widget.type != null;

  late final _name = TextEditingController(text: widget.type?.name);
  late final _note = TextEditingController(text: widget.type?.note);

  // الـ options المختارة من الـ dropdown:
  // add → بتتبعت مع الـ create، edit → بتتضاف واحدة واحدة بعد الحفظ
  final List<String> _options = [];

  // labels الموجودة فعلًا في الـ stage type (في الـ edit) — مش هتظهر في الـ dropdown
  Set<String> get _existing => (widget.type?.options ?? const <StageOption>[])
      .map((o) => o.label.trim().toLowerCase())
      .toSet();

  // الـ options الجاهزة اللي لسه ما اتختارتش ومش موجودة أصلًا
  List<String> get _remaining => _presetOptions
      .where((o) => !_options.contains(o) && !_existing.contains(o.toLowerCase()))
      .toList();

  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);

    final note = _note.text.trim();
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      // في الـ edit بنبعتها دايمًا (عشان تتمسح لو فضّيتها)، وفي الـ add بس لو مكتوبة
      if (_isEdit || note.isNotEmpty) 'note': note,
      if (!_isEdit) 'isActive': true, // الـ stage type الجديد بيتعمل active
      if (!_isEdit && _options.isNotEmpty) 'options': _options,
    };

    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_isEdit) {
        final id = widget.type!.id!;
        await widget.api.update(id, body);
        // الـ options الجديدة بتتضاف واحدة واحدة (نفس endpoint الـ Manage options)
        final optApi = _OptionsApi(Endpoints.stageTypes);
        final failed = <String>[];
        for (final o in _options) {
          try {
            await optApi.add(id, o);
          } catch (_) {
            failed.add(o);
          }
        }
        if (failed.isNotEmpty) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Saved, but failed to add: ${failed.join(', ')}'),
              backgroundColor: _danger,
            ),
          );
        }
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
                  _isEdit ? 'Edit Stage Type' : 'Add Stage Type',
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
                  decoration: _dec('Name (e.g. Reason)', Icons.label_rounded),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _dec('Note', Icons.notes_rounded),
                ),

                // ===== Options (add + edit) =====
                ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isEdit
                          ? 'Add options (${_options.length})'
                          : 'Options (${_options.length})',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // dropdown بالـ options الجاهزة: اختيار واحدة بيضيفها كـ chip تحت
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          // الـ key بيرجّع الـ dropdown فاضي بعد كل اختيار
                          key: ValueKey(_options.length),
                          value: null,
                          isExpanded: true,
                          decoration: _dec(
                            _remaining.isEmpty
                                ? 'All options added'
                                : 'Select option',
                            Icons.list_alt_rounded,
                          ),
                          items: _remaining
                              .map(
                                (o) => DropdownMenuItem(
                                  value: o,
                                  child: Text(
                                    o,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _remaining.isEmpty
                              ? null
                              : (v) {
                                  if (v != null) {
                                    setState(() => _options.add(v));
                                  }
                                },
                        ),
                      ),
                      if (_remaining.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () =>
                              setState(() => _options.addAll(_remaining)),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.navy,
                          ),
                          child: const Text('Add all'),
                        ),
                      ],
                    ],
                  ),
                  if (_options.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final o in _options)
                            InputChip(
                              label: Text(
                                o,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onDeleted: () =>
                                  setState(() => _options.remove(o)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
                if (_isEdit)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Selected options are added when you save. To rename, deactivate or delete existing ones use Manage options.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white54
                              : AppColors.textSecondary,
                        ),
                      ),
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
                            _isEdit ? 'Save changes' : 'Create stage type',
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

// ─────────────────────────────────────────────
//  Manage options bottom sheet
// ─────────────────────────────────────────────
class _OptionsSheet extends StatefulWidget {
  final StageTypeModel type;
  final CrudService api; // للـ getOne (إعادة تحميل الـ options بعد أي تعديل)
  final VoidCallback onChanged; // بيحدّث الليست اللي ورا
  const _OptionsSheet({
    required this.type,
    required this.api,
    required this.onChanged,
  });

  @override
  State<_OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends State<_OptionsSheet> {
  final _optApi = _OptionsApi(Endpoints.stageTypes);
  final _input = TextEditingController();
  late List<StageOption> _options = [...widget.type.options];
  bool _busy = false;

  String get _id => widget.type.id!;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: error ? _danger : AppColors.navy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // بيعيد تحميل الـ options من الـ API (الـ response ممكن يكون {data: {...}} أو الـ object نفسه)
  Future<void> _reload() async {
    try {
      final body = await widget.api.getOne(_id);
      final raw = body['data'] is Map ? body['data'] : body;
      final t = StageTypeModel.fromJson(Map<String, dynamic>.from(raw as Map));
      if (mounted) setState(() => _options = t.options);
    } catch (_) {
      // لو فشل التحديث، الأكشن نفسه نجح — الليست هتتحدث لما تفتح تاني
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _reload();
      widget.onChanged();
    } catch (e) {
      _snack(e.toString(), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _add() async {
    final v = _input.text.trim();
    if (v.isEmpty || _busy) return;
    _input.clear();
    await _run(() => _optApi.add(_id, v));
  }

  Future<String?> _prompt(String title, String initial) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(StageOption o) async {
    final v = await _prompt('Edit option', o.label);
    if (v == null || v.isEmpty || v == o.label) return;
    await _run(() => _optApi.rename(_id, o.id!, v));
  }

  Future<void> _delete(StageOption o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete option',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text('"${o.label}" will be deleted. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: _danger, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => _optApi.delete(_id, o.id!));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
              'Options — ${widget.type.displayName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            // إضافة option جديدة
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                    decoration: InputDecoration(
                      labelText: 'New option',
                      prefixIcon: const Icon(Icons.list_alt_rounded, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _busy ? null : _add,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.navy,
                  ),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 10),
            Flexible(
              child: _options.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No options yet',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _options.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final o = _options[i];
                        return Opacity(
                          opacity: o.active ? 1 : 0.55,
                          child: Container(
                            padding: const EdgeInsets.only(left: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    o.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (!o.active)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _danger.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Inactive',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: _danger,
                                      ),
                                    ),
                                  ),
                                PopupMenuButton<String>(
                                  enabled: !_busy,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  onSelected: (a) {
                                    switch (a) {
                                      case 'edit':
                                        _rename(o);
                                      case 'toggle':
                                        _run(
                                          () => _optApi.setActive(
                                            _id,
                                            o.id!,
                                            !o.active,
                                          ),
                                        );
                                      case 'delete':
                                        _delete(o);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text(
                                        o.active ? 'Deactivate' : 'Activate',
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        'Delete',
                                        style: TextStyle(color: _danger),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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