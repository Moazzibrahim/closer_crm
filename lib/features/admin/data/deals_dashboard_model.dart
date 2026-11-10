// lib/features/admin/data/deals_model.dart
import 'package:flutter_application_1/features/admin/data/admin_dashboard_model.dart'; // SalesOpt

double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

class DealsTotals {
  final int deals, clients, linkedDeals, linkedContacts;
  final double value, commission, cashback, net;
  const DealsTotals({
    this.deals = 0, this.clients = 0, this.linkedDeals = 0, this.linkedContacts = 0,
    this.value = 0, this.commission = 0, this.cashback = 0, this.net = 0,
  });
  factory DealsTotals.fromJson(Map<String, dynamic> j) => DealsTotals(
        deals: _i(j['deals']),
        clients: _i(j['clients']),
        linkedDeals: _i(j['linkedDeals']),
        linkedContacts: _i(j['linkedContacts']),
        value: _d(j['value']),
        commission: _d(j['commission']),
        cashback: _d(j['cashback']),
        net: _d(j['net']),
      );
}

class DealsPoint {
  final String label;
  final int deals;
  final double value;
  const DealsPoint(this.label, this.deals, this.value);
  factory DealsPoint.fromJson(Map<String, dynamic> j) =>
      DealsPoint('${j['label'] ?? j['key'] ?? ''}', _i(j['deals']), _d(j['value']));
}

/// صف عام (للـ bySales و byStage) - الحقول متسامحة لأن الـ sample كان فاضي
class DealsRow {
  final String name;
  final int deals;
  final double value;
  const DealsRow(this.name, this.deals, this.value);
  factory DealsRow.fromJson(Map<String, dynamic> j) => DealsRow(
        '${j['name'] ?? j['salesName'] ?? j['stageName'] ?? j['label'] ?? '—'}',
        _i(j['deals'] ?? j['count']),
        _d(j['value'] ?? j['total']),
      );
}

class DealsDashboard {
  final List<int> years;
  final List<SalesOpt> salesOptions;
  final DealsTotals totals;
  final List<DealsRow> bySales, byStage;
  final List<DealsPoint> timeline;
  const DealsDashboard({
    required this.years, required this.salesOptions, required this.totals,
    required this.bySales, required this.byStage, required this.timeline,
  });

  static List<Map<String, dynamic>> _maps(dynamic v) => (v as List? ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  factory DealsDashboard.fromJson(Map<String, dynamic> j) => DealsDashboard(
        years: (j['years'] as List? ?? []).map(_i).toList(),
        salesOptions: _maps(j['salesOptions'])
            .map((e) => SalesOpt('${e['id']}', '${e['name']}'))
            .toList(),
        totals: DealsTotals.fromJson(
            Map<String, dynamic>.from(j['totals'] as Map? ?? {})),
        bySales: _maps(j['bySales']).map(DealsRow.fromJson).toList(),
        byStage: _maps(j['byStage']).map(DealsRow.fromJson).toList(),
        timeline: _maps(j['timeline']).map(DealsPoint.fromJson).toList(),
      );
}