// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/features/leads/presentation/screens/lead_details_screen_master.dart';
import 'package:flutter_application_1/features/notifications/provider/notifications_provider.dart';
import 'package:provider/provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NotificationsFeedProvider()
        ..load()
        ..markSeen(),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatefulWidget {
  const _NotificationsView();

  @override
  State<_NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<_NotificationsView> {
  final _scroll = ScrollController();
  static const _filters = ['All', 'Unread'];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      if (_scroll.position.maxScrollExtent - _scroll.position.pixels < 300) {
        context.read<NotificationsFeedProvider>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ── Helpers ──
  String _group(DateTime d) {
    final now = DateTime.now();
    final t = DateTime(now.year, now.month, now.day);
    final x = DateTime(d.year, d.month, d.day);
    final diff = t.difference(x).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return 'Earlier';
  }

  String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(m), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _open(BellNotification n) async {
    final p = context.read<NotificationsFeedProvider>();
    p.markRead(n);
    if (n.leadId == null) return;
    if (!n.canOpen) {
      _toast('You no longer have access to this lead');
      return;
    }
    final r = await p.checkAccess(n);
    if (!mounted) return;
    if (!r.ok || r.leadId == null) {
      _toast(r.reason ?? 'You cannot open this lead');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeadDetailsScreen(
          leadId: r.leadId!,
          config: LeadDetailsConfig.admin, // 👈 عدّلها حسب الرول
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<NotificationsFeedProvider>();

    final groups = <String>[];
    for (final n in p.items) {
      final g = _group(n.createdAt);
      if (!groups.contains(g)) groups.add(g);
    }

    Widget body;
    if (p.loading && p.items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (p.error != null && p.items.isEmpty) {
      body = _buildError(p);
    } else if (p.items.isEmpty) {
      body = RefreshIndicator(
        onRefresh: p.load,
        child: ListView(children: [SizedBox(height: 80), _buildEmptyState()]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: p.load,
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            for (final g in groups) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
                child: Text(
                  g,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              for (final n in p.items.where((e) => _group(e.createdAt) == g))
                _buildTile(p, n),
            ],
            if (p.loadingMore)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context, p),
          Expanded(child: body),
        ],
      ),
    );
  }

  // ───────────────── Header ─────────────────
  Widget _buildHeader(BuildContext context, NotificationsFeedProvider p) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.navyLight],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: AppColors.white,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.white.withOpacity(0.12),
                    ),
                  ),
                  const Spacer(),
                  if (p.mineUnread > 0)
                    TextButton.icon(
                      onPressed: p.markAllRead,
                      icon: const Icon(
                        Icons.done_all_rounded,
                        size: 18,
                        color: AppColors.goldLight,
                      ),
                      label: const Text(
                        'Mark all as read',
                        style: TextStyle(
                          color: AppColors.goldLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (p.mineUnread > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${p.mineUnread} new',
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if ((p.scope ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Text(
                    p.scope!,
                    style: TextStyle(
                      color: AppColors.goldLight.withOpacity(0.9),
                      fontSize: 12.5,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  children: List.generate(_filters.length, (i) {
                    final selected = (i == 1) == p.unreadOnly;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => p.setUnreadOnly(i == 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.gold
                                : AppColors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _filters[i],
                            style: TextStyle(
                              color: selected
                                  ? AppColors.navy
                                  : AppColors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────── Tile ─────────────────
  Widget _buildTile(NotificationsFeedProvider p, BellNotification n) {
    final style = _typeStyle(n.type);
    final unread = n.mine && !n.read;

    final tile = GestureDetector(
      onTap: () => _open(n),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: unread ? AppColors.gold.withOpacity(0.55) : AppColors.border,
            width: unread ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withOpacity(unread ? 0.07 : 0.02),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: style.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(style.icon, color: style.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: const BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  if (n.forName != null && n.forName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'For ${n.forName}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _ago(n.createdAt),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      if (n.count > 1) ...[
                        const SizedBox(width: 10),
                        Text(
                          '×${n.count}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
      ),
    );

    // المسح بيشتغل على إشعاراتك إنت بس (الباقي 404)
    if (!n.mine) return tile;

    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => p.remove(n),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.white,
          size: 26,
        ),
      ),
      child: tile,
    );
  }

  Widget _buildError(NotificationsFeedProvider p) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              p.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFE5484D)),
            ),
            TextButton(onPressed: p.load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.navy.withOpacity(0.06),
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                size: 52,
                color: AppColors.navyLight,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              "You're all caught up",
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No notifications to show right now.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _TypeStyle _typeStyle(String type) {
    switch (type) {
      case 'lead_created':
      case 'lead_created_by_me':
        return const _TypeStyle(
          Icons.person_add_alt_1_rounded,
          Color(0xFF2F9E6E),
        );
      case 'lead_assigned':
      case 'lead_assigned_by_me':
        return const _TypeStyle(
          Icons.assignment_ind_rounded,
          Color(0xFF3B82F6),
        );
      case 'lead_comment':
      case 'comment_by_me':
        return const _TypeStyle(Icons.chat_bubble_rounded, AppColors.gold);
      case 'lead_reply':
      case 'reply_by_me':
        return const _TypeStyle(Icons.reply_rounded, Color(0xFF8B5CF6));
      default:
        return const _TypeStyle(
          Icons.notifications_rounded,
          AppColors.navyLight,
        );
    }
  }
}

class _TypeStyle {
  final IconData icon;
  final Color color;
  const _TypeStyle(this.icon, this.color);
}
