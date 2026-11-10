import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/leads/data/lead_model.dart';
import 'package:flutter_application_1/features/leads/presentation/screens/lead_details_screen_master.dart';

// نفس الـ API القديم، بس بصلاحيات الـ Admin.
class AdminLeadDetailsScreen extends StatelessWidget {
  final String leadId;
  final LeadItem? initial;
  const AdminLeadDetailsScreen({super.key, required this.leadId, this.initial});

  @override
  Widget build(BuildContext context) => LeadDetailsScreen(
    leadId: leadId,
    initial: initial,
    config: LeadDetailsConfig.admin,
  );
}