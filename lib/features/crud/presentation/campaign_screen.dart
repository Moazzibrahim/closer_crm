// campaigns_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/features/crud/data/campaigns_model.dart';
import 'package:flutter_application_1/features/crud/providers/crud_service.dart';
// ⚠️ حط campaigns_model.dart في نفس فولدر projects_model.dart (أو عدّل المسار)
// ⚠️ لازم يكون عندك Endpoints.campaigns في api_constants.dart

const _danger = Color(0xFFE5484D);
const _success = Color(0xFF2E9E6B);

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtDate(DateTime? d) =>
    d == null ? '' : '${d.day} ${_months[d.month - 1]} ${d.year}';

// yyyy-MM-dd زي ما الباك إند مستني
String _dateOnly(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// 12000 → "12,000"
String _money(double? v) {
  if (v == null) return '—';
  final s = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
  final parts = s.split('.');
  final int = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return parts.length > 1 ? '$int.${parts[1]}' : int;
}

// ─────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────
class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});
  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  final _api = CrudService(Endpoints.campaigns);

  List<CampaignModel> _campaigns = [];
  CampaignsPagination? _pagination;
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
      final res = CampaignsResponse.fromJson(body);
      _campaigns = res.data;
      _pagination = res.pagination;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  // البحث بالاسم أو الملاحظات أو أسماء المشاريع
  List<CampaignModel> get _filtered {
    final q = _query.toLowerCase();
    return _campaigns.where((c) {
      if (_showActive != null && c.active != _showActive) return false;
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          (c.notes ?? '').toLowerCase().contains(q) ||
          c.projectNames.any((n) => n.toLowerCase().contains(q));
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
  Future<void> _openForm([CampaignModel? campaign]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CampaignFormSheet(campaign: campaign, api: _api),
    );
    if (saved == true) {
      _snack(campaign == null ? 'Campaign added' : 'Campaign updated');
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
  Future<void> _delete(CampaignModel c) async {
    final ok = await _confirm(
      title: 'Delete campaign',
      message: '"${c.displayName}" will be deleted. Continue?',
      action: 'Delete',
      actionColor: _danger,
    );
    if (!ok) return;
    try {
      await _api.delete(c.id!);
      _snack('Campaign deleted');
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
          ? 'Activate ${ids.length} campaign(s)?'
          : '${ids.length} campaign(s) will be deactivated. You can restore them later.',
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
    final sel = _campaigns.where((c) => _selected.contains(c.id)).toList();
    final activeOnes = sel.where((c) => c.active).toList();
    if (activeOnes.isNotEmpty) {
      _setActive(activeOnes.map((c) => c.id!).toList(), false);
    } else {
      _setActive(sel.map((c) => c.id!).toList(), true);
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
          selecting ? '${_selected.length} selected' : 'Campaigns',
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
                _campaigns.any((c) => _selected.contains(c.id) && c.active)
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
        icon: const Icon(Icons.campaign_rounded),
        label: const Text(
          'Add Campaign',
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
                hintText: 'Search campaign, notes or project',
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
    final total = _pagination?.totalItems ?? _campaigns.length;
    final active =
        _pagination?.totalActive ?? _campaigns.where((c) => c.active).length;
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

  Widget _body(List<CampaignModel> list, bool isDark) {
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
          'No campaigns found',
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
          final c = list[i];
          final id = c.id!;
          return _CampaignCard(
            campaign: c,
            selected: _selected.contains(id),
            isDark: isDark,
            // لو في selection شغّال الضغطة بتعمل toggle، غير كده بتفتح الـ edit
            onTap: () => _selected.isNotEmpty ? _toggle(id) : _openForm(c),
            onLongPress: () => _toggle(id),
            onAction: (a) {
              switch (a) {
                case 'edit':
                  _openForm(c);
                case 'toggle':
                  _setActive([id], !c.active);
                case 'delete':
                  _delete(c);
              }
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Campaign card
// ─────────────────────────────────────────────
class _CampaignCard extends StatelessWidget {
  final CampaignModel campaign;
  final bool selected, isDark;
  final VoidCallback onTap, onLongPress;
  final ValueChanged<String> onAction;

  const _CampaignCard({
    required this.campaign,
    required this.selected,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    // "Starts 25 Sep 2026  •  Cost 8,000"
    final info = [
      if (c.startDate != null) 'Starts ${_fmtDate(c.startDate)}',
      if (c.cost != null) 'Cost ${_money(c.cost)}',
    ].join('  •  ');
    final projectsText = c.projectNames.join(', ');

    return Opacity(
      opacity: c.active ? 1 : 0.6,
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
                // أيقونة الحملة، ولو selected بنعرض check
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    selected ? Icons.check_rounded : Icons.campaign_rounded,
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
                        c.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      if (info.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          info,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.goldLight
                                : AppColors.navy,
                          ),
                        ),
                      ],
                      if (projectsText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          projectsText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (c.notes != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          c.notes!,
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
                          if (c.projects.isNotEmpty)
                            _pill(
                              '${c.projects.length} project${c.projects.length == 1 ? '' : 's'}',
                              AppColors.gold.withOpacity(0.2),
                              isDark ? AppColors.goldLight : AppColors.navy,
                            ),
                          _pill(
                            c.active ? 'Active' : 'Inactive',
                            (c.active ? _success : _danger).withOpacity(0.15),
                            c.active ? _success : _danger,
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
                      child: Text(c.active ? 'Deactivate' : 'Activate'),
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
class _CampaignFormSheet extends StatefulWidget {
  final CampaignModel? campaign; // null = add
  final CrudService api;
  const _CampaignFormSheet({this.campaign, required this.api});

  @override
  State<_CampaignFormSheet> createState() => _CampaignFormSheetState();
}

class _CampaignFormSheetState extends State<_CampaignFormSheet> {
  final _key = GlobalKey<FormState>();
  bool get _isEdit => widget.campaign != null;

  late final _name = TextEditingController(text: widget.campaign?.name);
  late final _cost = TextEditingController(
    text: widget.campaign?.cost == null
        ? ''
        : (widget.campaign!.cost! == widget.campaign!.cost!.roundToDouble()
              ? widget.campaign!.cost!.toInt().toString()
              : widget.campaign!.cost!.toString()),
  );
  late final _notes = TextEditingController(text: widget.campaign?.notes);
  late DateTime? _start = widget.campaign?.startDate;

  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _start ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (d != null) setState(() => _start = d);
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);

    final notes = _notes.text.trim();
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'startDate': _dateOnly(_start!),
      'cost': num.parse(_cost.text.trim()),
      // في الـ edit بنبعتها دايمًا (عشان تتمسح لو فضّيتها)، وفي الـ add بس لو مكتوبة
      if (_isEdit || notes.isNotEmpty) 'notes': notes,
      if (!_isEdit) 'isActive': true, // الحملة الجديدة بتتعمل active
    };

    try {
      if (_isEdit) {
        await widget.api.update(widget.campaign!.id!, body);
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
                  _isEdit ? 'Edit Campaign' : 'Add Campaign',
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
                  decoration: _dec('Campaign name', Icons.campaign_rounded),
                ),
                const SizedBox(height: 12),
                // Start date (إجباري)
                FormField<DateTime>(
                  validator: (_) => _start == null ? 'Required' : null,
                  builder: (state) => InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      await _pickDate();
                      state.didChange(_start);
                    },
                    child: InputDecorator(
                      decoration: _dec('Start date', Icons.event_rounded)
                          .copyWith(errorText: state.errorText),
                      child: Text(
                        _start == null ? 'Pick a date' : _dateOnly(_start!),
                        style: TextStyle(
                          color: _start == null
                              ? AppColors.textSecondary
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cost,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || num.tryParse(v.trim()) == null)
                      ? 'Required'
                      : null,
                  decoration: _dec('Cost', Icons.payments_rounded),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _dec('Notes', Icons.notes_rounded),
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
                            _isEdit ? 'Save changes' : 'Create campaign',
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