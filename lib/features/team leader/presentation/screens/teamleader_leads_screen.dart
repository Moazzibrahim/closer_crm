import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/admin/presentation/screens/admin_leads_screen.dart';
import 'package:flutter_application_1/features/auth/providers/auth_provider.dart';
import 'package:flutter_application_1/features/leads/presentation/screens/lead_details_screen_master.dart';
import 'package:flutter_application_1/features/leads/providers/admin_leads_filter_service.dart';
import 'package:provider/provider.dart';

class TeamLeaderLeadsScreen extends StatelessWidget {
  final String userId;
  final LeadsFilters? extraPreset;

  const TeamLeaderLeadsScreen({
    super.key,
    required this.userId,
    this.extraPreset,
  });

  @override
  Widget build(BuildContext context) {
    final name = context.read<AuthProvider>().name;

    return LeadsScreen(
      myLeads: false,
      preset: extraPreset?.copy(),
      canAssign: true,
      allowAssignTeamLeader: false,
      canResetCreationDate: false, // 👈 بيخفي Reset creation date
      teamOwnerId: userId,
      teamOwnerName: name, // 👈 بيظهر "(me)" في قايمة السيلز
      teamOwnerIsManager: false,
      canChangeStage: false,
      canDelete: false,
      detailsConfig: LeadDetailsConfig.sales,
    );
  }
}
