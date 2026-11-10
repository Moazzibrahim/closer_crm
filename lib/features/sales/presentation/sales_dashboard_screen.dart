// lib/features/sales/presentation/screens/sales_dashboard_screen.dart
// نفس ديزاين داشبورد الأدمن، من غير فلتر السيلز (الداتا دايماً بتاعة اليوزر الحالي).
// ignore_for_file: unnecessary_underscores, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/constants/main_shell.dart';
import 'package:flutter_application_1/core/widgets/dashboard_widget.dart';
import 'package:flutter_application_1/features/auth/providers/auth_provider.dart';
import 'package:flutter_application_1/features/leads/providers/admin_leads_filter_service.dart';
import 'package:flutter_application_1/features/notifications/presentation/notifications_screen.dart';
import 'package:flutter_application_1/features/notifications/provider/notifications_provider.dart';
import 'package:flutter_application_1/features/sales/model/sales_dashboard_model.dart';
import 'package:flutter_application_1/features/sales/presentation/sales_leads_screen.dart';
import 'package:flutter_application_1/features/sales/provider/sales_dashboard_provider.dart';
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

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ─────────────────────────────────────────────
//  Stage icons: بتتختار من اسم الـ stage (الأخص الأول)
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

IconData _stageIcon(String name) {
  final n = name.toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');
  for (final r in _stageIcons) {
    if (r.$1.any(n.contains)) return r.$2;
  }
  return Icons.apartment_rounded;
}

// ─────────────────────────────────────────────
//  Entry: بيعمل الـ provider بـ id اليوزر الحالي
// ─────────────────────────────────────────────
class SalesDashboardScreen extends StatelessWidget {
  const SalesDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final salesId = context.read<AuthProvider>().userId ?? '';
    return ChangeNotifierProvider(
      create: (_) {
        NotificationBadge.start();
        return SalesDashboardProvider(salesId)..load();
      },
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

    final p = context.watch<SalesDashboardProvider>();
    final data = p.stages;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          NotificationBadge.refresh();
          await p.load();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _Header(data: data)),
            const SliverToBoxAdapter(child: SectionTitle('My Lead Stages')),

            // فلتر التاريخ بس (مفيش فلتر سيلز)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [_RangeChip()],
                ),
              ),
            ),

            if (p.stagesLoading && data != null)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              ),

            if (p.stagesError != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ErrorBox(
                    message: p.stagesError!,
                    onRetry: p.loadStages,
                  ),
                ),
              ),

            if (data == null && p.stagesLoading)
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
//  Header: gradient + hero card متداخل
// ─────────────────────────────────────────────
class _Header extends StatelessWidget {
  final StagesData? data;
  const _Header({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkOf(context);
    final top = MediaQuery.of(context).padding.top;
    // الاسم من الـ AuthProvider بدل ما يبقى ثابت
    final name = context.select<AuthProvider, String>((a) => a.name);

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
                      const CloserLogo(size: 52),
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
                            NotificationBadge.refresh();
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
                          name.isEmpty ? 'Sales' : name,
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
//  Hero card: total + share + late
// ─────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final StagesData? data;
  const _HeroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkOf(context);
    final total = data == null ? '—' : '${data!.total}';
    final late = data == null ? '—' : '${data!.lateTotal}';
    // Share: حصتي من كل الـ leads (مثال 3/107 · 2.8%)
    final share = data == null
        ? '—'
        : '${data!.shareSales}/${data!.shareAll} · ${data!.sharePercent.toStringAsFixed(1)}%';

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
                      'MY LEADS',
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
              Expanded(
                child: MiniStat(
                  icon: Icons.pie_chart_rounded,
                  label: 'Share',
                  value: share,
                  gold: true,
                ),
              ),
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
//  Header icon button (glass style + badge)
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
//  Stage card + فتح تاب الـ Leads بنفس الفلاتر
// ─────────────────────────────────────────────
class _StageCard extends StatelessWidget {
  final StageItem stage;
  const _StageCard({required this.stage});

  void _open(BuildContext context) {
    final p = context.read<SalesDashboardProvider>();
    final r = p.range;
    context.read<ShellProvider>().openLeads(
      LeadsFilters(
        stages: [stage.id],
        sales: [p.salesId],
        createdFrom: r == null ? null : _ymd(r.start),
        createdTo: r == null ? null : _ymd(r.end),
      ),
      builder: (preset) => SalesLeadsScreen(preset: preset), // 👈
    );
  }

  @override
  Widget build(BuildContext context) {
    return RingStatCard(
      name: stage.name,
      count: stage.count,
      percent: stage.percent,
      color: stage.color,
      icon: _stageIcon(stage.name),
      late: stage.late,
      lateColor: stage.lateColor,
      onTap: () => _open(context),
    );
  }
}

// ─────────────────────────────────────────────
//  Date-range chip (All time / 2026-10-01 → 2026-10-31)
// ─────────────────────────────────────────────
class _RangeChip extends StatelessWidget {
  const _RangeChip();

  Future<void> _pick(BuildContext context, SalesDashboardProvider p) async {
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
    final p = context.watch<SalesDashboardProvider>();
    final range = p.range;
    return FilterChipButton(
      label: range == null
          ? 'All time'
          : '${_ymd(range.start)} → ${_ymd(range.end)}',
      icon: Icons.date_range_rounded,
      onClear: range != null ? p.clearRange : null,
      onTap: () => _pick(context, p),
    );
  }
}

// ─────────────────────────────────────────────
//  Follow-ups
// ─────────────────────────────────────────────

/// بيفتح تاب Leads بفلتر الـ follow-up / stale (دايماً على leads اليوزر)
void _openFollowUpLeads(
  BuildContext context, {
  bool late = false,
  String? from,
  String? to,
  String? stale,
}) {
  final salesId = context.read<SalesDashboardProvider>().salesId;
  context.read<ShellProvider>().openLeads(
    LeadsFilters(
      lateFollowUp: late,
      followUpFrom: from,
      followUpTo: to,
      stale: stale,
      sales: [salesId],
    ),
    builder: (preset) => SalesLeadsScreen(preset: preset), // 👈
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
    final p = context.watch<SalesDashboardProvider>();
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

          // Buckets (حدود الوقت جاية من الـ API)
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

          // Stale (unassignedOld بيجي null للسيلز فبنخفيه)
          MenuRowsCard(
            rows: [
              MenuRow(
                Icons.comments_disabled_rounded,
                'No comment',
                f.noComment,
                onTap: () => _openFollowUpLeads(context, stale: 'noComment'),
              ),
              MenuRow(
                Icons.touch_app_rounded,
                'Untouched',
                f.untouched,
                onTap: () => _openFollowUpLeads(context, stale: 'untouched'),
              ),
              if (f.unassignedOld != null)
                MenuRow(
                  Icons.person_off_rounded,
                  'Unassigned (old)',
                  f.unassignedOld!,
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
                    subtitle: l.stageName,
                    trailing: _lateText(l.dueAt),
                    dotColor: l.stageColor,
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
//  Deals: فلاتر + totals + timeline
// ─────────────────────────────────────────────
class _DealsSection extends StatelessWidget {
  const _DealsSection();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SalesDashboardProvider>();
    final d = p.deals;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DealsFilters(),
          const SizedBox(height: 12),
          if (p.dealsLoading && d != null)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (p.dealsError != null)
            ErrorBox(message: p.dealsError!, onRetry: p.loadDeals),
          if (d == null && p.dealsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (d != null) ...[
            StatGrid(
              items: [
                StatItem('Deals', '${d.deals}', Icons.handshake_rounded),
                StatItem('Clients', '${d.clients}', Icons.groups_rounded),
                StatItem('Value', formatMoney(d.value), Icons.payments_rounded),
                StatItem(
                  'Commission',
                  formatMoney(d.commission),
                  Icons.percent_rounded,
                ),
                StatItem(
                  'Cashback',
                  formatMoney(d.cashback),
                  Icons.savings_rounded,
                ),
                StatItem(
                  'Net',
                  formatMoney(d.net),
                  Icons.account_balance_wallet_rounded,
                ),
              ],
            ),
            const SizedBox(height: 12),
            BarTimeline(
              title: 'Timeline',
              emptyText: 'No deals in this period',
              points: d.timeline,
            ),
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
    final p = context.watch<SalesDashboardProvider>();
    final years = p.deals?.years.isNotEmpty == true
        ? p.deals!.years
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
                selected: p.dealsView == v,
                onTap: () => p.setView(v),
              ),
            for (final y in years)
              FilterChipButton(
                label: '$y',
                selected: p.dealsYear == y,
                onTap: () => p.setYear(y),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Sub-period: quarter أو month
        if (p.dealsView == 'quarter')
          Wrap(
            spacing: 8,
            children: [
              for (var q = 1; q <= 4; q++)
                FilterChipButton(
                  label: 'Q$q',
                  selected: p.dealsQuarter == q,
                  onTap: () => p.setQuarter(q),
                ),
            ],
          ),
        if (p.dealsView == 'month')
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var m = 1; m <= 12; m++)
                FilterChipButton(
                  label: _monthNames[m - 1],
                  selected: p.dealsMonth == m,
                  onTap: () => p.setMonth(m),
                ),
            ],
          ),
      ],
    );
  }
}
