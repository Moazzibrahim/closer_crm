// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/features/auth/providers/activity_log_provider.dart';
import 'package:flutter_application_1/features/auth/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return ChangeNotifierProvider(
      create: (_) => ActivityProvider()
        // مقارنة case-insensitive احتياطًا لو الباك رجّع 'admin'
        ..isAdmin = (auth.role ?? '').toLowerCase() == 'admin'
        ..myId = auth.userId ?? ''
        ..refresh(),
      child: const _ActivityView(),
    );
  }
}

class _ActivityView extends StatefulWidget {
  const _ActivityView();
  @override
  State<_ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<_ActivityView> {
  final _scroll = ScrollController();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    // pagination: لما توصل قرب آخر القائمة حمّل الصفحة اللي بعدها
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        context.read<ActivityProvider>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  static const _actionOptions = [
    'create',
    'update',
    'delete',
    'assign',
    'change_stage',
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ActivityProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.background,
      appBar: AppBar(
        title: Text(p.isAdmin ? 'All Activity' : 'My Activity'),
        backgroundColor: isDark ? const Color(0xFF121212) : AppColors.white,
        foregroundColor: isDark ? AppColors.goldLight : AppColors.navy,
        elevation: 0,
      ),
      body: Column(
        children: [
          // بحث بالاسم: للأدمن بس
          if (p.isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Search by user name',
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: (v) => p.applyFilters(name: v.trim()),
              ),
            ),
          // فلتر الـ action
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final a in _actionOptions)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: FilterChip(
                      label: Text(a),
                      selected: p.actions.contains(a),
                      onSelected: (on) {
                        final list = [...p.actions];
                        on ? list.add(a) : list.remove(a);
                        p.applyFilters(acts: list, f: p.from, t: p.to);
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: p.refresh,
              child: _body(p, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(ActivityProvider p, bool isDark) {
    if (p.items.isEmpty && p.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p.items.isEmpty && p.error != null) {
      return ListView(
        children: [
          Padding(padding: const EdgeInsets.all(32), child: Text(p.error!)),
        ],
      );
    }
    if (p.items.isEmpty) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No activity yet')),
          ),
        ],
      );
    }
    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: p.items.length + (p.hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (i >= p.items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final l = p.items[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white10 : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.summary,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  // اسم صاحب العملية يظهر للأدمن بس (اليوزر العادي كله بتاعه)
                  if (p.isAdmin) ...[
                    Text(
                      '${l.userName} · ${l.userRole}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                  ] else
                    const Spacer(),
                  Text(
                    l.timeText, // ← بدل الـ hour/minute اليدوي
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
