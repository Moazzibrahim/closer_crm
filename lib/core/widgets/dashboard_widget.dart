// lib/core/widgets/dashboard_widgets.dart
// ignore_for_file: unnecessary_underscores, use_null_aware_elements

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';

// ─────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────
bool isDarkOf(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color accentOf(BuildContext c) =>
    isDarkOf(c) ? AppColors.goldLight : AppColors.navy;
Color labelColorOf(BuildContext c) =>
    isDarkOf(c) ? Colors.white54 : AppColors.textSecondary;
Color valueColorOf(BuildContext c) =>
    isDarkOf(c) ? Colors.white : AppColors.textPrimary;

String formatMoney(double v) {
  if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(2)}M';
  if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
  return v.toStringAsFixed(v % 1 == 0 ? 0 : 2);
}

BoxDecoration cardDecoration(bool isDark) => BoxDecoration(
  color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: isDark ? Colors.white10 : AppColors.border),
);

// ─────────────────────────────────────────────
//  AppCard: الكارت الأساسي (container بالديكور الموحد)
// ─────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final deco = cardDecoration(isDarkOf(context));
    if (onTap == null) {
      return Container(padding: padding, decoration: deco, child: child);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(padding: padding, decoration: deco, child: child),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SectionTitle
// ─────────────────────────────────────────────
class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: valueColorOf(context),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CardLabel: العنوان الصغير فوق الكروت (MOST OVERDUE / TIMELINE ...)
// ─────────────────────────────────────────────
class CardLabel extends StatelessWidget {
  final String text;
  const CardLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 10,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w600,
      color: labelColorOf(context),
    ),
  );
}

// ─────────────────────────────────────────────
//  FilterChipButton: الـ chip بتاع الفلاتر (كان _chip + _SalesChip + _RangeChip)
// ─────────────────────────────────────────────
class FilterChipButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onClear; // لو موجودة بيظهر زرار X
  final double maxLabelWidth;
  const FilterChipButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.selected = false,
    this.onClear,
    this.maxLabelWidth = 160,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkOf(context);
    final accent = accentOf(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withOpacity(selected ? 0.25 : (isDark ? 0.12 : 0.08)),
          borderRadius: BorderRadius.circular(20),
          border: selected ? Border.all(color: accent) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 6),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxLabelWidth),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded, size: 15, color: accent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  StatTile: مربع رقم + أيقونة + عنوان (كان _DealTile)
// ─────────────────────────────────────────────
class StatTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: accentOf(context)),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: valueColorOf(context),
              ),
            ),
          ),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w600,
              color: labelColorOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// بيانات بسيطة للـ grid
class StatItem {
  final String label, value;
  final IconData icon;
  const StatItem(this.label, this.value, this.icon);
}

class StatGrid extends StatelessWidget {
  final List<StatItem> items;
  final int crossAxisCount;
  final double aspect;
  const StatGrid({
    super.key,
    required this.items,
    this.crossAxisCount = 3,
    this.aspect = 1.25,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: aspect,
      children: [
        for (final i in items)
          StatTile(label: i.label, value: i.value, icon: i.icon),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  BucketTile: رقم كبير + عنوان (Overdue / Today ...)
// ─────────────────────────────────────────────
class BucketTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final VoidCallback? onTap;
  const BucketTile({
    super.key,
    required this.label,
    required this.count,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkOf(context);
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 12),
        onTap: count > 0 ? onTap : null,
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: count > 0
                    ? color
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w600,
                color: labelColorOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  RowsCard: كارت بعنوان + صفوف (name + trailing)
//  بيغطي BY SALES / BY STAGE / LATE BY SALES
// ─────────────────────────────────────────────
class RowItem {
  final String title;
  final String? subtitle;
  final String trailing;
  final IconData? icon;
  final Color? dotColor; // لو موجود بيرسم نقطة بدل الأيقونة
  final Color? trailingColor;
  final VoidCallback? onTap;
  const RowItem({
    required this.title,
    required this.trailing,
    this.subtitle,
    this.icon,
    this.dotColor,
    this.trailingColor,
    this.onTap,
  });
}

class RowsCard extends StatelessWidget {
  final String title;
  final List<RowItem> rows;
  const RowsCard({super.key, required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardLabel(title),
          const SizedBox(height: 8),
          for (final r in rows)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: r.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    if (r.dotColor != null)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: r.dotColor,
                          shape: BoxShape.circle,
                        ),
                      )
                    else if (r.icon != null)
                      Icon(r.icon, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.title.isEmpty ? '—' : r.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: valueColorOf(context),
                            ),
                          ),
                          if (r.subtitle != null)
                            Text(
                              r.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: labelColorOf(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      r.trailing,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: r.trailingColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  MenuRowsCard: كارت صفوف بأيقونة + رقم + سهم (كان _StaleCard)
// ─────────────────────────────────────────────
class MenuRow {
  final IconData icon;
  final String label;
  final int value;
  final VoidCallback? onTap;
  const MenuRow(this.icon, this.label, this.value, {this.onTap});
}

class MenuRowsCard extends StatelessWidget {
  final List<MenuRow> rows;
  const MenuRowsCard({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkOf(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          for (final r in rows)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: r.value > 0 ? r.onTap : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(r.icon, size: 18, color: accentOf(context)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.white70
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '${r.value}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: valueColorOf(context),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  BarTimeline: رسم أعمدة بسيط (كان _DealsTimeline)
// ─────────────────────────────────────────────
class BarPoint {
  final String label;
  final double value;
  final int count;
  const BarPoint(this.label, this.value, this.count);
}

class BarTimeline extends StatelessWidget {
  final String title;
  final List<BarPoint> points;
  final String emptyText;
  const BarTimeline({
    super.key,
    required this.points,
    this.title = 'Timeline',
    this.emptyText = 'No data in this period',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkOf(context);
    final maxV = points.fold<double>(0, (m, e) => math.max(m, e.value));
    final maxC = points.fold<int>(0, (m, e) => math.max(m, e.count));
    final useValue = maxV > 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardLabel(title),
          const SizedBox(height: 10),
          if (maxV == 0 && maxC == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text(emptyText)),
            )
          else
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: points.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final pt = points[i];
                  final ratio = useValue
                      ? (maxV == 0 ? 0.0 : pt.value / maxV)
                      : (maxC == 0 ? 0.0 : pt.count / maxC);
                  return SizedBox(
                    width: 22,
                    child: Column(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: math.max(
                                ratio * 80,
                                pt.count > 0 ? 4 : 1,
                              ),
                              decoration: BoxDecoration(
                                color: pt.count > 0
                                    ? AppColors.gold
                                    : (isDark
                                          ? Colors.white10
                                          : AppColors.border),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pt.label,
                          style: TextStyle(
                            fontSize: 9,
                            color: labelColorOf(context),
                          ),
                        ),
                      ],
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

// ─────────────────────────────────────────────
//  ErrorBox
// ─────────────────────────────────────────────
class ErrorBox extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const ErrorBox({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  RingStatCard: كارت الـ stage (حلقة + رقم + نسبة + late)
// ─────────────────────────────────────────────
class RingStatCard extends StatelessWidget {
  final String name;
  final int count;
  final double percent; // 0..100
  final Color color;
  final IconData icon;
  final int late;
  final Color? lateColor;
  final VoidCallback? onTap;
  const RingStatCard({
    super.key,
    required this.name,
    required this.count,
    required this.percent,
    required this.color,
    required this.icon,
    this.late = 0,
    this.lateColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkOf(context);
    final progress = (percent / 100).clamp(0.0, 1.0);
    final lc = lateColor ?? const Color(0xFFF2545B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: cardDecoration(isDark).copyWith(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: CustomPaint(
                painter: RingPainter(
                  progress: progress,
                  color: color,
                  track: isDark
                      ? Colors.white10
                      : AppColors.border.withOpacity(0.8),
                ),
                child: Center(child: Icon(icon, size: 19, color: color)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w600,
                      color: labelColorOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          color: valueColorOf(context),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '${percent.toStringAsFixed(percent % 1 == 0 ? 0 : 1)}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (late > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 10, color: lc),
                          const SizedBox(width: 3),
                          Text(
                            '$late late',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: lc,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 4.0;
    final arcRect = (Offset.zero & size).deflate(stroke / 2);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final progPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, trackPaint);
    final sweep = math.max(progress, 0.03) * math.pi * 2;
    canvas.drawArc(arcRect, -math.pi / 2, sweep, false, progPaint);
  }

  @override
  bool shouldRepaint(covariant RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

// ─────────────────────────────────────────────
//  MiniStat: خانة صغيرة (أيقونة + عنوان + قيمة) — جوه الـ hero card
// ─────────────────────────────────────────────
class MiniStat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool gold;
  const MiniStat({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.gold = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkOf(context);
    final Color accent = gold ? AppColors.gold : accentOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withOpacity(isDark ? 0.12 : 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: valueColorOf(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
