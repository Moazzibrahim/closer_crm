// ignore_for_file: unnecessary_underscores

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/features/crud/data/users_model.dart';
import 'package:flutter_application_1/features/sessions/provider/session_provider.dart';
import 'package:provider/provider.dart';

// ═════════════════════════════════════════════
//  Screen
// ═════════════════════════════════════════════
class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => SessionsProvider()..init(),
    child: const _SessionsView(),
  );
}

class _SessionsView extends StatefulWidget {
  const _SessionsView();
  @override
  State<_SessionsView> createState() => _SessionsViewState();
}

class _SessionsViewState extends State<_SessionsView> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Infinite scroll: قرب من آخر الليست → حمّل الصفحة اللي بعدها
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        context.read<SessionsProvider>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  // بحث بـ keyword مع debounce عشان ما نبعتش ريكويست مع كل حرف
  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final p = context.read<SessionsProvider>();
      final k = v.trim().isEmpty ? null : v.trim();
      if (k != p.filters.keyword) p.apply(p.filters.copyWith(keyword: k));
    });
  }

  Future<void> _openFilters() async {
    final p = context.read<SessionsProvider>();
    final res = await showModalBottomSheet<SessionFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(initial: p.filters, users: p.users),
    );
    if (res != null) p.apply(res);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = context.watch<SessionsProvider>();
    final bg = dark ? const Color(0xFF121212) : AppColors.background;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text(
          'Sessions',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: false,
        backgroundColor: dark ? const Color(0xFF121212) : AppColors.white,
        foregroundColor: dark ? AppColors.goldLight : AppColors.navy,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          // ── Search + Filter button ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: _onSearch,
                    decoration: const InputDecoration(
                      hintText: 'Search (chrome, windows, ...)',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Badge(
                  isLabelVisible: p.filters.activeCount > 0,
                  label: Text('${p.filters.activeCount}'),
                  child: Material(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: _openFilters,
                      borderRadius: BorderRadius.circular(14),
                      child: const SizedBox(
                        width: 52,
                        height: 52,
                        child: Icon(Icons.tune_rounded, color: AppColors.gold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Active filter chips ──
          _ActiveChips(provider: p),

          // ── Total ──
          if (!p.loading && p.error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${p.total} sessions',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),

          // ── List ──
          Expanded(child: _body(p, dark)),
        ],
      ),
    );
  }

  Widget _body(SessionsProvider p, bool dark) {
    if (p.loading && p.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p.error != null && p.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              p.error!,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: p.refresh, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (p.items.isEmpty) {
      return const Center(
        child: Text(
          'No sessions found',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: p.refresh,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: p.items.length + (p.hasNext ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          if (i >= p.items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            );
          }
          return _SessionCard(s: p.items[i], dark: dark);
        },
      ),
    );
  }
}

// ── Chips الفلاتر المفعّلة (كل chip ممكن تتشال لوحدها) ──
String _ymd(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class _ActiveChips extends StatelessWidget {
  final SessionsProvider provider;
  const _ActiveChips({required this.provider});

  @override
  Widget build(BuildContext context) {
    final f = provider.filters;
    final chips = <Widget>[];

    Widget chip(String label, SessionFilters Function() remove) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onDeleted: () => provider.apply(remove()),
        visualDensity: VisualDensity.compact,
      ),
    );

    if (f.userId != null) {
      chips.add(
        chip(provider.userName(f.userId), () => f.copyWith(userId: null)),
      );
    }
    if (f.platform != null) {
      chips.add(chip(f.platform!, () => f.copyWith(platform: null)));
    }
    if (f.ip != null) chips.add(chip('IP ${f.ip}', () => f.copyWith(ip: null)));
    if (f.createdFrom != null || f.createdTo != null) {
      chips.add(
        chip(
          'Created ${f.createdFrom != null ? _ymd(f.createdFrom!) : '…'} → ${f.createdTo != null ? _ymd(f.createdTo!) : '…'}',
          () => f.copyWith(createdFrom: null, createdTo: null),
        ),
      );
    }
    if (f.lastLoginFrom != null) {
      chips.add(
        chip(
          'Login ≥ ${_ymd(f.lastLoginFrom!)}',
          () => f.copyWith(lastLoginFrom: null),
        ),
      );
    }
    if (f.sort != SessionFilters.defaultSort) {
      chips.add(
        chip(
          'Oldest first',
          () => f.copyWith(sort: SessionFilters.defaultSort),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: chips,
      ),
    );
  }
}

// ── كارت الـ session ──
class _SessionCard extends StatelessWidget {
  final SessionModel s;
  final bool dark;
  const _SessionCard({required this.s, required this.dark});

  IconData get _platformIcon {
    switch (s.platform?.toLowerCase()) {
      case 'android':
        return Icons.android_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      default:
        return Icons.language_rounded; // web
    }
  }

  // "02 Nov 2026, 19:00" بالتوقيت المحلي للجهاز
  String _fmt(DateTime? d) {
    if (d == null) return '—';
    const m = [
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
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}, $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final textC = dark ? Colors.white : AppColors.textPrimary;
    final sub = dark ? Colors.white60 : AppColors.textSecondary;

    Widget info(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: sub),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: sub),
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E1E1E) : AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dark ? Colors.white10 : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.navy,
                child: Text(
                  s.user.initial,
                  style: const TextStyle(
                    color: AppColors.goldLight,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.user.fullName.isEmpty ? '—' : s.user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: textC,
                      ),
                    ),
                    Text(
                      s.user.email ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: sub),
                    ),
                  ],
                ),
              ),
              if (s.user.role != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    s.user.role!,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Divider(height: 14, color: dark ? Colors.white10 : AppColors.border),
          info(_platformIcon, '${s.platform ?? 'web'} • ${s.deviceLabel}'),
          info(Icons.lan_rounded, s.ip ?? '—'),
          if (s.location.label != null)
            info(Icons.place_rounded, s.location.label!),
          info(Icons.access_time_rounded, _fmt(s.lastLoginAt)),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════
//  Filter bottom sheet
//  بيرجّع SessionFilters جديدة لما تدوس Apply
// ═════════════════════════════════════════════
class _FilterSheet extends StatefulWidget {
  final SessionFilters initial;
  final List<UserModel> users;
  const _FilterSheet({required this.initial, required this.users});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _userId = widget.initial.userId;
  late String? _platform = widget.initial.platform;
  late DateTime? _createdFrom = widget.initial.createdFrom;
  late DateTime? _createdTo = widget.initial.createdTo;
  late DateTime? _loginFrom = widget.initial.lastLoginFrom;
  late String _sort = widget.initial.sort;
  late final _ip = TextEditingController(text: widget.initial.ip ?? '');

  @override
  void dispose() {
    _ip.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime? current) => showDatePicker(
    context: context,
    initialDate: current ?? DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime.now().add(const Duration(days: 1)),
  );

  void _apply() {
    final ip = _ip.text.trim();
    Navigator.pop(
      context,
      widget.initial.copyWith(
        userId: _userId,
        platform: _platform,
        ip: ip.isEmpty ? null : ip,
        createdFrom: _createdFrom,
        createdTo: _createdTo,
        lastLoginFrom: _loginFrom,
        sort: _sort,
      ),
    );
  }

  void _reset() => setState(() {
    _userId = _platform = _createdFrom = _createdTo = _loginFrom = null;
    _sort = SessionFilters.defaultSort;
    _ip.clear();
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final label = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: dark ? Colors.white70 : AppColors.textPrimary,
    );

    Widget section(String t, Widget child) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: label),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );

    Widget dateTile(String t, DateTime? v, ValueChanged<DateTime?> onSet) =>
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async => onSet(await _pick(v) ?? v),
            icon: const Icon(Icons.event_rounded, size: 16),
            label: Text(
              v == null ? t : _ymd(v),
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        );

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E1E1E) : AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: dark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(onPressed: _reset, child: const Text('Reset')),
                ],
              ),

              // ── User (من /auth/All) ──
              section(
                'User',
                DropdownButtonFormField<String?>(
                  value: widget.users.any((u) => u.id == _userId)
                      ? _userId
                      : null,
                  isExpanded: true,
                  hint: const Text('All users'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All users'),
                    ),
                    for (final u in widget.users)
                      DropdownMenuItem<String?>(
                        value: u.id,
                        child: Text(
                          '${u.fullName.isEmpty ? (u.email ?? '') : u.fullName}${u.role != null ? ' • ${u.role}' : ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _userId = v),
                ),
              ),

              // ── Platform ──
              section(
                'Platform',
                Wrap(
                  spacing: 8,
                  children: [
                    for (final p in [null, 'web', 'android', 'ios'])
                      ChoiceChip(
                        label: Text(p ?? 'All'),
                        selected: _platform == p,
                        onSelected: (_) => setState(() => _platform = p),
                      ),
                  ],
                ),
              ),

              // ── IP ──
              section(
                'IP address',
                TextField(
                  controller: _ip,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 94.200.12.34',
                    prefixIcon: Icon(Icons.lan_rounded),
                  ),
                ),
              ),

              // ── Created range ──
              section(
                'Created between',
                Row(
                  children: [
                    dateTile(
                      'From',
                      _createdFrom,
                      (d) => setState(() => _createdFrom = d),
                    ),
                    const SizedBox(width: 8),
                    dateTile(
                      'To',
                      _createdTo,
                      (d) => setState(() => _createdTo = d),
                    ),
                  ],
                ),
              ),

              // ── Last login ≥ ──
              section(
                'Last login since',
                Row(
                  children: [
                    dateTile(
                      'Pick date',
                      _loginFrom,
                      (d) => setState(() => _loginFrom = d),
                    ),
                  ],
                ),
              ),

              // ── Sort ──
              section(
                'Sort',
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Newest login'),
                      selected: _sort == '-lastLoginAt',
                      onSelected: (_) => setState(() => _sort = '-lastLoginAt'),
                    ),
                    ChoiceChip(
                      label: const Text('Oldest login'),
                      selected: _sort == 'lastLoginAt',
                      onSelected: (_) => setState(() => _sort = 'lastLoginAt'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Apply',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
