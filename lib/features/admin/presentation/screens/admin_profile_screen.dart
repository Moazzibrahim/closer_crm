// ignore_for_file: deprecated_member_use, unused_element_parameter

import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/features/Reshuffle/presentation/screens/reshuffle_rules_screen.dart';
import 'package:flutter_application_1/features/auth/presentation/screens/activity_log_screen.dart';
import 'package:flutter_application_1/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_application_1/features/auth/providers/auth_provider.dart';
import 'package:flutter_application_1/features/crud/presentation/all_users_screen.dart';
import 'package:flutter_application_1/features/crud/presentation/area_screen.dart';
import 'package:flutter_application_1/features/crud/presentation/campaign_screen.dart';
import 'package:flutter_application_1/features/crud/presentation/cancel_reason_screen.dart';
import 'package:flutter_application_1/features/crud/presentation/channels_screen.dart';
import 'package:flutter_application_1/features/crud/presentation/cities_screen.dart';
import 'package:flutter_application_1/features/crud/presentation/commWay_screen.dart';
import 'package:flutter_application_1/features/crud/presentation/developers_screen.dart';
import 'package:flutter_application_1/features/crud/presentation/projects_screen.dart';
import 'package:flutter_application_1/features/crud/presentation/property_type_screen.dart';
import 'package:flutter_application_1/features/crud/presentation/regions_screen.dart';
import 'package:flutter_application_1/features/crud/presentation/stage_type_screen.dart';
import 'package:flutter_application_1/features/crud/presentation/stages_screen.dart';
import 'package:flutter_application_1/features/sessions/presentation/sessions_screen.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/screens/my_profile_screen.dart';

// ─────────────────────────────────────────────
//  Profile / Settings screen
//  - Header card (avatar, name, role)
//  - Grouped menu: each row opens its own page
//  - Log out button at the bottom
// ─────────────────────────────────────────────

// عنصر واحد في المنيو
class _MenuItem {
  final String title;
  final IconData icon;
  final bool danger; // true = لون أحمر (للـ Trash مثلاً)

  // الصفحة اللي هتفتح. لو null بتفتح صفحة placeholder بنفس الاسم.
  // لما تعمل الصفحة الحقيقية: page: (_) => const CitiesScreen(),
  final WidgetBuilder? page;

  const _MenuItem(this.title, this.icon, {this.danger = false, this.page});
}

class _MenuGroup {
  final String title;
  final List<_MenuItem> items;
  const _MenuGroup(this.title, this.items);
}

// ✏️ عدّل هنا لتغيير الأقسام أو الأيقونات أو الصفحات
List<_MenuGroup> _groups = [
  _MenuGroup('Account', [
    _MenuItem('Profile', Icons.person_rounded, page: (_) => MyProfileScreen()),
    _MenuItem(
      'Activity',
      Icons.history_rounded,
      page: (_) => const ActivityScreen(),
    ),
    _MenuItem(
      'Communication Way',
      Icons.forum_rounded,
      page: (_) => const CommunicationWaysScreen(),
    ),
  ]),
  _MenuGroup('Team', [
    _MenuItem(
      'Users',
      Icons.manage_accounts_rounded,
      page: (_) => UsersScreen(),
    ),
    _MenuItem(
      'Sessions',
      Icons.devices_rounded,
      page: (_) => const SessionsScreen(),
    ), // 👈 جديد
  ]),
  _MenuGroup('Automation', [
    _MenuItem(
      'Reshuffle Rules',
      Icons.shuffle_rounded,
      page: (_) => const ReshuffleRulesScreen(),
    ),
  ]),
  _MenuGroup('CRM Setup', [
    _MenuItem(
      'Stages',
      Icons.stacked_line_chart_rounded,
      page: (_) => const StagesScreen(),
    ),
    _MenuItem(
      'Stage Types',
      Icons.type_specimen,
      page: (_) => const StageTypesScreen(),
    ),
    _MenuItem(
      'Developers',
      Icons.apartment_rounded,
      page: (_) => DevelopersScreen(),
    ),
    _MenuItem('Projects', Icons.domain_rounded, page: (_) => ProjectsScreen()),
    _MenuItem(
      'Property Types',
      Icons.apartment,
      page: (_) => const PropertyTypesScreen(),
    ),
    _MenuItem('Channels', Icons.hub_rounded, page: (_) => ChannelsScreen()),
    _MenuItem(
      'Cancel Reasons',
      Icons.event_busy_rounded,
      page: (_) => const CancelReasonsScreen(),
    ),
    _MenuItem(
      'Campaigns',
      Icons.campaign_rounded,
      page: (_) => const CampaignsScreen(),
    ),
  ]),
  _MenuGroup('Locations', [
    _MenuItem(
      'Cities',
      Icons.location_city_rounded,
      page: (_) => CitiesScreen(),
    ),
    _MenuItem('Regions', Icons.map_rounded, page: (_) => const RegionsScreen()),
    _MenuItem('Areas', Icons.place_rounded, page: (_) => const AreasScreen()),
  ]),
  // _MenuGroup('Other', [
  //   _MenuItem('Trash', Icons.delete_outline_rounded, danger: true),
  // ]),
];

// ─────────────────────────────────────────────
//  Main Screen
// ─────────────────────────────────────────────
class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.background,
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          const _Header(),
          const SizedBox(height: 8),

          // Groups
          for (final g in _groups) _GroupCard(group: g),

          const SizedBox(height: 8),

          // Log out
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _LogoutButton(onTap: () => _confirmLogout(context)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Dialog تأكيد قبل تسجيل الخروج
  Future<void> _confirmLogout(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log out',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Log out',
              style: TextStyle(
                color: Color(0xFFE5484D),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    // يمسح الـ token والـ role واليوزر المحفوظين
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}

// ─────────────────────────────────────────────
//  Header: gradient + user card
// ─────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final top = MediaQuery.of(context).padding.top;

    // بيانات اليوزر الحقيقية (بتتحدث لو اتغيرت)
    final auth = context.watch<AuthProvider>();
    final name = auth.name.isEmpty ? '—' : auth.name;
    final email = auth.email.isEmpty ? '—' : auth.email;
    final role = auth.role ?? '—';
    final photoUrl = auth.photoUrl;
    final initial = auth.name.trim().isEmpty
        ? '?'
        : auth.name.trim()[0].toUpperCase();

    // الـ fallback: أول حرف من الاسم
    final Widget initialBox = Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.goldLight,
        ),
      ),
    );

    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 16, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A1F2E), AppColors.navy]
              : [AppColors.navy, AppColors.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Avatar: صورة اليوزر، ولو مفيش/فشلت يعرض أول حرف
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.gold, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: (photoUrl == null)
                      ? initialBox
                      : Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => initialBox,
                          loadingBuilder: (_, child, progress) =>
                              progress == null ? child : initialBox,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Role chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Group card (title + rows with dividers)
// ─────────────────────────────────────────────
class _GroupCard extends StatelessWidget {
  final _MenuGroup group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group title
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              group.title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white10 : AppColors.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            // ClipRRect عشان الـ ripple ما يخرجش برا الحواف
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                children: [
                  for (int i = 0; i < group.items.length; i++) ...[
                    _MenuRow(item: group.items[i]),
                    if (i != group.items.length - 1)
                      Divider(
                        height: 1,
                        indent: 64,
                        color: isDark ? Colors.white10 : AppColors.border,
                      ),
                  ],
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
//  Single menu row → opens its own page
// ─────────────────────────────────────────────
class _MenuRow extends StatelessWidget {
  final _MenuItem item;
  const _MenuRow({required this.item});

  static const Color _danger = Color(0xFFE5484D);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color accent = item.danger
        ? _danger
        : (isDark ? AppColors.goldLight : AppColors.navy);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Navigator.of(context) = Navigator بتاع التاب → الـ nav bar يفضل ظاهر
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  item.page ??
                  (_) => _SectionPage(title: item.title, icon: item.icon),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Icon box
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withOpacity(isDark ? 0.15 : 0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(item.icon, size: 20, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: item.danger
                        ? _danger
                        : (isDark ? Colors.white : AppColors.textPrimary),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Log out button
// ─────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const danger = Color(0xFFE5484D);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: danger.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: danger.withOpacity(0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.logout_rounded, size: 20, color: danger),
            SizedBox(width: 8),
            Text(
              'Log out',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Placeholder page (بدّلها بالصفحة الحقيقية لكل قسم)
// ─────────────────────────────────────────────
class _SectionPage extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionPage({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.background,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: false,
        backgroundColor: isDark ? const Color(0xFF121212) : AppColors.white,
        foregroundColor: isDark ? AppColors.goldLight : AppColors.navy,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.gold),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Coming soon',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
