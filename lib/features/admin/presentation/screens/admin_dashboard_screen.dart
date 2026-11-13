// lib/features/admin/presentation/screens/admin_dashboard_screen.dart
// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/constants/main_shell.dart';
import 'package:flutter_application_1/core/widgets/dashboard_widget.dart';
import 'package:flutter_application_1/features/admin/data/admin_dashboard_model.dart';
import 'package:flutter_application_1/features/admin/providers/dashboard_provider.dart';
import 'package:flutter_application_1/features/auth/providers/auth_provider.dart';
import 'package:flutter_application_1/features/leads/providers/admin_leads_filter_service.dart';
import 'package:flutter_application_1/features/notifications/presentation/notifications_screen.dart';
import 'package:flutter_application_1/features/notifications/provider/notifications_provider.dart';
import 'package:flutter_application_1/features/splash/closer_logo.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────
//  Constants
// ─────────────────────────────────────────────
const _kRed = Color(0xFFF2545B);
const _kBlue = Color(0xFF3B82F6);
const _kGreen = Color(0xFF10B981);

const _monthNames = [
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

// ─────────────────────────────────────────────
//  Stage icons: بتتختار من اسم الـ stage
//  ترتيب الفحص مهم: الأخص الأول (Not Interested قبل Interested)
// ─────────────────────────────────────────────
const List<(List<String>, IconData)> _stageIcons = [
  (['cancel', 'ملغ', 'الغاء'], Icons.event_busy_rounded),
  (
    ['noanswer', 'notanswer', 'unreachable', 'مردش', 'لايرد'],
    Icons.phone_missed_rounded,
  ),
  (
    ['notinterested', 'uninterested', 'lost', 'reject', 'غيرمهتم', 'رفض'],
    Icons.thumb_down_alt_rounded,
  ),
  (['unqualified', 'notqualified'], Icons.person_off_rounded),
  (['interested', 'hot', 'مهتم'], Icons.favorite_rounded),
  (['qualified'], Icons.verified_rounded),
  (
    ['deal', 'closed', 'won', 'sold', 'صفقة', 'بيع'],
    Icons.real_estate_agent_rounded,
  ),
  (['deliver', 'handover', 'تسليم'], Icons.vpn_key_rounded),
  (['reserv', 'booking', 'booked', 'حجز'], Icons.bookmark_added_rounded),
  (['negotiat', 'offer', 'تفاوض', 'عرض'], Icons.price_change_rounded),
  (['visit', 'viewing', 'tour', 'زيارة', 'معاينة'], Icons.home_work_rounded),
  (['meeting', 'اجتماع', 'ميتنج'], Icons.groups_rounded),
  (['callback', 'followup', 'follow', 'متابعة'], Icons.phone_callback_rounded),
  (['whatsapp', 'واتس'], Icons.chat_rounded),
  (['transfer', 'تحويل'], Icons.swap_horiz_rounded),
  (['pending', 'waiting', 'hold', 'انتظار'], Icons.hourglass_top_rounded),
  (['fresh', 'new', 'جديد'], Icons.fiber_new_rounded),
];

IconData _stageIcon(StageStat s) {
  if (s.isVirtual) return Icons.label_off_rounded; // "No stage"
  // نشيل المسافات والشرطات عشان "Done Deal" = "donedeal"
  final n = s.name.toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');
  for (final r in _stageIcons) {
    if (r.$1.any(n.contains)) return r.$2;
  }
  return Icons.apartment_rounded; // أي stage مش معروفة
}

// ─────────────────────────────────────────────
//  Entry: creates the providers and loads data once.
// ─────────────────────────────────────────────
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            NotificationBadge.start();
            return DashboardProvider()..load();
          },
        ),
        ChangeNotifierProvider(create: (_) => DealsProvider()..load()),
      ],
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkOf(context);
    final width = MediaQuery.of(context).size.width;

    final bool isTablet = width >= 600;
    final int crossAxisCount = isTablet ? 3 : 2;
    final double aspect = isTablet ? 2.3 : 1.85;

    final p = context.watch<DashboardProvider>();
    final data = p.data;

    return Scaffold(
      // nav bar + FAB live in MainShell
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          NotificationBadge.refresh();
          await p.resetAndLoad();
          if (context.mounted) await context.read<DealsProvider>().load();
        },
        child: CustomScrollView(
          // Always scrollable so pull-to-refresh works even with few items
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _Header(data: data)),
            const SliverToBoxAdapter(child: SectionTitle('Lead Stages')),

            // فلتر السيلز + فلتر التاريخ
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [_SalesChip(), _RangeChip()],
                ),
              ),
            ),

            // Thin loader when refreshing with data already on screen
            if (p.isLoading && data != null)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              ),

            // Error (with retry). Old data, if any, stays below it.
            if (p.error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ErrorBox(message: p.error!, onRetry: p.load),
                ),
              ),

            // First load
            if (data == null && p.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),

            if (data != null)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: aspect,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _StageCard(stage: data.stages[i]),
                    childCount: data.stages.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SectionTitle('Follow-ups')),
            const SliverToBoxAdapter(child: _FollowUpsSection()),
            const SliverToBoxAdapter(child: SectionTitle('Deals')),
            const SliverToBoxAdapter(child: _DealsSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Header: gradient background + overlapping hero card
// ─────────────────────────────────────────────
class _Header extends StatelessWidget {
  final DashboardStages? data;
  const _Header({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkOf(context);
    final top = MediaQuery.of(context).padding.top;
    // اسم اليوزر اللي عامل لوجين (بيتحدث تلقائيًا لو اتغير)
    final auth = context.watch<AuthProvider>();
    final fullName = auth.name.trim();
    // نعرض الاسم الأول بس، ولو فاضي نعرض "—"
    final displayName = fullName.isEmpty ? '—' : fullName.split(' ').first;

    return Stack(
      children: [
        Column(
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(16, top + 12, 16, 84),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1A1F2E), AppColors.navy]
                      : [AppColors.navy, AppColors.navyLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const CloserLogo(size: 52, background: Colors.black),
                      const Spacer(),
                      ValueListenableBuilder<int>(
                        valueListenable: NotificationBadge.count,
                        builder: (_, n, __) => _IconBox(
                          icon: Icons.notifications_none,
                          badge: n,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            );
                            NotificationBadge.refresh(); // بعد الرجوع
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayName, // ← اسم اليوزر الحالي
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 58),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 0,
          child: _HeroCard(data: data),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Hero card: total leads + (fresh | share) + late
// ─────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final DashboardStages? data;
  const _HeroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkOf(context);

    // "—" while the first load is still running
    final total = data == null ? '—' : '${data!.total}';
    final late = data == null ? '—' : '${data!.lateTotal}';
    final salesName = data?.sales?.name;

    // عنوان الكارت: لو فلتر سيلز بنكتب اسمه
    final title = salesName == null
        ? 'TOTAL LEADS'
        : 'LEADS · ${salesName.toUpperCase()}';

    // أول mini stat: Share لو فلتر سيلز (الـ API بيرجّع fresh = null)، وإلا Fresh
    final Widget first;
    if (data?.share != null) {
      final s = data!.share!;
      first = MiniStat(
        icon: Icons.pie_chart_rounded,
        label: 'Share',
        value: '${s.sales}/${s.all} · ${s.percent.toStringAsFixed(1)}%',
        gold: true,
      );
    } else {
      final f = data?.fresh;
      first = MiniStat(
        icon: Icons.fiber_new_rounded,
        label: 'Fresh',
        value: f == null
            ? '—'
            : '${f.count} · ${f.percent.toStringAsFixed(1)}%',
        gold: true,
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withOpacity(isDark ? 0.4 : 0.14),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.navy.withOpacity(isDark ? 0.5 : 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.group_rounded, color: accentOf(context)),
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
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                        color: labelColorOf(context),
                      ),
                    ),
                    Text(
                      total,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        color: valueColorOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: first),
              const SizedBox(width: 10),
              Expanded(
                child: MiniStat(
                  icon: Icons.schedule_rounded,
                  label: 'Late',
                  value: late,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Header icon button (glass style, optional badge)
// ─────────────────────────────────────────────
class _IconBox extends StatelessWidget {
  final IconData icon;
  final int? badge;
  final VoidCallback? onTap;

  const _IconBox({required this.icon, this.badge, this.onTap});

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Icon(icon, size: 22, color: AppColors.goldLight),
        ),
      ),
    );

    if (badge == null || badge! <= 0) return button;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            constraints: const BoxConstraints(minWidth: 18),
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.navy, width: 1.5),
            ),
            child: Text(
              badge! > 99 ? '+99' : '$badge',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Stage card (wrapper حوالين RingStatCard + لوجيك فتح الـ Leads)
// ─────────────────────────────────────────────
class _StageCard extends StatelessWidget {
  final StageStat stage;
  const _StageCard({required this.stage});

  void _open(BuildContext context) {
    // نفس فلاتر الداشبورد (تاريخ + سيلز) عشان الأرقام تتطابق
    final dash = context.read<DashboardProvider>();
    final range = dash.range;
    final salesId = dash.sales?.id;

    // حوّل لتاب Leads بالفلتر
    context.read<ShellProvider>().openLeads(
      LeadsFilters(
        stages: [stage.id!],
        sales: salesId == null ? null : [salesId],
        createdFrom: range == null ? null : ymd(range.start),
        createdTo: range == null ? null : ymd(range.end),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RingStatCard(
      name: stage.name,
      count: stage.count,
      percent: stage.percent,
      color: stage.color, // اللون جاي من الباك
      icon: _stageIcon(stage),
      late: stage.late,
      lateColor: stage.lateColor,
      // "No stage" مفيش id نفلتر بيه
      onTap: stage.id == null ? null : () => _open(context),
    );
  }
}

// ─────────────────────────────────────────────
//  Sales filter chip (All sales / اسم السيلز)
// ─────────────────────────────────────────────
class _SalesChip extends StatelessWidget {
  const _SalesChip();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DashboardProvider>();
    final sales = p.sales;

    return FilterChipButton(
      label: sales?.name ?? 'All sales',
      icon: Icons.person_search_rounded,
      maxLabelWidth: 140,
      onClear: sales != null ? p.clearSales : null, // رجوع لكل السيلز
      onTap: () {
        p.ensureSalesLoaded(); // بيحمّل القايمة مرة واحدة ويتكاش
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          // الشيت route جديد، فبنمرر نفس الـ provider ليه
          builder: (_) => ChangeNotifierProvider.value(
            value: p,
            child: const _SalesSheet(),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  Sales picker sheet (بحث + اختيار واحد)
// ─────────────────────────────────────────────
class _SalesSheet extends StatefulWidget {
  const _SalesSheet();

  @override
  State<_SalesSheet> createState() => _SalesSheetState();
}

class _SalesSheetState extends State<_SalesSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DashboardProvider>();
    final shown = p.salesOptions
        .where((o) => o.name.toLowerCase().contains(_q.toLowerCase()))
        .toList();

    Widget body;
    if (p.salesLoading && p.salesOptions.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (p.salesError != null && p.salesOptions.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              p.salesError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            TextButton(
              onPressed: p.ensureSalesLoaded,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else {
      body = ListView(
        children: [
          // All sales = بدون فلتر
          ListTile(
            leading: const Icon(Icons.groups_rounded),
            title: const Text('All sales'),
            trailing: p.sales == null ? const Icon(Icons.check_rounded) : null,
            onTap: () {
              Navigator.pop(context);
              p.clearSales();
            },
          ),
          for (final o in shown)
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: Text(o.name),
              trailing: p.sales?.id == o.id
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () {
                Navigator.pop(context);
                p.setSales(o);
              },
            ),
          if (shown.isEmpty && !p.salesLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No sales found')),
            ),
        ],
      );
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                hintText: 'Search sales',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Date-range filter chip (All time / 2026-10-01 → 2026-10-31)
// ─────────────────────────────────────────────
class _RangeChip extends StatelessWidget {
  const _RangeChip();

  Future<void> _pick(BuildContext context, DashboardProvider p) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: p.range,
    );
    if (picked != null) p.setRange(picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DashboardProvider>();
    final range = p.range;

    return FilterChipButton(
      label: range == null
          ? 'All time'
          : '${ymd(range.start)} → ${ymd(range.end)}',
      icon: Icons.date_range_rounded,
      onClear: range != null ? p.clearRange : null, // back to all time
      onTap: () => _pick(context, p),
    );
  }
}

// ─────────────────────────────────────────────
//  Follow-ups
// ─────────────────────────────────────────────

/// بيفتح تاب Leads بفلتر الـ follow-up / stale
void _openFollowUpLeads(
  BuildContext context, {
  bool late = false,
  String? from, // ISO من الـ API
  String? to,
  String? stale,
}) {
  final salesId = context.read<DashboardProvider>().sales?.id;
  context.read<ShellProvider>().openLeads(
    LeadsFilters(
      lateFollowUp: late,
      followUpFrom: from,
      followUpTo: to,
      stale: stale,
      sales: salesId == null ? null : [salesId],
    ),
  );
}

String _lateText(DateTime? d) {
  if (d == null) return '';
  final days = DateTime.now().difference(d).inDays;
  return days <= 0 ? 'today' : '${days}d late';
}

class _FollowUpsSection extends StatelessWidget {
  const _FollowUpsSection();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DashboardProvider>();
    final f = p.followUps;

    if (f == null) {
      if (p.followUpsError != null) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ErrorBox(message: p.followUpsError!, onRetry: p.loadFollowUps),
        );
      }
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (p.followUpsError != null)
            ErrorBox(message: p.followUpsError!, onRetry: p.loadFollowUps),

          // Buckets (الحدود جاية من الـ API نفسه)
          Row(
            children: [
              BucketTile(
                label: 'Overdue',
                count: f.overdue.count,
                color: _kRed,
                onTap: () => _openFollowUpLeads(context, late: true),
              ),
              const SizedBox(width: 8),
              BucketTile(
                label: 'Today',
                count: f.today.count,
                color: AppColors.gold,
                onTap: () => _openFollowUpLeads(
                  context,
                  from: f.today.from,
                  to: f.today.to,
                ),
              ),
              const SizedBox(width: 8),
              BucketTile(
                label: 'Tomorrow',
                count: f.tomorrow.count,
                color: _kBlue,
                onTap: () => _openFollowUpLeads(
                  context,
                  from: f.tomorrow.from,
                  to: f.tomorrow.to,
                ),
              ),
              const SizedBox(width: 8),
              BucketTile(
                label: 'Week',
                count: f.week.count,
                color: _kGreen,
                onTap: () => _openFollowUpLeads(
                  context,
                  from: f.week.from,
                  to: f.week.to,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stale
          MenuRowsCard(
            rows: [
              MenuRow(
                Icons.comments_disabled_rounded,
                'No comment',
                f.stale.noComment,
                onTap: () => _openFollowUpLeads(context, stale: 'noComment'),
              ),
              MenuRow(
                Icons.touch_app_rounded,
                'Untouched',
                f.stale.untouched,
                onTap: () => _openFollowUpLeads(context, stale: 'untouched'),
              ),
              MenuRow(
                Icons.person_off_rounded,
                'Unassigned (old)',
                f.stale.unassignedOld,
                onTap: () =>
                    _openFollowUpLeads(context, stale: 'unassignedOld'),
              ),
            ],
          ),

          // Most overdue
          if (f.mostOverdue.isNotEmpty) ...[
            const SizedBox(height: 12),
            RowsCard(
              title: 'Most overdue',
              rows: [
                for (final l in f.mostOverdue)
                  RowItem(
                    title: l.name,
                    subtitle: [
                      l.stageName,
                      l.salesNames.isEmpty
                          ? 'Unassigned'
                          : l.salesNames.join(', '),
                    ].join(' · '),
                    trailing: _lateText(l.dueAt),
                    dotColor: l.stageColor,
                    trailingColor: _kRed,
                  ),
              ],
            ),
          ],

          // Late by sales
          if (f.lateBySales.isNotEmpty) ...[
            const SizedBox(height: 12),
            RowsCard(
              title: 'Late by sales',
              rows: [
                for (final s in f.lateBySales)
                  RowItem(
                    title: s.name,
                    trailing: '${s.late} late',
                    icon: Icons.person_rounded,
                    trailingColor: _kRed,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Deals section: filters + totals + timeline + by sales/stage
// ─────────────────────────────────────────────
class _DealsSection extends StatelessWidget {
  const _DealsSection();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DealsProvider>();
    final d = p.data;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DealsFilters(),
          const SizedBox(height: 12),
          if (p.isLoading && d != null)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (p.error != null) ErrorBox(message: p.error!, onRetry: p.load),
          if (d == null && p.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (d != null) ...[
            StatGrid(
              items: [
                StatItem('Deals', '${d.totals.deals}', Icons.handshake_rounded),
                StatItem(
                  'Clients',
                  '${d.totals.clients}',
                  Icons.groups_rounded,
                ),
                StatItem(
                  'Value',
                  formatMoney(d.totals.value),
                  Icons.payments_rounded,
                ),
                StatItem(
                  'Commission',
                  formatMoney(d.totals.commission),
                  Icons.percent_rounded,
                ),
                StatItem(
                  'Cashback',
                  formatMoney(d.totals.cashback),
                  Icons.savings_rounded,
                ),
                StatItem(
                  'Net',
                  formatMoney(d.totals.net),
                  Icons.account_balance_wallet_rounded,
                ),
              ],
            ),
            const SizedBox(height: 12),
            BarTimeline(
              title: 'Timeline',
              emptyText: 'No deals in this period',
              points: [
                for (final t in d.timeline) BarPoint(t.label, t.value, t.deals),
              ],
            ),
            if (d.bySales.isNotEmpty) ...[
              const SizedBox(height: 12),
              RowsCard(
                title: 'By sales',
                rows: [
                  for (final r in d.bySales)
                    RowItem(
                      title: r.name,
                      trailing: '${r.deals} · ${formatMoney(r.value)}',
                      icon: Icons.person_rounded,
                    ),
                ],
              ),
            ],
            if (d.byStage.isNotEmpty) ...[
              const SizedBox(height: 12),
              RowsCard(
                title: 'By stage',
                rows: [
                  for (final r in d.byStage)
                    RowItem(
                      title: r.name,
                      trailing: '${r.deals} · ${formatMoney(r.value)}',
                      icon: Icons.flag_rounded,
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DealsFilters extends StatelessWidget {
  const _DealsFilters();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DealsProvider>();
    final years = p.data?.years.isNotEmpty == true
        ? p.data!.years
        : [DateTime.now().year];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // View + year
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in const ['month', 'quarter', 'year'])
              FilterChipButton(
                label: v[0].toUpperCase() + v.substring(1),
                selected: p.view == v,
                onTap: () => p.setView(v),
              ),
            for (final y in years)
              FilterChipButton(
                label: '$y',
                selected: p.year == y,
                onTap: () => p.setYear(y),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Sub-period: quarter or month
        if (p.view == 'quarter')
          Wrap(
            spacing: 8,
            children: [
              for (var q = 1; q <= 4; q++)
                FilterChipButton(
                  label: 'Q$q',
                  selected: p.quarter == q,
                  onTap: () => p.setQuarter(q),
                ),
            ],
          ),
        if (p.view == 'month')
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var m = 1; m <= 12; m++)
                FilterChipButton(
                  label: _monthNames[m - 1],
                  selected: p.month == m,
                  onTap: () => p.setMonth(m),
                ),
            ],
          ),
        const SizedBox(height: 8),

        // Multi-select sales
        FilterChipButton(
          label: p.salesIds.isEmpty
              ? 'All sales'
              : '${p.salesIds.length} sales selected',
          icon: Icons.person_search_rounded,
          selected: p.salesIds.isNotEmpty,
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => ChangeNotifierProvider.value(
              value: p,
              child: const _DealsSalesSheet(),
            ),
          ),
        ),
      ],
    );
  }
}

class _DealsSalesSheet extends StatelessWidget {
  const _DealsSalesSheet();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DealsProvider>();
    final opts = p.data?.salesOptions ?? [];

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.groups_rounded),
            title: const Text('All sales'),
            trailing: p.salesIds.isEmpty
                ? const Icon(Icons.check_rounded)
                : null,
            onTap: () {
              Navigator.pop(context);
              p.clearSales();
            },
          ),
          for (final o in opts)
            CheckboxListTile(
              value: p.salesIds.contains(o.id),
              title: Text(o.name),
              onChanged: (_) => p.toggleSales(o.id),
            ),
          if (opts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No sales found')),
            ),
        ],
      ),
    );
  }
}
