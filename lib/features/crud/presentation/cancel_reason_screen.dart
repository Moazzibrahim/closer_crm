// cancel_reasons_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/features/crud/data/cancel_reason_model.dart';
import 'package:flutter_application_1/features/crud/providers/crud_service.dart';
// ⚠️ حط cancel_reasons_model.dart في نفس فولدر projects_model.dart (أو عدّل المسار)
// ⚠️ لازم يكون عندك Endpoints.cancelReasons في api_constants.dart

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
class CancelReasonsScreen extends StatefulWidget {
  const CancelReasonsScreen({super.key});
  @override
  State<CancelReasonsScreen> createState() => _CancelReasonsScreenState();
}

class _CancelReasonsScreenState extends State<CancelReasonsScreen> {
  final _api = CrudService(Endpoints.cancelReasons);

  List<CancelReasonModel> _reasons = [];
  CancelReasonsPagination? _pagination;
  bool _loading = true;
  String? _error;

  String _query = '';
  bool? _showActive; // null = All
  String? _category; // null = كل الـ categories
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
      final res = CancelReasonsResponse.fromJson(body);
      _reasons = res.data;
      _pagination = res.pagination;
      // لو الـ category المختار اتمسح من الداتا، نرجع لـ All
      if (_category != null && !_categories.contains(_category)) {
        _category = null;
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  // الـ categories الموجودة فعلًا (من غير تكرار، مرتبة)
  List<String> get _categories {
    final set = <String>{
      for (final r in _reasons)
        if (r.category != null) r.category!,
    };
    return set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  // البحث بالاسم أو الـ category
  List<CancelReasonModel> get _filtered {
    final q = _query.toLowerCase();
    return _reasons.where((r) {
      if (_showActive != null && r.active != _showActive) return false;
      if (_category != null && r.category != _category) return false;
      if (q.isEmpty) return true;
      return r.name.toLowerCase().contains(q) ||
          (r.category ?? '').toLowerCase().contains(q);
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
  Future<void> _openForm([CancelReasonModel? reason]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CancelReasonFormSheet(
        reason: reason,
        api: _api,
        categories: _categories, // اقتراحات للـ category
      ),
    );
    if (saved == true) {
      _snack(reason == null ? 'Cancel reason added' : 'Cancel reason updated');
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
  Future<void> _delete(CancelReasonModel r) async {
    final ok = await _confirm(
      title: 'Delete cancel reason',
      message: '"${r.displayName}" will be deleted. Continue?',
      action: 'Delete',
      actionColor: _danger,
    );
    if (!ok) return;
    try {
      await _api.delete(r.id!);
      _snack('Cancel reason deleted');
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
          ? 'Activate ${ids.length} cancel reason(s)?'
          : '${ids.length} cancel reason(s) will be deactivated. You can restore them later.',
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
    final sel = _reasons.where((r) => _selected.contains(r.id)).toList();
    final activeOnes = sel.where((r) => r.active).toList();
    if (activeOnes.isNotEmpty) {
      _setActive(activeOnes.map((r) => r.id!).toList(), false);
    } else {
      _setActive(sel.map((r) => r.id!).toList(), true);
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
          selecting ? '${_selected.length} selected' : 'Cancel Reasons',
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
                _reasons.any((r) => _selected.contains(r.id) && r.active)
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
          'Add Reason',
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
                hintText: 'Search reason or category',
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
          // Status chips + Category chips (دهبي)
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
                if (_categories.isNotEmpty) const SizedBox(width: 8),
                for (final c in _categories)
                  _chip(
                    c,
                    _category == c,
                    // الضغط مرتين على نفس الـ category بيلغي الفلتر
                    () => setState(() {
                      _category = _category == c ? null : c;
                      _selected.clear();
                    }),
                    gold: true,
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
    final total = _pagination?.totalItems ?? _reasons.length;
    final active =
        _pagination?.totalActive ?? _reasons.where((r) => r.active).length;
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

  Widget _chip(String label, bool on, VoidCallback tap, {bool gold = false}) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: on
                  ? (gold ? AppColors.navy : Colors.white)
                  : AppColors.textSecondary,
            ),
          ),
          selected: on,
          showCheckmark: false,
          selectedColor: gold ? AppColors.gold : AppColors.navy,
          onSelected: (_) => tap(),
        ),
      );

  Widget _body(List<CancelReasonModel> list, bool isDark) {
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
          'No cancel reasons found',
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
          final r = list[i];
          final id = r.id!;
          return _CancelReasonCard(
            reason: r,
            selected: _selected.contains(id),
            isDark: isDark,
            // لو في selection شغّال الضغطة بتعمل toggle، غير كده بتفتح الـ edit
            onTap: () => _selected.isNotEmpty ? _toggle(id) : _openForm(r),
            onLongPress: () => _toggle(id),
            onAction: (a) {
              switch (a) {
                case 'edit':
                  _openForm(r);
                case 'toggle':
                  _setActive([id], !r.active);
                case 'delete':
                  _delete(r);
              }
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Cancel reason card
// ─────────────────────────────────────────────
class _CancelReasonCard extends StatelessWidget {
  final CancelReasonModel reason;
  final bool selected, isDark;
  final VoidCallback onTap, onLongPress;
  final ValueChanged<String> onAction;

  const _CancelReasonCard({
    required this.reason,
    required this.selected,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final r = reason;
    final subtitle = [
      if (r.addedByName != null) 'Added by ${r.addedByName}',
      if (r.createdAt != null) _fmtDate(r.createdAt),
    ].join('  •  ');

    return Opacity(
      opacity: r.active ? 1 : 0.6,
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
                // أيقونة السبب، ولو selected بنعرض check
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    selected ? Icons.check_rounded : Icons.cancel_rounded,
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
                        r.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (r.category != null)
                            _pill(
                              r.category!,
                              AppColors.gold.withOpacity(0.2),
                              isDark ? AppColors.goldLight : AppColors.navy,
                            ),
                          _pill(
                            r.active ? 'Active' : 'Inactive',
                            (r.active ? _success : _danger).withOpacity(0.15),
                            r.active ? _success : _danger,
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
                      child: Text(r.active ? 'Deactivate' : 'Activate'),
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
class _CancelReasonFormSheet extends StatefulWidget {
  final CancelReasonModel? reason; // null = add
  final CrudService api;
  final List<String> categories; // الـ categories الموجودة (اقتراحات)
  const _CancelReasonFormSheet({
    this.reason,
    required this.api,
    this.categories = const [],
  });

  @override
  State<_CancelReasonFormSheet> createState() => _CancelReasonFormSheetState();
}

class _CancelReasonFormSheetState extends State<_CancelReasonFormSheet> {
  final _key = GlobalKey<FormState>();
  bool get _isEdit => widget.reason != null;

  late final _name = TextEditingController(text: widget.reason?.name);
  late final _category = TextEditingController(text: widget.reason?.category);

  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);

    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'category': _category.text.trim(),
      if (!_isEdit) 'isActive': true, // السبب الجديد بيتعمل active
    };

    try {
      if (_isEdit) {
        await widget.api.update(widget.reason!.id!, body);
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
                  _isEdit ? 'Edit Cancel Reason' : 'Add Cancel Reason',
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
                  textCapitalization: TextCapitalization.sentences,
                  validator: _req,
                  decoration: _dec(
                    'Reason (e.g. Price too high)',
                    Icons.cancel_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _category,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.words,
                  onFieldSubmitted: (_) => _saving ? null : _submit(),
                  validator: _req,
                  decoration: _dec(
                    'Category (e.g. Price)',
                    Icons.category_rounded,
                  ),
                ),
                // اقتراحات: الـ categories الموجودة، الضغط عليها بيملا الحقل
                if (widget.categories.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final c in widget.categories)
                          ActionChip(
                            label: Text(
                              c,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () => setState(() => _category.text = c),
                          ),
                      ],
                    ),
                  ),
                ],
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
                            _isEdit ? 'Save changes' : 'Create reason',
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
