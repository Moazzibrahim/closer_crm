// lib/features/trash/presentation/trash_screen.dart
// صفحة Trash موحدة (للأدمن بس): بتعرض العناصر الـ isActive=false لكل resource
// وبترجّعها بـ PUT {path}/bulk/activate  { ids: [...] }
// ignore_for_file: deprecated_member_use, unnecessary_underscores

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/core/utils/dio_client.dart';

String _s(dynamic v) => v == null ? '' : '$v';

/// بيجيب اسم من object متداخل (populate) أو ''.
String _nested(dynamic v) => v is Map ? _s(v['name']) : '';

String _join(List<String> parts, [String sep = ' · ']) =>
    parts.where((e) => e.trim().isNotEmpty).join(sep);

// ─────────────────────────────────────────────
//  تعريف كل نوع في الـ Trash
//  لو عايز تضيف resource جديد: ضيف سطر هنا بس.
// ─────────────────────────────────────────────
class _TrashType {
  final String label;
  final IconData icon;
  final String listPath; // GET (isActive=false)
  final String restorePath; // PUT bulk/activate
  final String Function(Map m) title;
  final String Function(Map m) subtitle;

  const _TrashType({
    required this.label,
    required this.icon,
    required this.listPath,
    required this.restorePath,
    required this.title,
    required this.subtitle,
  });
}

String _byName(Map m) => _s(m['name']);

final List<_TrashType> _types = [
  _TrashType(
    label: 'Leads',
    icon: Icons.groups_rounded,
    listPath: Endpoints.leads,
    restorePath: Endpoints.leadsBulkActivate,
    title: _byName,
    subtitle: (m) => _join(['${_s(m['phoneCountryCode'])} ${_s(m['phone'])}']),
  ),
  _TrashType(
    label: 'Users',
    icon: Icons.manage_accounts_rounded,
    listPath: Endpoints.allUsers,
    restorePath: Endpoints.bulkActivateUsers,
    title: (m) => _join([_s(m['firstName']), _s(m['lastName'])], ' '),
    subtitle: (m) => _join([_s(m['email']), _s(m['role'])]),
  ),
  _TrashType(
    label: 'Stages',
    icon: Icons.stacked_line_chart_rounded,
    listPath: Endpoints.stages,
    restorePath: '${Endpoints.stages}/bulk/activate',
    title: _byName,
    subtitle: (m) => _nested(m['stageType']),
  ),
  _TrashType(
    label: 'Stage Types',
    icon: Icons.type_specimen,
    listPath: Endpoints.stageTypes,
    restorePath: '${Endpoints.stageTypes}/bulk/activate',
    title: _byName,
    subtitle: (m) => _s(m['note']),
  ),
  _TrashType(
    label: 'Projects',
    icon: Icons.domain_rounded,
    listPath: Endpoints.projects,
    restorePath: '${Endpoints.projects}/bulk/activate',
    title: _byName,
    subtitle: (m) => _nested(m['developer']),
  ),
  _TrashType(
    label: 'Developers',
    icon: Icons.apartment_rounded,
    listPath: Endpoints.developers,
    restorePath: '${Endpoints.developers}/bulk/activate',
    title: _byName,
    subtitle: (_) => '',
  ),
  _TrashType(
    label: 'Property Types',
    icon: Icons.apartment,
    listPath: Endpoints.propertyTypes,
    restorePath: '${Endpoints.propertyTypes}/bulk/activate',
    title: _byName,
    subtitle: (_) => '',
  ),
  _TrashType(
    label: 'Channels',
    icon: Icons.hub_rounded,
    listPath: Endpoints.channels,
    restorePath: '${Endpoints.channels}/bulk/activate',
    title: _byName,
    subtitle: (m) => _s(m['code']),
  ),
  _TrashType(
    label: 'Campaigns',
    icon: Icons.campaign_rounded,
    listPath: Endpoints.campaigns,
    restorePath: '${Endpoints.campaigns}/bulk/activate',
    title: _byName,
    subtitle: (m) => _s(m['notes']),
  ),
  _TrashType(
    label: 'Communication Ways',
    icon: Icons.forum_rounded,
    listPath: Endpoints.communicationWays,
    restorePath: '${Endpoints.communicationWays}/bulk/activate',
    title: _byName,
    subtitle: (m) => _s(m['category']),
  ),
  _TrashType(
    label: 'Cancel Reasons',
    icon: Icons.event_busy_rounded,
    listPath: Endpoints.cancelReasons,
    restorePath: '${Endpoints.cancelReasons}/bulk/activate',
    title: _byName,
    subtitle: (m) => _s(m['category']),
  ),
  _TrashType(
    label: 'Cities',
    icon: Icons.location_city_rounded,
    listPath: Endpoints.cities,
    restorePath: '${Endpoints.cities}/bulk/activate',
    title: _byName,
    subtitle: (_) => '',
  ),
  _TrashType(
    label: 'Regions',
    icon: Icons.map_rounded,
    listPath: Endpoints.regions,
    restorePath: '${Endpoints.regions}/bulk/activate',
    title: _byName,
    subtitle: (_) => '',
  ),
  _TrashType(
    label: 'Areas',
    icon: Icons.place_rounded,
    listPath: Endpoints.areas,
    restorePath: '${Endpoints.areas}/bulk/activate',
    title: _byName,
    subtitle: (m) => _nested(m['region']),
  ),
];

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _date(dynamic iso) {
  final d = DateTime.tryParse(_s(iso))?.toLocal();
  if (d == null) return '';
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

// ─────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});
  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  static const _pageSize = 20;

  final _scroll = ScrollController();
  final _search = TextEditingController();
  Timer? _debounce;

  int _typeIdx = 0;
  final List<Map> _items = [];
  final Set<String> _selected = {};
  int _page = 1;
  int _total = 0;
  int _req = 0; // لتجاهل الردود القديمة
  bool _hasMore = true, _loading = false, _loadingMore = false, _restoring = false;
  String? _error;
  String _keyword = '';

  _TrashType get _type => _types[_typeIdx];
  String _idOf(Map m) => _s(m['_id'] ?? m['id']);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.maxScrollExtent - _scroll.position.pixels < 300) {
        _fetch(reset: false);
      }
    });
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _fetch({required bool reset}) async {
    if (!reset && (_loading || _loadingMore || !_hasMore)) return;
    final id = ++_req;
    final page = reset ? 1 : _page + 1;

    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final r = await DioClient.instance.dio.get(
        _type.listPath,
        queryParameters: {
          'isActive': false, // 👈 اللي في الترآش بس
          'page': page,
          'limit': _pageSize,
          'sort': '-updatedAt',
          if (_keyword.isNotEmpty) 'keyword': _keyword,
        },
      );
      if (id != _req || !mounted) return;

      final res = Map<String, dynamic>.from(r.data as Map);
      final list = (res['data'] as List? ?? []).whereType<Map>().toList();
      // الليدز بترجّع pagination، والباقي paginationResult
      final p = (res['paginationResult'] ?? res['pagination'] ?? {}) as Map;

      setState(() {
        if (reset) {
          _items.clear();
          _selected.clear();
        }
        _items.addAll(list);
        _page = page;
        _hasMore = p['next'] != null;
        _total = (p['totalItems'] is num) ? (p['totalItems'] as num).toInt() : _items.length;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (id != _req || !mounted) return;
      setState(() {
        _error = DioClient.parse(e).toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _setType(int i) {
    if (i == _typeIdx) return;
    _search.clear();
    _keyword = '';
    setState(() => _typeIdx = i);
    _fetch(reset: true);
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _keyword = v.trim();
      _fetch(reset: true);
    });
  }

  void _toggle(String id) => setState(() {
    if (!_selected.add(id)) _selected.remove(id);
  });

  void _selectAll() => setState(() {
    if (_selected.length == _items.length) {
      _selected.clear();
    } else {
      _selected.addAll(_items.map(_idOf));
    }
  });

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? const Color(0xFFE5484D) : null,
        ),
      );
  }

  /// رجّع عناصر (واحد أو مجموعة)
  Future<void> _restore(List<String> ids) async {
    if (ids.isEmpty || _restoring) return;
    setState(() => _restoring = true);
    try {
      await DioClient.instance.dio.put(_type.restorePath, data: {'ids': ids});
      if (!mounted) return;
      setState(() {
        _items.removeWhere((m) => ids.contains(_idOf(m)));
        _selected.removeAll(ids);
        _total = (_total - ids.length).clamp(0, 1 << 30);
      });
      _toast('Restored ${ids.length} ${_type.label.toLowerCase()}');
    } catch (e) {
      _toast(DioClient.parse(e).toString(), error: true);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF121212) : AppColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              _Header(
                total: _total,
                typeLabel: _type.label,
                search: _search,
                onSearch: _onSearch,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              // Chips: نوع الـ Trash
              SizedBox(
                height: 56,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: _types.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _TypeChip(
                    label: _types[i].label,
                    icon: _types[i].icon,
                    selected: i == _typeIdx,
                    dark: dark,
                    onTap: () => _setType(i),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _fetch(reset: true),
                  child: _body(dark),
                ),
              ),
            ],
          ),

          // شريط الاسترجاع الجماعي
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: AnimatedSlide(
              offset: _selected.isEmpty ? const Offset(0, 1.6) : Offset.zero,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: _SelectionBar(
                count: _selected.length,
                allSelected: _selected.length == _items.length && _items.isNotEmpty,
                busy: _restoring,
                dark: dark,
                onSelectAll: _selectAll,
                onClear: () => setState(_selected.clear),
                onRestore: () => _restore(_selected.toList()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(bool dark) {
    final sub = dark ? Colors.white60 : AppColors.textSecondary;

    if (_loading && _items.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 120),
        Center(child: CircularProgressIndicator()),
      ]);
    }
    if (_error != null && _items.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 100),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFE5484D))),
              TextButton(onPressed: () => _fetch(reset: true), child: const Text('Retry')),
            ]),
          ),
        ),
      ]);
    }
    if (_items.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 100),
        Icon(Icons.delete_outline_rounded, size: 56, color: sub.withOpacity(0.5)),
        const SizedBox(height: 12),
        Center(child: Text('Trash is empty', style: TextStyle(color: sub, fontSize: 15))),
      ]);
    }

    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      itemCount: _items.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final m = _items[i];
        final id = _idOf(m);
        final title = _type.title(m);
        return _TrashTile(
          icon: _type.icon,
          title: title.isEmpty ? '—' : title,
          subtitle: _type.subtitle(m),
          date: _date(m['updatedAt']),
          selected: _selected.contains(id),
          dark: dark,
          onTap: () => _toggle(id),
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _toggle(id);
          },
          onRestore: () => _restore([id]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  Widgets
// ─────────────────────────────────────────────
class _Header extends StatelessWidget {
  final int total;
  final String typeLabel;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final VoidCallback onBack;
  const _Header({
    required this.total,
    required this.typeLabel,
    required this.search,
    required this.onSearch,
    required this.onBack,
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
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trash',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '$total deleted ${typeLabel.toLowerCase()}',
                        style: TextStyle(
                          color: AppColors.goldLight.withOpacity(0.9),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                height: 46,
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: Colors.black54, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: search,
                        onChanged: onSearch,
                        style: const TextStyle(color: Colors.black),
                        cursorColor: AppColors.navy,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: 'Search in trash',
                          hintStyle: TextStyle(color: Colors.black45, fontSize: 14),
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

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected, dark;
  final VoidCallback onTap;
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? (dark ? AppColors.navy : Colors.white)
        : (dark ? Colors.white70 : AppColors.textSecondary);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? (dark ? AppColors.gold : AppColors.navy)
              : (dark ? AppColors.navyLight : AppColors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : (dark ? AppColors.goldLight.withOpacity(0.15) : AppColors.border),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg)),
          ],
        ),
      ),
    );
  }
}

class _TrashTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle, date;
  final bool selected, dark;
  final VoidCallback onTap, onLongPress, onRestore;
  const _TrashTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.selected,
    required this.dark,
    required this.onTap,
    required this.onLongPress,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final accent = dark ? AppColors.gold : AppColors.navy;
    final sub = dark ? Colors.white60 : AppColors.textSecondary;

    return Material(
      color: dark ? const Color(0xFF1E1E1E) : AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accent : (dark ? Colors.white10 : AppColors.border),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withOpacity(dark ? 0.15 : 0.09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(selected ? Icons.check_rounded : icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: dark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle.trim().isNotEmpty)
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: sub)),
                    if (date.isNotEmpty)
                      Text('Updated $date', style: TextStyle(fontSize: 10.5, color: sub.withOpacity(0.8))),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Restore',
                onPressed: onRestore,
                icon: const Icon(Icons.restore_rounded, color: Color(0xFF10B981)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  final int count;
  final bool allSelected, busy, dark;
  final VoidCallback onSelectAll, onClear, onRestore;
  const _SelectionBar({
    required this.count,
    required this.allSelected,
    required this.busy,
    required this.dark,
    required this.onSelectAll,
    required this.onClear,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: dark ? AppColors.navyLight : AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: dark ? AppColors.goldLight.withOpacity(0.18) : AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.35 : 0.12), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          IconButton(onPressed: onClear, icon: const Icon(Icons.close_rounded)),
          Text('$count selected', style: TextStyle(fontWeight: FontWeight.w700, color: dark ? Colors.white : AppColors.textPrimary)),
          TextButton(onPressed: onSelectAll, child: Text(allSelected ? 'Clear' : 'All')),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: busy ? null : onRestore,
            icon: busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.restore_rounded, size: 18),
            label: const Text('Restore', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}