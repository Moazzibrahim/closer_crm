// communication_ways_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/features/crud/data/commway_model.dart';
import 'package:flutter_application_1/features/crud/data/stages_model.dart';
import 'package:flutter_application_1/features/crud/providers/crud_service.dart';
// ⚠️ لازم يكون عندك Endpoints.communicationWays في api_constants.dart

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

// التصنيفات الجاهزة (لو الـ API رجّع تصنيف تاني بيتضاف تلقائي في الـ dropdown)
const _categories = ['Digital', 'In-person'];

// الألوان الجاهزة
const _palette = [
  '#25D366',
  '#128C7E',
  '#4C6FFF',
  '#F2545B',
  '#E67E22',
  '#9B59B6',
  '#34495E',
  '#EC4899',
  '#F1C40F',
  '#1ABC9C',
];

// الأيقونات: الاسم اللي بيتبعت للـ API (lucide) ← أيقونة Material مقابلة
const _icons = <String, IconData>{
  'MessageCircle': Icons.chat_rounded,
  'MessageSquare': Icons.message_rounded,
  'Phone': Icons.phone_rounded,
  'PhoneCall': Icons.phone_in_talk_rounded,
  'Mail': Icons.mail_rounded,
  'Video': Icons.videocam_rounded,
  'Users': Icons.groups_rounded,
  'Globe': Icons.language_rounded,
  'Send': Icons.send_rounded,
  'Smartphone': Icons.smartphone_rounded,
  'MapPin': Icons.place_rounded,
  'Calendar': Icons.event_rounded,
};

final _hexRe = RegExp(r'^#[0-9A-Fa-f]{6}$');

// أيقونة الـ way: اسم معروف → Icon، emoji → Text، غير كده أيقونة افتراضية
Widget _wayIcon(String? icon, Color color, {double size = 24}) {
  if (icon != null && _icons.containsKey(icon)) {
    return Icon(_icons[icon], color: color, size: size);
  }
  if (icon != null &&
      icon.isNotEmpty &&
      !RegExp(r'^[A-Za-z0-9_\-]+$').hasMatch(icon)) {
    return Text(icon, style: TextStyle(fontSize: size - 2));
  }
  return Icon(Icons.forum_rounded, color: color, size: size);
}

// ─────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────
class CommunicationWaysScreen extends StatefulWidget {
  const CommunicationWaysScreen({super.key});
  @override
  State<CommunicationWaysScreen> createState() =>
      _CommunicationWaysScreenState();
}

class _CommunicationWaysScreenState extends State<CommunicationWaysScreen> {
  final _api = CrudService(Endpoints.communicationWays);

  List<CommunicationWayModel> _ways = [];
  CommunicationWaysPagination? _pagination;
  bool _loading = true;
  String? _error;

  String _query = '';
  bool? _showActive; // null = All
  String? _categoryFilter; // null = كل التصنيفات
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
      final res = CommunicationWaysResponse.fromJson(body);
      _ways = res.data;
      _pagination = res.pagination;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  List<String> get _categoriesInData =>
      _ways.map((w) => w.category).whereType<String>().toSet().toList();

  List<CommunicationWayModel> get _filtered {
    final q = _query.toLowerCase();
    return _ways.where((w) {
      if (_showActive != null && w.active != _showActive) return false;
      if (_categoryFilter != null && w.category != _categoryFilter)
        return false;
      if (q.isEmpty) return true;
      return w.name.toLowerCase().contains(q) ||
          (w.notes ?? '').toLowerCase().contains(q) ||
          (w.category ?? '').toLowerCase().contains(q);
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
  Future<void> _openForm([CommunicationWayModel? way]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WayFormSheet(way: way, api: _api),
    );
    if (saved == true) {
      _snack(
        way == null ? 'Communication way added' : 'Communication way updated',
      );
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
  Future<void> _delete(CommunicationWayModel w) async {
    final ok = await _confirm(
      title: 'Delete communication way',
      message: '"${w.displayName}" will be deleted. Continue?',
      action: 'Delete',
      actionColor: _danger,
    );
    if (!ok) return;
    try {
      await _api.delete(w.id!);
      _snack('Communication way deleted');
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
          ? 'Activate ${ids.length} communication way(s)?'
          : '${ids.length} communication way(s) will be deactivated. You can restore them later.',
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
    final sel = _ways.where((w) => _selected.contains(w.id)).toList();
    final activeOnes = sel.where((w) => w.active).toList();
    if (activeOnes.isNotEmpty) {
      _setActive(activeOnes.map((w) => w.id!).toList(), false);
    } else {
      _setActive(sel.map((w) => w.id!).toList(), true);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final list = _filtered;
    final selecting = _selected.isNotEmpty;
    final cats = _categoriesInData;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.background,
      appBar: AppBar(
        title: Text(
          selecting ? '${_selected.length} selected' : 'Communication Ways',
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
                _ways.any((w) => _selected.contains(w.id) && w.active)
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
          'Add Way',
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
                hintText: 'Search name, category or note',
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
          // فلتر بالتصنيف (بيظهر لو في أكتر من تصنيف)
          if (cats.length > 1)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _chip(
                    'All categories',
                    _categoryFilter == null,
                    () => setState(() => _categoryFilter = null),
                  ),
                  for (final c in cats)
                    _chip(
                      c,
                      _categoryFilter == c,
                      () => setState(() => _categoryFilter = c),
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
    final total = _pagination?.totalItems ?? _ways.length;
    final active =
        _pagination?.totalActive ?? _ways.where((w) => w.active).length;
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

  Widget _body(List<CommunicationWayModel> list, bool isDark) {
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
          'No communication ways found',
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
          final w = list[i];
          final id = w.id!;
          return _WayCard(
            way: w,
            selected: _selected.contains(id),
            isDark: isDark,
            // لو في selection شغّال الضغطة بتعمل toggle، غير كده بتفتح الـ edit
            onTap: () => _selected.isNotEmpty ? _toggle(id) : _openForm(w),
            onLongPress: () => _toggle(id),
            onAction: (a) {
              switch (a) {
                case 'edit':
                  _openForm(w);
                case 'toggle':
                  _setActive([id], !w.active);
                case 'delete':
                  _delete(w);
              }
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Way card
// ─────────────────────────────────────────────
class _WayCard extends StatelessWidget {
  final CommunicationWayModel way;
  final bool selected, isDark;
  final VoidCallback onTap, onLongPress;
  final ValueChanged<String> onAction;

  const _WayCard({
    required this.way,
    required this.selected,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final w = way;
    final c = hexToColor(w.color);
    final subtitle = [
      if (w.addedByName != null) 'Added by ${w.addedByName}',
      if (w.createdAt != null) _fmtDate(w.createdAt),
    ].join('  •  ');

    return Opacity(
      opacity: w.active ? 1 : 0.6,
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
                // أيقونة الـ way بلونه، ولو selected بنعرض check
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.gold.withOpacity(0.18)
                        : c.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded, color: AppColors.gold)
                      : _wayIcon(w.icon, c),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      if (w.notes != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          w.notes!,
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
                          if (w.category != null)
                            _pill(
                              w.category!,
                              AppColors.gold.withOpacity(0.2),
                              isDark ? AppColors.goldLight : AppColors.navy,
                            ),
                          _pill(
                            w.active ? 'Active' : 'Inactive',
                            (w.active ? _success : _danger).withOpacity(0.15),
                            w.active ? _success : _danger,
                          ),
                          _colorDot(c),
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
                      child: Text(w.active ? 'Deactivate' : 'Activate'),
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

  Widget _colorDot(Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: c.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          'Color',
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
class _WayFormSheet extends StatefulWidget {
  final CommunicationWayModel? way; // null = add
  final CrudService api;
  const _WayFormSheet({this.way, required this.api});

  @override
  State<_WayFormSheet> createState() => _WayFormSheetState();
}

class _WayFormSheetState extends State<_WayFormSheet> {
  final _key = GlobalKey<FormState>();
  bool get _isEdit => widget.way != null;

  late final _name = TextEditingController(text: widget.way?.name);
  late final _notes = TextEditingController(text: widget.way?.notes);
  late final _color = TextEditingController(
    text: (widget.way?.color ?? '#25D366').toUpperCase(),
  );
  // لو الأيقونة الحالية مش من القايمة (emoji مثلًا) بنحطها هنا
  late final _emoji = TextEditingController(
    text: (widget.way?.icon != null && !_icons.containsKey(widget.way!.icon))
        ? widget.way!.icon
        : '',
  );

  late String? _icon = widget.way?.icon; // اسم أيقونة أو emoji أو null
  late String? _category = widget.way?.category ?? _categories.first;
  bool _saving = false;

  List<String> get _categoryOptions =>
      {..._categories, if (_category != null) _category!}.toList();

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _color.dispose();
    _emoji.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);

    final notes = _notes.text.trim();
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      // في الـ edit بنبعتها دايمًا (عشان تتمسح لو فضّيتها)، وفي الـ add بس لو مكتوبة
      if (_isEdit || notes.isNotEmpty) 'notes': notes,
      // الأيقونة: في الـ edit بنبعتها دايمًا (null = مسح)، وفي الـ add لو مختارة
      if (_isEdit || _icon != null) 'icon': _icon,
      'color': _color.text.trim().toUpperCase(),
      'category': _category,
      if (!_isEdit) 'isActive': true, // الـ way الجديد بيتعمل active
    };

    try {
      if (_isEdit) {
        await widget.api.update(widget.way!.id!, body);
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

  Widget _label(String t) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      t,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
    ),
  );

  // شبكة الأيقونات + حقل emoji مخصص
  Widget _iconPicker(bool isDark) {
    final accent = hexToColor(_color.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Icon'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in _icons.entries)
              GestureDetector(
                onTap: () => setState(() {
                  // الضغط على نفس الأيقونة تاني بيلغي الاختيار
                  _icon = _icon == e.key ? null : e.key;
                  _emoji.clear();
                }),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _icon == e.key
                        ? accent.withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _icon == e.key
                          ? accent
                          : (isDark ? Colors.white12 : AppColors.border),
                      width: _icon == e.key ? 2 : 1,
                    ),
                  ),
                  child: Icon(
                    e.value,
                    size: 22,
                    color: _icon == e.key
                        ? accent
                        : (isDark ? Colors.white70 : AppColors.textSecondary),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _emoji,
          onChanged: (v) => setState(() {
            final t = v.trim();
            _icon = t.isEmpty ? null : t;
          }),
          decoration: _dec(
            'Or custom emoji (e.g. 📞)',
            Icons.emoji_emotions_rounded,
          ),
        ),
      ],
    );
  }

  Widget _colorPicker(bool isDark) {
    final current = _color.text.trim().toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Color'),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: hexToColor(_color.text),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white24 : AppColors.border,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _color,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                    _hexRe.hasMatch((v ?? '').trim()) ? null : 'Use #RRGGBB',
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
                onTap: () => setState(() => _color.text = h),
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
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
          ],
        ),
      ],
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
                  _isEdit ? 'Edit Communication Way' : 'Add Communication Way',
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
                  decoration: _dec('Name (e.g. WhatsApp)', Icons.forum_rounded),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _category,
                  isExpanded: true,
                  decoration: _dec('Category', Icons.category_rounded),
                  validator: (v) => v == null ? 'Required' : null,
                  items: _categoryOptions
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _dec('Notes', Icons.notes_rounded),
                ),
                const SizedBox(height: 16),
                _colorPicker(isDark),
                const SizedBox(height: 16),
                _iconPicker(isDark),
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
                            _isEdit
                                ? 'Save changes'
                                : 'Create communication way',
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
