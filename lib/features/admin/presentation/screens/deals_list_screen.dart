// lib/core/widgets/deals_list_screen.dart
// ignore_for_file: deprecated_member_use, unnecessary_underscores
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/widgets/dashboard_widget.dart';

/// قايمة الصفقات من رد GET /dashboard/deals (المفتاح "list")
List<Map<String, dynamic>> dealsListOf(Map<String, dynamic> j) => [
  for (final m in (j['list'] as List? ?? const []).whereType<Map>())
    Map<String, dynamic>.from(m),
];

String _s(dynamic v) => v == null ? '' : '$v'.trim();

String _name(dynamic x) => x is Map ? _s(x['name'] ?? x['fullName']) : _s(x);

Color _hex(String? h, Color fb) {
  var s = (h ?? '').replaceAll('#', '');
  if (s.length == 6) s = 'FF$s';
  final v = int.tryParse(s, radix: 16);
  return v == null ? fb : Color(v);
}

class DealsListScreen extends StatelessWidget {
  final List<Map<String, dynamic>> deals;
  final bool limited;
  final int? total; // 👈 العدد الحقيقي من الـ totals (الكارت)
  final void Function(BuildContext context, String leadId)? onOpenLead;
  const DealsListScreen({
    super.key,
    required this.deals,
    this.limited = false,
    this.total,
    this.onOpenLead,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDarkOf(context);
    final count = total ?? deals.length; // 👈 نفس رقم الكارت
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF121212) : AppColors.background,
      appBar: AppBar(
        title: Text('Deals ($count)'), // 👈 بدل deals.length
        backgroundColor: dark ? AppColors.navyLight : AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: deals.isEmpty
          ? Center(
              child: Text(
                'No deals in this period',
                style: TextStyle(color: labelColorOf(context)),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: deals.length + (limited ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                if (i >= deals.length) {
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      // 👈 بيوضح إن المعروض جزء من الإجمالي
                      'Showing the first ${deals.length} of $count deals',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: labelColorOf(context)),
                    ),
                  );
                }
                return _DealTile(d: deals[i], onOpenLead: onOpenLead);
              },
            ),
    );
  }
}

class _DealTile extends StatelessWidget {
  final Map<String, dynamic> d;
  final void Function(BuildContext, String)? onOpenLead;
  const _DealTile({required this.d, this.onOpenLead});

  @override
  Widget build(BuildContext context) {
    final lead = d['lead'] is Map ? d['lead'] as Map : const {};
    final leadId = _s(lead['id'] ?? lead['_id']);
    final leadName = _s(lead['name']);
    final linkedTo = lead['linkedTo'] is Map ? _name(lead['linkedTo']) : '';
    final linkedCount = (lead['linkedContacts'] as List? ?? const []).length;

    final price = d['unitPrice'] is num
        ? formatMoney((d['unitPrice'] as num).toDouble())
        : '';
    final commission = d['commission'] is num
        ? formatMoney((d['commission'] as num).toDouble())
        : '';
    final net = d['net'] is num
        ? formatMoney((d['net'] as num).toDouble())
        : '';

    final date = DateTime.tryParse(_s(d['at']))?.toLocal();
    final dateText = date == null
        ? ''
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final stage = d['stage'] is Map ? d['stage'] as Map : const {};
    final stageColor = _hex(_s(stage['color']), AppColors.gold);
    final sales = _name(d['sales']);
    final project = _s(d['project']);
    final developer = _s(d['developer']);

    return AppCard(
      onTap: leadId.isEmpty || onOpenLead == null
          ? null
          : () => onOpenLead!(context, leadId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الوحدة + السعر
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_s(d['unitNumber']).isEmpty ? '-' : _s(d['unitNumber'])}'
                  ' • ${_s(d['unitType'])}',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: valueColorOf(context),
                  ),
                ),
              ),
              if (price.isNotEmpty)
                Text(
                  price,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (project.isNotEmpty || developer.isNotEmpty)
            Text(
              [project, developer].where((e) => e.isNotEmpty).join(' · '),
              style: TextStyle(fontSize: 12.5, color: labelColorOf(context)),
            ),
          if (leadName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Lead: $leadName',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: valueColorOf(context),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (_name(stage).isNotEmpty)
                _meta(context, Icons.circle, _name(stage), color: stageColor),
              if (sales.isNotEmpty) _meta(context, Icons.badge_rounded, sales),
              if (dateText.isNotEmpty)
                _meta(context, Icons.event_rounded, dateText),
              if (commission.isNotEmpty)
                _meta(context, Icons.percent_rounded, 'Comm $commission'),
              if (net.isNotEmpty)
                _meta(
                  context,
                  Icons.account_balance_wallet_rounded,
                  'Net $net',
                ),
            ],
          ),
          if (linkedTo.isNotEmpty || linkedCount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.link_rounded,
                    size: 13,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    linkedTo.isNotEmpty
                        ? 'Linked to $linkedTo'
                        : '$linkedCount linked contact${linkedCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _meta(BuildContext c, IconData i, String t, {Color? color}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(i, size: color != null ? 9 : 13, color: color ?? labelColorOf(c)),
      const SizedBox(width: 4),
      Text(t, style: TextStyle(fontSize: 11.5, color: labelColorOf(c))),
    ],
  );
}
