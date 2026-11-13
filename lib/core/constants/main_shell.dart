import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:flutter_application_1/features/admin/presentation/screens/admin_leads_screen.dart';
import 'package:flutter_application_1/features/admin/presentation/screens/admin_profile_screen.dart';
import 'package:flutter_application_1/features/auth/presentation/screens/my_profile_screen.dart';
import 'package:flutter_application_1/features/auth/providers/auth_provider.dart';
import 'package:flutter_application_1/features/auth/providers/crm_settings.dart';
import 'package:flutter_application_1/features/chat/presentation/screens/admin_ai_chat_screen.dart';
import 'package:flutter_application_1/features/leads/presentation/screens/create_leads_screen.dart';
import 'package:flutter_application_1/features/leads/providers/admin_leads_filter_service.dart';
import 'package:flutter_application_1/features/sales/presentation/sales_dashboard_screen.dart';
import 'package:flutter_application_1/features/sales/presentation/sales_leads_screen.dart';
import 'package:flutter_application_1/features/sales/provider/sales_dashboard_provider.dart';
import 'package:flutter_application_1/features/team%20leader/presentation/screens/teamleader_leads_screen.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────
//  1) الـ Roles
// ─────────────────────────────────────────────
enum UserRole { admin, manager, teamLeader, sales, marketer }

UserRole? userRoleFromString(String? role) {
  // نشيل المسافات والشرطات عشان "Team Leader" و "team_leader" يبقوا زي بعض
  switch (role?.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '')) {
    case 'admin':
      return UserRole.admin;
    case 'manager':
      return UserRole.manager;
    case 'teamleader':
      return UserRole.teamLeader;
    case 'sales':
      return UserRole.sales;
    case 'marketer':
      return UserRole.marketer;
    default:
      return null;
  }
}

// ─────────────────────────────────────────────
//  2) تعريف التاب + إعدادات كل Role
// ─────────────────────────────────────────────
class NavTab {
  final String label;
  final IconData icon, activeIcon;
  final WidgetBuilder root;
  final bool refreshOnEnter; // true = يتبني من جديد كل ما تدخله

  const NavTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.root,
    this.refreshOnEnter = true,
  });
}

class RoleNavConfig {
  final List<NavTab> tabs;
  final bool canAddLead; // زرار الـ + اللي في نص الـ bar
  const RoleNavConfig({required this.tabs, this.canAddLead = true});
}

// تابات مشتركة (بدل التكرار)
const _kAiChatLabel = 'AI Chat'; // لازم يطابق الفلتر تحت

NavTab _profileTab(WidgetBuilder root) => NavTab(
  label: 'Profile',
  icon: Icons.person_outline_rounded,
  activeIcon: Icons.person_rounded,
  root: root,
);

NavTab get _aiChatTab => NavTab(
  label: _kAiChatLabel,
  icon: Icons.message_outlined,
  activeIcon: Icons.message_rounded,
  refreshOnEnter: false, // المحادثة تفضل زي ما هي
  root: (_) => const AiChatScreen(),
);

NavTab _tab(
  String label,
  IconData icon,
  IconData activeIcon,
  WidgetBuilder root,
) => NavTab(label: label, icon: icon, activeIcon: activeIcon, root: root);

Widget _page(String title, IconData icon) =>
    _PlaceholderPage(title: title, icon: icon);

/// بتفلتر التابات حسب صلاحيات الـ CRM
RoleNavConfig navConfigFor(UserRole role, CrmSettingsProvider crm) {
  final base = _baseNavConfig(role);
  final tabs = base.tabs
      .where((t) => t.label != _kAiChatLabel || crm.canUseAiChat)
      .toList();
  return RoleNavConfig(tabs: tabs, canAddLead: base.canAddLead);
}

RoleNavConfig _baseNavConfig(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return RoleNavConfig(
        tabs: [
          _tab(
            'Dashboard',
            Icons.space_dashboard_outlined,
            Icons.space_dashboard_rounded,
            (_) => const AdminDashboardScreen(),
          ),
          _tab(
            'Leads',
            Icons.groups_outlined,
            Icons.groups_rounded,
            (_) => const LeadsScreen(),
          ),
          _aiChatTab,
          _profileTab((_) => AdminProfileScreen()),
        ],
      );

    case UserRole.manager:
      return RoleNavConfig(
        tabs: [
          _tab(
            'Dashboard',
            Icons.space_dashboard_outlined,
            Icons.space_dashboard_rounded,
            (_) => _page('Manager Dashboard', Icons.space_dashboard_rounded),
          ),
          _tab(
            'Leads',
            Icons.groups_outlined,
            Icons.groups_rounded,
            (_) => _page('Leads', Icons.groups_rounded),
          ),
          _tab(
            'Team',
            Icons.diversity_3_outlined,
            Icons.diversity_3_rounded,
            (_) => _page('Team', Icons.diversity_3_rounded),
          ),
          _profileTab((_) => const MyProfileScreen()),
        ],
      );

    case UserRole.teamLeader:
      return RoleNavConfig(
        tabs: [
          _tab(
            'Home',
            Icons.home_outlined,
            Icons.home_rounded,
            // refreshOnEnter = true → provider جديد + load جديد كل دخول
            (ctx) => ChangeNotifierProvider(
              create: (_) => SalesDashboardProvider(
                ctx.read<AuthProvider>().userId ?? '',
                isTeam: true,
              )..load(),
              child: const SalesDashboardScreen(),
            ),
          ),
          _tab('Leads', Icons.contacts_outlined, Icons.contacts_rounded, (ctx) {
            final uid = ctx.read<AuthProvider>().userId ?? '';
            return TeamLeaderLeadsScreen(userId: uid);
          }),
          _aiChatTab,
          _profileTab((_) => const MyProfileScreen()),
        ],
      );

    case UserRole.sales:
      // نفس تابات السيلز

      return RoleNavConfig(
        tabs: [
          _tab(
            'Home',
            Icons.home_outlined,
            Icons.home_rounded,
            // refreshOnEnter = true → provider جديد + load جديد كل دخول
            (ctx) => ChangeNotifierProvider(
              create: (_) =>
                  SalesDashboardProvider(ctx.read<AuthProvider>().userId ?? '')
                    ..load(),
              child: const SalesDashboardScreen(),
            ),
          ),
          _tab('My Leads', Icons.contacts_outlined, Icons.contacts_rounded, (
            ctx,
          ) {
            final salesId = ctx.read<AuthProvider>().userId ?? '';
            return SalesLeadsScreen(preset: LeadsFilters(sales: [salesId]));
          }),
          _aiChatTab,
          _profileTab((_) => const MyProfileScreen()),
        ],
      );

    case UserRole.marketer:
      return RoleNavConfig(
        canAddLead: false,
        tabs: [
          _tab(
            'Home',
            Icons.home_outlined,
            Icons.home_rounded,
            (_) => _page('Marketer Home', Icons.home_rounded),
          ),
          _tab(
            'Campaigns',
            Icons.campaign_outlined,
            Icons.campaign_rounded,
            (_) => _page('Campaigns', Icons.campaign_rounded),
          ),
          _tab(
            'Leads',
            Icons.groups_outlined,
            Icons.groups_rounded,
            (_) => _page('Leads', Icons.groups_rounded),
          ),
          _profileTab((_) => const MyProfileScreen()),
        ],
      );
  }
}

// ─────────────────────────────────────────────
//  3) Shell Provider: index + Navigator لكل تاب
// ─────────────────────────────────────────────
class ShellProvider extends ChangeNotifier {
  final int tabCount;
  final List<bool> _fresh;
  final Set<int> _visited = {0}; // التابات اللي اتفتحت (lazy build)
  final Map<int, WidgetBuilder> _pending = {}; // root مؤقت (من openLeads)
  int index = 0;

  late final List<GlobalKey<NavigatorState>> navKeys = List.generate(
    tabCount,
    (_) => GlobalKey<NavigatorState>(),
  );

  ShellProvider(this.tabCount, {List<bool>? fresh})
    : _fresh = fresh ?? List.filled(tabCount, true);

  bool isVisited(int i) => _visited.contains(i);

  /// بتتنادى مرة واحدة من الـ Navigator وهو بيتبني
  WidgetBuilder? takePending(int i) => _pending.remove(i);

  void setIndex(int i) {
    if (i == index) {
      // دوسة تانية على نفس التاب = ارجع لأول صفحة فيه
      navKeys[i].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    _enter(i, rebuild: _fresh[i]);
  }

  /// يفتح تاب الـ Leads بفلتر جاهز (من الداشبورد مثلاً)
  void openLeads(
    LeadsFilters preset, {
    int leadsIndex = 1,
    Widget Function(LeadsFilters preset)? builder,
  }) {
    _pending[leadsIndex] = (_) =>
        builder?.call(preset) ?? LeadsScreen(preset: preset);
    _enter(leadsIndex, rebuild: true); // Navigator جديد بالـ preset
  }

  void _enter(int i, {required bool rebuild}) {
    if (rebuild) navKeys[i] = GlobalKey<NavigatorState>();
    _visited.add(i);
    index = i;
    notifyListeners();
  }
}

// ─────────────────────────────────────────────
//  4) Main Shell
// ─────────────────────────────────────────────
class MainShell extends StatefulWidget {
  final UserRole role;
  const MainShell({super.key, required this.role});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final crm = context.read<CrmSettingsProvider>();
      if (!crm.isLoaded && !crm.isLoading) crm.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.watch<CrmSettingsProvider>();

    if (!crm.isLoaded) {
      return Scaffold(
        body: Center(
          child: crm.error != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(crm.error!, textAlign: TextAlign.center),
                    ),
                    TextButton(onPressed: crm.load, child: const Text('Retry')),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

    final config = navConfigFor(widget.role, crm);
    if (kDebugMode) {
      debugPrint(
        'role=${widget.role} aiChat=${crm.canUseAiChat} '
        'tabs=${config.tabs.map((t) => t.label)}',
      );
    }

    return ChangeNotifierProvider(
      key: ValueKey('${widget.role}-${config.tabs.length}'),
      create: (_) => ShellProvider(
        config.tabs.length,
        fresh: [for (final t in config.tabs) t.refreshOnEnter],
      ),
      child: _ShellView(config: config, role: widget.role),
    );
  }
}

class _ShellView extends StatelessWidget {
  final RoleNavConfig config;
  final UserRole role;
  const _ShellView({required this.config, required this.role});

  Future<void> _addLead(BuildContext context, ShellProvider shell) async {
    final uid = context.read<AuthProvider>().userId;
    await shell.navKeys[shell.index].currentState?.push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateLeadScreen(
          isAdmin: role == UserRole.admin || role == UserRole.manager,
          fixedSalesId: role == UserRole.sales ? uid : null,
          teamLeaderId: role == UserRole.teamLeader ? uid : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellProvider>();

    // Back: يرجع جوه التاب → للتاب الأول → يقفل التطبيق
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = shell.navKeys[shell.index].currentState;
        if (nav != null && await nav.maybePop()) return;
        if (shell.index != 0) {
          shell.setIndex(0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        // IndexedStack + lazy: التاب ما يتبنيش إلا لما تفتحه أول مرة
        body: IndexedStack(
          index: shell.index,
          children: [
            for (int i = 0; i < config.tabs.length; i++)
              shell.isVisited(i)
                  ? Navigator(
                      key: shell.navKeys[i],
                      onGenerateRoute: (_) => MaterialPageRoute(
                        builder: shell.takePending(i) ?? config.tabs[i].root,
                      ),
                    )
                  : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: _FloatingNavBar(
          tabs: config.tabs,
          currentIndex: shell.index,
          onTap: shell.setIndex,
          showAdd: config.canAddLead,
          onAdd: () => _addLead(context, shell),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  5) الـ Nav Bar (Floating + Animated)
// ─────────────────────────────────────────────
class _FloatingNavBar extends StatelessWidget {
  final List<NavTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showAdd;
  final VoidCallback onAdd;

  const _FloatingNavBar({
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
    required this.showAdd,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mid = tabs.length ~/ 2;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: dark ? AppColors.navyLight : AppColors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: dark
                ? AppColors.goldLight.withOpacity(0.18)
                : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.35 : 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (int i = 0; i < tabs.length; i++) ...[
              if (showAdd && i == mid) _AddButton(onTap: onAdd),
              Expanded(
                child: _NavItem(
                  tab: tabs[i],
                  selected: i == currentIndex,
                  dark: dark,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTap(i);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final NavTab tab;
  final bool selected, dark;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = dark ? Colors.white60 : AppColors.textSecondary;
    final activeLabel = dark ? AppColors.gold : AppColors.navy;

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.gold.withOpacity(0.12),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                width: selected ? 54 : 40,
                height: 32,
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [AppColors.navy, AppColors.navyLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.navy.withOpacity(0.30),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    selected ? tab.activeIcon : tab.icon,
                    key: ValueKey(selected),
                    size: 22,
                    color: selected ? AppColors.gold : inactive,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? activeLabel : inactive,
                ),
                child: Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Semantics(
        button: true,
        label: 'Add lead',
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.navy, AppColors.navyLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppColors.gold, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.add_rounded,
              size: 28,
              color: AppColors.gold,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Placeholder للصفحات اللي لسه معملتهاش
// ─────────────────────────────────────────────
class _PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;
  const _PlaceholderPage({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? AppColors.navy : AppColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: dark ? AppColors.navyLight : AppColors.white,
        foregroundColor: dark ? AppColors.goldLight : AppColors.navy,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.gold),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: dark ? AppColors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _PlaceholderPage(
                    title: '$title details',
                    icon: Icons.info_outline,
                  ),
                ),
              ),
              child: const Text('Open sub page'),
            ),
          ],
        ),
      ),
    );
  }
}
