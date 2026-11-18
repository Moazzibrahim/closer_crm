import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/admin/presentation/screens/admin_leads_screen.dart';
import 'package:flutter_application_1/features/leads/providers/admin_leads_filter_service.dart';

/// ليدز الماركتر: نفس شاشة الأدمن بس من غير delete / trash / restore
class MarketerLeadsScreen extends StatelessWidget {
  final LeadsFilters? preset;
  const MarketerLeadsScreen({super.key, this.preset});

  @override
  Widget build(BuildContext context) {
    return LeadsScreen(
      preset: preset?.copy(),
      canDelete: false, // يخفي زرار Delete وتاب الـ Trash وRestore
      // باقي الصلاحيات (assign / change stage / reset date) زي الأدمن
      canChangeStage: false, // زي التيم ليدر، غيّرها لو عايز
      canAssign: true,
      useUserLookup: true,
    );
  }
}
