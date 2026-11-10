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
    final baseSurface = dark ? AppColors.navyLight : AppColors.white;
    final accent = dark ? AppColors.gold : AppColors.navy;
    final surface = selected
        ? Color.alphaBlend(accent.withOpacity(0.09), baseSurface)
        : baseSurface;
    final textMain = dark ? AppColors.white : AppColors.textPrimary;
    final textSub = dark ? Colors.white60 : AppColors.textSecondary;
    // معاد المتابعة (بيتمسح من السيرفر لما الـ stage نهائية → نرجع لتاريخ الـ stage)
    final followUp = lead.nextFollowUpAt;
    final isLate = followUp != null && followUp.isBefore(DateTime.now());
    final dateText = fmtLeadDate(followUp ?? lead.stageDate);
    final dateIcon = followUp != null
        ? Icons.alarm_rounded
        : Icons.schedule_rounded;
    final dateColor = isLate ? const Color(0xFFF2545B) : textSub;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(dark ? 0.25 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: stage),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: stage + date
                        Row(
                          children: [
                            if (selecting) ...[
                              _SelectDot(selected: selected, dark: dark),
                              const SizedBox(width: 10),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: stage.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: stage,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        lead.stageName.toUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: stage,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Spacer(),
                            Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: textSub,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dateText,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: textSub,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Row 2: avatar + name + project + type
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.navy, AppColors.navyLight],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _initials,
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
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
                                            letterSpacing: 0.4,
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
                                            horizontal: 6,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.gold.withOpacity(
                                              0.18,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            lead.leadType.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
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

                        // Row 3: salesman + created
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: dark
                                ? Colors.white.withOpacity(0.05)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _InfoTile(
                                  icon: Icons.support_agent_rounded,
                                  label: 'SALESMAN',
                                  value: lead.salesman,
                                  dark: dark,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 32,
                                color: dark
                                    ? Colors.white.withOpacity(0.1)
                                    : AppColors.border,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _InfoTile(
                                  icon: Icons.event_available_rounded,
                                  label: 'CREATED',
                                  value: fmtLeadDate(lead.created),
                                  dark: dark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Row 4: phone + actions
                        LeadPhoneRow(
                          phone: lead.phone,
                          countryCode: lead.phoneCountryCode,
                          dark: dark,
                          lastComment: lead.lastComment,
                          onNoteTap:
                              onNote, // ✅ لو الشاشة بعتت onNote يتنفذ، وإلا بيفتح شيت آخر كومنت
                        ),
                        // Row(
                        //   children: [
                        //     Expanded(
                        //       child: Text(
                        //         lead.fullPhone,
                        //         maxLines: 1,
                        //         overflow: TextOverflow.ellipsis,
                        //         style: TextStyle(
                        //           fontSize: 16,
                        //           fontWeight: FontWeight.w800,
                        //           letterSpacing: 0.4,
                        //           color: textMain,
                        //         ),
                        //       ),
                        //     ),
                        //     _ActionBtn(
                        //       icon: Icons.call_rounded,
                        //       color: accent,
                        //       onTap: onCall ?? () => _open('tel:${lead.fullPhone}'),
                        //     ),
                        //     const SizedBox(width: 8),
                        //     _ActionBtn(
                        //       icon: Icons.chat_rounded,
                        //       color: const Color(0xFF16A34A),
                        //       onTap: onWhatsApp ?? () => _open('https://wa.me/$digits'),
                        //     ),
                        //     const SizedBox(width: 8),
                        //     _ActionBtn(
                        //       icon: Icons.sticky_note_2_rounded,
                        //       color: dark ? AppColors.goldLight : AppColors.navyLight,
                        //       onTap: onNote,
                        //     ),
                        //   ],
                        // ),
                      ],
                    ),
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

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool dark;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: dark ? AppColors.gold : AppColors.navy),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: dark ? Colors.white54 : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
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
