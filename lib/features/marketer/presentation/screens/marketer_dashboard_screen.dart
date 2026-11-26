// lib/features/marketer/presentation/marketing_dashboard_screen.dart
// داشبورد المسوّق: نفس ديزاين داشبورد السيلز (header + hero card متداخل + كروت).
// ignore_for_file: unnecessary_underscores, deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/constants/main_shell.dart';
import 'package:flutter_application_1/core/widgets/dashboard_widget.dart';
import 'package:flutter_application_1/features/auth/providers/auth_provider.dart';
import 'package:flutter_application_1/features/leads/presentation/screens/lead_details_screen_master.dart';
import 'package:flutter_application_1/features/leads/providers/admin_leads_filter_service.dart';
import 'package:flutter_application_1/features/marketer/data/marketer_dashboard_model.dart';
import 'package:flutter_application_1/features/marketer/presentation/screens/marketer_leads_screen.dart';
import 'package:flutter_application_1/features/marketer/provider/marketer_dashboard_provider.dart';
import 'package:flutter_application_1/features/notifications/presentation/notifications_screen.dart';
import 'package:flutter_application_1/features/notifications/provider/notifications_provider.dart';
import 'package:flutter_application_1/features/splash/closer_logo.dart';
import 'package:provider/provider.dart';

const _kRed = Color(0xFFF2545B);
const _kBlue = Color(0xFF3B82F6);
const _kGreen = Color(0xFF10B981);

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

// ─────────────────────────────────────────────
//  Entry
// ─────────────────────────────────────────────
class MarketingDashboardScreen extends StatefulWidget {
  const MarketingDashboardScreen({super.key});
  @override
  State<MarketingDashboardScreen> createState() =>
      _MarketingDashboardScreenState();
}

class _MarketingDashboardScreenState extends State<MarketingDashboardScreen> {
  @override
  void initState() {
    super.initState();
    NotificationBadge.start();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkOf(context);
    final width = MediaQuery.of(context).size.width;
    final bool isTablet = width >= 600;
    final p = context.watch<MarketingDashboardProvider>();
    final d = p.data;

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
            SliverToBoxAdapter(child: _Header(data: d)),

            // ── الفلاتر: تاريخ + channels ──
            const SliverToBoxAdapter(child: SectionTitle('Overview')),
            SliverToBoxAdapter(child: _Filters(p: p)),

            if (p.loading && d != null)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              ),
            if (p.error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ErrorBox(message: p.error!, onRetry: p.load),
                ),
              ),
            if (d == null && p.loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),

            if (d != null && d.noChannels)
              const SliverToBoxAdapter(child: _EmptyChannels()),

            if (d != null && !d.noChannels) ...[
              // KPIs
              SliverToBoxAdapter(child: _Kpis(t: d.totals)),

              // Funnel
              const SliverToBoxAdapter(child: SectionTitle('Funnel')),
              SliverToBoxAdapter(child: _Funnel(t: d.totals)),

              // Timeline
              const SliverToBoxAdapter(child: SectionTitle('Leads Timeline')),
              SliverToBoxAdapter(child: _TimelineChart(days: d.timeline)),

              // Stages
              const SliverToBoxAdapter(child: SectionTitle('Lead Stages')),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isTablet ? 3 : 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: isTablet ? 2.3 : 1.85,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _StageCard(s: d.byStage[i]),
                    childCount: d.byStage.length,
                  ),
                ),
              ),

              // Breakdowns
              const SliverToBoxAdapter(child: SectionTitle('Performance')),
              SliverToBoxAdapter(
                child: _Breakdown(
                  title: 'By Source',
                  icon: Icons.hub_rounded,
                  rows: d.bySource,
                ),
              ),
              SliverToBoxAdapter(
                child: _Breakdown(
                  title: 'By Campaign',
                  icon: Icons.campaign_rounded,
                  rows: d.byCampaign,
                ),
              ),
              SliverToBoxAdapter(
                child: _Breakdown(
                  title: 'By Project',
                  icon: Icons.apartment_rounded,
                  rows: d.byProject,
                ),
              ),

              // Deals
              const SliverToBoxAdapter(child: SectionTitle('Deals')),
              SliverToBoxAdapter(child: _DealsGrid(t: d.totals)),

              // Recent
              const SliverToBoxAdapter(child: SectionTitle('Recent Leads')),
              SliverToBoxAdapter(child: _RecentLeads(items: d.recent)),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Header + Hero (Total leads / change vs prev period)
// ─────────────────────────────────────────────
class _Header extends StatelessWidget {
  final MarketingData? data;
  const _Header({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkOf(context);
    final top = MediaQuery.of(context).padding.top;
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
                      ? [const Color(0xFF1A1F2E), const Color(0xFF1A1F2E)]
                      : [const Color(0xFF1A1F2E), const Color(0xFF1A1F2E)],
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
                                builder: (_) => const NotificationsScreen(
                                  detailsConfig: LeadDetailsConfig.marketer,
                                  useUserLookup: true,
                                ),
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
                          name.isEmpty ? 'Marketer' : name,
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

class _HeroCard extends StatelessWidget {
  final MarketingData? data;
  const _HeroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkOf(context);
    final t = data?.totals;
    final change = t?.change ?? 0;
    final up = change >= 0;

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
                child: Icon(Icons.campaign_rounded, color: accentOf(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL LEADS',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                        color: labelColorOf(context),
                      ),
                    ),
                    Text(
                      t == null ? '—' : '${t.leads}',
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
              // التغيير مقارنة بالفترة السابقة
              if (t != null)
                _Pill(
                  '${up ? '▲' : '▼'} ${change.abs().toStringAsFixed(1)}%',
                  up ? _kGreen : _kRed,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: MiniStat(
                  icon: Icons.trending_up_rounded,
                  label: 'Conversion',
                  value: t == null
                      ? '—'
                      : '${t.conversion.toStringAsFixed(1)}%',
                  gold: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MiniStat(
                  icon: Icons.schedule_rounded,
                  label: 'Late',
                  value: t == null ? '—' : '${t.late}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.14),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}

// ─────────────────────────────────────────────
//  Filters: date range + channels
// ─────────────────────────────────────────────
class _Filters extends StatelessWidget {
  final MarketingDashboardProvider p;
  const _Filters({required this.p});

  Future<void> _pick(BuildContext context) async {
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
    final channels = p.data?.channels ?? const <MktChannel>[];
    final r = p.range;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilterChipButton(
            label: r == null
                ? 'Last 30 days'
                : '${_ymd(r.start)} → ${_ymd(r.end)}',
            icon: Icons.date_range_rounded,
            onClear: r != null ? p.clearRange : null,
            onTap: () => _pick(context),
          ),
          if (channels.isNotEmpty)
            FilterChipButton(
              label: 'All channels',
              selected: p.channelId == null,
              onTap: () => p.setChannel(null),
            ),
          for (final c in channels)
            FilterChipButton(
              label: c.name,
              selected: p.channelId == c.id,
              onTap: () => p.setChannel(c.id),
            ),
        ],
      ),
    );
  }
}

class _EmptyChannels extends StatelessWidget {
  const _EmptyChannels();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
    child: Center(
      child: Text(
        'No channels assigned to you yet',
        style: TextStyle(color: labelColorOf(context)),
      ),
    ),
  );
}

// ─────────────────────────────────────────────
//  KPIs
// ─────────────────────────────────────────────
class _Kpis extends StatelessWidget {
  final MktTotals t;
  const _Kpis({required this.t});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StatGrid(
        items: [
          StatItem('Assigned', '${t.assigned}', Icons.person_add_alt_1_rounded),
          StatItem('Contacted', '${t.contacted}', Icons.phone_in_talk_rounded),
          StatItem('Closed', '${t.closed}', Icons.verified_rounded),
          StatItem('Fresh', '${t.fresh}', Icons.fiber_new_rounded),
          StatItem('Unassigned', '${t.unassigned}', Icons.person_off_rounded),
          StatItem('Resubmissions', '${t.resubmissions}', Icons.replay_rounded),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Funnel: Leads → Assigned → Contacted → Closed
// ─────────────────────────────────────────────
class _Funnel extends StatelessWidget {
  final MktTotals t;
  const _Funnel({required this.t});

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkOf(context);
    final steps = [
      ('Leads', t.leads, AppColors.navyLight),
      ('Assigned', t.assigned, _kBlue),
      ('Contacted', t.contacted, AppColors.gold),
      ('Closed', t.closed, _kGreen),
    ];
    final max = math.max(1, t.leads);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(isDark, 18),
      child: Column(
        children: [
          for (final s in steps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 78,
                    child: Text(
                      s.$1,
                      style: TextStyle(
                        fontSize: 12,
                        color: labelColorOf(context),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: s.$2 / max,
                        minHeight: 10,
                        color: s.$3,
                        backgroundColor: s.$3.withOpacity(0.12),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${s.$2}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: valueColorOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDeco(bool isDark, double r) => BoxDecoration(
  color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
  borderRadius: BorderRadius.circular(r),
  border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
);

// ─────────────────────────────────────────────
//  Stage card (ring + count)
// ─────────────────────────────────────────────
class _StageCard extends StatelessWidget {
  final MktStage s;
  const _StageCard({required this.s});

  // كارت "No stage" الـ id بتاعه فاضي/null من الباك
  bool get _isNoStage {
    final n = s.name.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
    return s.id.isEmpty || s.id == 'null' || n == 'nostage';
  }

  void _open(BuildContext context) {
    final p = context.read<MarketingDashboardProvider>();
    // لو مفيش range مختار الباك بيستخدم آخر 30 يوم، فنطابقه
    final now = DateTime.now();
    final r =
        p.range ??
        DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);

    context.read<ShellProvider>().openLeads(
      LeadsFilters(
        stages: _isNoStage ? const [] : [s.id],
        noStage: _isNoStage,
        createdFrom: _ymd(r.start),
        createdTo: _ymd(r.end),
      ),
      builder: (preset) =>
          MarketerLeadsScreen(preset: preset), // 👈 من غير delete
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDeco(isDark, 18),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: (s.percent / 100).clamp(0.0, 1.0),
                    strokeWidth: 5,
                    color: s.color,
                    backgroundColor: s.color.withOpacity(0.15),
                  ),
                  Text(
                    '${s.count}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: valueColorOf(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: valueColorOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${s.percent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: labelColorOf(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: labelColorOf(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Breakdown card (source / campaign / project)
// ─────────────────────────────────────────────
class _Breakdown extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<MktBreakdown> rows;
  const _Breakdown({
    required this.title,
    required this.icon,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final isDark = isDarkOf(context);
    final maxLeads = rows.fold<int>(1, (m, r) => math.max(m, r.leads));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: _cardDeco(isDark, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.gold),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: valueColorOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: valueColorOf(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Pill(
                        '${r.conversion.toStringAsFixed(1)}%',
                        r.conversion > 0 ? _kGreen : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${r.leads}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: valueColorOf(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: r.leads / maxLeads,
                      minHeight: 6,
                      color: AppColors.gold,
                      backgroundColor: AppColors.gold.withOpacity(0.12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Assigned ${r.assigned} · Contacted ${r.contacted} · Closed ${r.closed}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: labelColorOf(context),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Deals
// ─────────────────────────────────────────────
class _DealsGrid extends StatelessWidget {
  final MktTotals t;
  const _DealsGrid({required this.t});

  @override
  Widget build(BuildContext context) {
    final d = t.deals;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StatGrid(
        items: [
          StatItem('Deals', '${d.count}', Icons.handshake_rounded),
          StatItem('Clients', '${d.clients}', Icons.groups_rounded),
          StatItem('Value', formatMoney(d.value), Icons.payments_rounded),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Recent leads
// ─────────────────────────────────────────────
class _RecentLeads extends StatelessWidget {
  final List<MktRecentLead> items;
  const _RecentLeads({required this.items});

  String _when(DateTime? d) {
    if (d == null) return '';
    return '${d.day} ${_months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'No leads in this period',
            style: TextStyle(color: labelColorOf(context)),
          ),
        ),
      );
    }
    final isDark = isDarkOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final l in items)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: _cardDeco(isDark, 16),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: l.stageColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: valueColorOf(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${l.source} · ${l.campaign} · ${l.project}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: labelColorOf(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: [
                            _Pill(l.stageName ?? 'No stage', l.stageColor),
                            if (!l.assigned) const _Pill('Unassigned', _kRed),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _when(l.at),
                    style: TextStyle(
                      fontSize: 11,
                      color: labelColorOf(context),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Timeline chart: عمودين لكل يوم (Leads + Closed)
// ─────────────────────────────────────────────
class _TimelineChart extends StatelessWidget {
  final List<MktDay> days;
  const _TimelineChart({required this.days});

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkOf(context);
    final hasData = days.any((d) => d.leads > 0 || d.closed > 0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: _cardDeco(isDark, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Legend(isDark ? AppColors.goldLight : AppColors.navy, 'Leads'),
              const SizedBox(width: 14),
              const _Legend(_kGreen, 'Closed'),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasData)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'No leads in this period',
                  style: TextStyle(color: labelColorOf(context)),
                ),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: LayoutBuilder(
                builder: (_, c) {
                  final w = math.max(c.maxWidth, days.length * 30.0);
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: CustomPaint(
                      size: Size(w, 200),
                      painter: _DaysPainter(
                        days: days,
                        leadsColor: isDark
                            ? AppColors.goldLight
                            : AppColors.navy,
                        grid: isDark ? Colors.white12 : AppColors.border,
                        sub: isDark ? Colors.white54 : AppColors.textSecondary,
                        text: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 11, color: labelColorOf(context))),
    ],
  );
}

class _DaysPainter extends CustomPainter {
  final List<MktDay> days;
  final Color leadsColor, grid, sub, text;
  const _DaysPainter({
    required this.days,
    required this.leadsColor,
    required this.grid,
    required this.sub,
    required this.text,
  });

  void _label(Canvas c, String s, Offset at, TextStyle st, double maxW) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: st),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxW);
    tp.paint(c, Offset(at.dx - tp.width / 2, at.dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 28.0, top = 18.0, bottom = 28.0;
    final h = size.height - top - bottom;
    final w = size.width - left;
    final maxV = days.fold<int>(
      1,
      (m, d) => math.max(m, math.max(d.leads, d.closed)),
    );
    final lines = math.max(1, math.min(maxV, 4)); // أقصى 4 خطوط شبكة
    final axisMax =
        (maxV / lines).ceil() * lines; // عشان القيم على المحور تبقى أعداد صحيحة
    final step = axisMax ~/ lines;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    final subStyle = TextStyle(fontSize: 10, color: sub);

    for (var i = 0; i <= lines; i++) {
      final y = top + h - h * i / lines;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: '${step * i}', style: subStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(left - 6 - tp.width, y - tp.height / 2));
    }

    final slot = w / days.length;
    final barW = math.min(10.0, slot * 0.32);

    void bar(double cx, int v, Color color) {
      if (v <= 0) return;
      final bh = math.max(3.0, h * v / axisMax);
      final rect = Rect.fromLTWH(cx - barW / 2, top + h - bh, barW, bh);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        Paint()..color = color,
      );
    }

    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final cx = left + slot * (i + 0.5);
      bar(cx - barW / 2 - 1, d.leads, leadsColor);
      bar(cx + barW / 2 + 1, d.closed, _kGreen);

      // أول يوم أو أول الشهر: نكتب الشهر، وإلا اليوم بس
      final showMonth = i == 0 || d.date.day == 1;
      _label(
        canvas,
        showMonth
            ? '${d.date.day} ${_months[d.date.month - 1]}'
            : '${d.date.day}',
        Offset(cx, top + h + 8),
        subStyle,
        slot * 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DaysPainter old) =>
      old.days != days || old.grid != grid || old.leadsColor != leadsColor;
}
