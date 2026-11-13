// ignore_for_file: deprecated_member_use, unused_local_variable
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/features/leads/data/lead_model.dart';
import 'package:flutter_application_1/features/leads/presentation/widgets/lead_phone_widget.dart';

class LeadCard extends StatelessWidget {
  final LeadItem lead;
  final bool dark;
  final bool selecting; // فيه selection شغال؟
  final bool selected; // الكارت ده متحدد؟
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onCall, onWhatsApp, onNote;

  const LeadCard({
    super.key,
    required this.lead,
    required this.dark,
    this.selecting = false,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.onCall,
    this.onWhatsApp,
    this.onNote,
  });

  String get _initials {
    final parts = lead.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts[1][0] : ''))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final stage = lead.stageColor;
    final accent = dark ? AppColors.gold : AppColors.navy;
    final baseSurface = dark ? AppColors.navyLight : AppColors.white;
    final surface = selected
        ? Color.alphaBlend(accent.withOpacity(0.08), baseSurface)
        : baseSurface;
    final textMain = dark ? AppColors.white : AppColors.textPrimary;
    final textSub = dark ? Colors.white60 : AppColors.textSecondary;
    final borderColor = dark
        ? AppColors.goldLight.withOpacity(0.15)
        : AppColors.border;

    // معاد المتابعة (بيتمسح من السيرفر لما الـ stage نهائية → نرجع لتاريخ الـ stage)
    final followUp = lead.nextFollowUpAt;
    final isLate = followUp != null && followUp.isBefore(DateTime.now());
    final dateText = fmtLeadDate(followUp ?? lead.stageDate);
    final dateIcon = followUp != null
        ? Icons.alarm_rounded
        : Icons.schedule_rounded;
    final dateColor = isLate ? const Color(0xFFF2545B) : textSub;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? accent : borderColor,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(dark ? 0.25 : 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header: stage + date (خلفية بدرجة لون الـ stage) ──
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        stage.withOpacity(dark ? 0.22 : 0.14),
                        stage.withOpacity(0.03),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (selecting) ...[
                        _SelectDot(selected: selected, dark: dark),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: stage,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: stage.withOpacity(0.5),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                lead.stageName.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: stage,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Icon(dateIcon, size: 14, color: dateColor),
                      const SizedBox(width: 4),
                      Text(
                        dateText,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: dateColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Avatar + name + project + type ──
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: stage.withOpacity(0.7),
                                width: 2,
                              ),
                            ),
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [AppColors.navy, AppColors.navyLight],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Text(
                                _initials,
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lead.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: textMain,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.apartment_rounded,
                                      size: 14,
                                      color: accent,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        lead.project,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                          color: dark
                                              ? AppColors.goldLight
                                              : AppColors.navy,
                                        ),
                                      ),
                                    ),
                                    if (lead.leadType.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.gold.withOpacity(
                                            0.18,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          lead.leadType.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                            color: dark
                                                ? AppColors.gold
                                                : const Color(0xFF8A6A00),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Salesman + Created (chips) ──
                      Row(
                        children: [
                          Expanded(
                            flex: 6,
                            child: _InfoChip(
                              icon: Icons.support_agent_rounded,
                              label: 'SALESMAN',
                              value: lead.salesman,
                              dark: dark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 5,
                            child: _InfoChip(
                              icon: Icons.event_available_rounded,
                              label: 'CREATED',
                              value: fmtLeadDate(lead.created),
                              dark: dark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Divider + phone + actions ──
                      Divider(height: 1, color: borderColor),
                      const SizedBox(height: 12),
                      LeadPhoneRow(
                        phone: lead.phone,
                        countryCode: lead.phoneCountryCode,
                        dark: dark,
                        lastComment: lead.lastComment,
                        onNoteTap: onNote,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool dark;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final accent = dark ? AppColors.gold : AppColors.navy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withOpacity(0.05) : AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: dark ? Colors.white54 : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value.isEmpty ? '—' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: dark ? AppColors.white : AppColors.textPrimary,
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

class _SelectDot extends StatelessWidget {
  final bool selected, dark;
  const _SelectDot({required this.selected, required this.dark});

  @override
  Widget build(BuildContext context) {
    final accent = dark ? AppColors.gold : AppColors.navy;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? accent : Colors.transparent,
        border: Border.all(
          color: selected
              ? accent
              : (dark ? Colors.white38 : AppColors.textSecondary),
          width: 1.6,
        ),
      ),
      child: selected
          ? Icon(
              Icons.check_rounded,
              size: 15,
              color: dark ? AppColors.navy : Colors.white,
            )
          : null,
    );
  }
}
