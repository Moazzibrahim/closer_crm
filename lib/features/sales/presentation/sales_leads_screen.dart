// lib/features/sales/presentation/screens/sales_leads_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/admin/presentation/screens/admin_leads_screen.dart';
import 'package:flutter_application_1/features/leads/presentation/screens/lead_details_screen_master.dart';
import 'package:flutter_application_1/features/leads/providers/admin_leads_filter_service.dart';

class SalesLeadsScreen extends StatelessWidget {
  /// الفلاتر جاية من الداشبورد (فيها sales: [salesId])
  final LeadsFilters? preset;
  const SalesLeadsScreen({super.key, this.preset});

  static const _sort = '-nextFollowUpAt';

  @override
  Widget build(BuildContext context) {
    final p = preset ?? LeadsFilters();
    // لو الداشبورد ما حددش sort نثبّت الافتراضي بتاع السيلز
    if (p.sort == '-createdAt') p.sort = _sort;

    return LeadsScreen(
      myLeads: true, // → /Leads/my-leads
      preset: p,
      defaultSort: _sort,
      canAssign: false,
      canChangeStage: false,
      canDelete: false,
      detailsConfig: LeadDetailsConfig.sales, // لو عندك config للسيلز
    );
  }
}
