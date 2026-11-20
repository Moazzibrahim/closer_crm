import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/admin/presentation/screens/admin_leads_screen.dart';
import 'package:flutter_application_1/features/auth/providers/auth_provider.dart';
import 'package:flutter_application_1/features/leads/presentation/screens/lead_details_screen_master.dart';
import 'package:flutter_application_1/features/leads/providers/admin_leads_filter_service.dart';
import 'package:provider/provider.dart';

/// ليدز الـ Sales Manager: ليدزه + فريقه كله (الباك بيعمل الـ scope من التوكن)
class ManagerLeadsScreen extends StatelessWidget {
  final String userId;
  final LeadsFilters? extraPreset;
  const ManagerLeadsScreen({super.key, required this.userId, this.extraPreset});

  @override
  Widget build(BuildContext context) {
    final name = context.read<AuthProvider>().name;
    return LeadsScreen(
      myLeads: false,
      preset: extraPreset?.copy(),
      canAssign: true,
      allowAssignTeamLeader: true, // assignedAs=teamLeader مسموح للمانجر
      canResetCreationDate: false, // Admin/Marketer بس
      teamOwnerId: userId,
      teamOwnerName: name,
      teamOwnerIsManager: true, // myTeam بيبعت manager=<id>
      canChangeStage: false, // زي التيم ليدر، غيّرها لو عايز
      canDelete: false, // trash/restore مسموحين للمانجر
      detailsConfig: LeadDetailsConfig.manager,
    );
  }
}
