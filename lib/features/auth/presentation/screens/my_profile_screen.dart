// ignore_for_file: deprecated_member_use, unused_local_variable, unused_element_parameter

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/features/auth/data/models/my_sessions_model.dart';
import 'package:flutter_application_1/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_application_1/features/auth/providers/activity_log_service.dart';
import 'package:flutter_application_1/features/auth/providers/crm_settings.dart';
import 'package:flutter_application_1/features/auth/providers/my_sessions_provider.dart';

// ─────────────────────────────────────────────
//  My Profile: بيانات المستخدم اللي عامل لوجين
//  (اسم، صورة، إيميل، رقم، role) + زرار Log out
//
//  الاستخدام:
//  MyProfileScreen(
//    name: user.name, email: user.email, phone: user.phone,
//    role: user.role, photoUrl: user.photoUrl,
//  )
//  القيم الافتراضية تحت للديزاين بس.
// ─────────────────────────────────────────────
import 'package:provider/provider.dart';
import 'package:flutter_application_1/features/auth/providers/auth_provider.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 👈 بيانات اليوزر الحقيقية، والشاشة بتتحدث لو اتغيرت
    final auth = context.watch<AuthProvider>();
    final name = auth.name.isEmpty ? '—' : auth.name;
    final email = auth.email.isEmpty ? '—' : auth.email;
    final phone = auth.phone.isEmpty ? '—' : auth.phone;
    final role = auth.role ?? '—';
    final photoUrl = auth.photoUrl;

    final dark = Theme.of(context).brightness == Brightness.dark;
    // ... باقي الـ build زي ما هو بالظبط
    final top = MediaQuery.of(context).padding.top;

    final Color bg = dark ? const Color(0xFF121212) : AppColors.background;
    final Color card = dark ? const Color(0xFF1E1E1E) : AppColors.white;
    final Color border = dark ? Colors.white10 : AppColors.border;
    final Color textC = dark ? Colors.white : AppColors.textPrimary;
    final Color accent = dark ? AppColors.goldLight : AppColors.navy;

    return Scaffold(
      backgroundColor: bg,
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          // ── Header: gradient + avatar ──
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(16, top + 10, 16, 80),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: dark
                        ? [const Color(0xFF1A1F2E), AppColors.navy]
                        : [AppColors.navy, AppColors.navyLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                ),
                child: Row(
                  children: [
                    Material(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => Navigator.of(context).maybePop(),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: AppColors.goldLight,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'My Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Avatar بيطلع نص فوق الهيدر ونص تحته
              Positioned(
                left: 0,
                right: 0,
                bottom: -52,
                child: Center(
                  child: _Avatar(
                    name: name,
                    photoUrl: photoUrl,
                    ringColor: bg,
                    onEdit: () {},
                  ),
                ),
              ),
            ],
          ),

          // مسافة لنص الأفاتار اللي نازل تحت الهيدر
          const SizedBox(height: 64),

          // ── Name + role chip ──
          Center(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: textC,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                role,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // ── Info card ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(dark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _InfoTile(
                    icon: Icons.person_rounded,
                    label: 'Full Name',
                    value: name,
                  ),
                  Divider(height: 1, indent: 62, color: border),
                  _InfoTile(
                    icon: Icons.email_rounded,
                    label: 'Email',
                    value: email,
                  ),
                  Divider(height: 1, indent: 62, color: border),
                  _InfoTile(
                    icon: Icons.phone_rounded,
                    label: 'Phone',
                    value: phone,
                  ),
                  Divider(height: 1, indent: 62, color: border),
                  _InfoTile(
                    icon: Icons.verified_user_rounded,
                    label: 'Role',
                    value: role,
                    gold: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const _DevicesSection(),
          const SizedBox(height: 22),
          const _ActivitySection(), // 👈 جديد: activity اليوزر اللي عامل لوجين بس
          const SizedBox(height: 22),
          // ── Log out ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InkWell(
              onTap: () => _confirmLogout(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _danger.withOpacity(0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout_rounded, size: 20, color: _danger),
                    SizedBox(width: 8),
                    Text(
                      'Log out',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  static const Color _danger = Color(0xFFE5484D);

  // Dialog تأكيد قبل تسجيل الخروج
  Future<void> _confirmLogout(BuildContext context) async {
    final dark = Theme.of(context).brightness == Brightness.dark;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dark ? const Color(0xFF1E1E1E) : AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log out',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: dark ? Colors.white : AppColors.textPrimary,
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
              style: TextStyle(color: _danger, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    // نمسك كل حاجة قبل أي await عشان الـ context ممكن يتشال
    final auth = context.read<AuthProvider>();
    final crm = context.read<CrmSettingsProvider>();
    final nav = Navigator.of(context, rootNavigator: true);

    await auth.logout(); // token + user + (يفضل) FCM token
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    // بعد ما الـ shell يتشال، نمسح صلاحيات اليوزر القديم
    WidgetsBinding.instance.addPostFrameCallback((_) => crm.clear());
  }
}

// ─────────────────────────────────────────────
//  Avatar: صورة من النت، ولو مفيش أو فشلت يعرض أول حرف
// ─────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final Color ringColor;
  final VoidCallback onEdit;

  const _Avatar({
    required this.name,
    required this.photoUrl,
    required this.ringColor,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    // الـ fallback: أول حرف على خلفية نيفي
    final Widget fallback = Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navy, AppColors.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w800,
          color: AppColors.goldLight,
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 112,
          height: 112,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ringColor,
            border: Border.all(color: AppColors.gold, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: (photoUrl == null || photoUrl!.isEmpty)
                ? fallback
                : Image.network(
                    photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => fallback,
                    loadingBuilder: (_, child, progress) =>
                        progress == null ? child : fallback,
                  ),
          ),
        ),
        // زرار تعديل الصورة
        Positioned(
          right: 2,
          bottom: 2,
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 2.5),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 16,
                color: AppColors.navy,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Info tile
// ─────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool gold;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.gold = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = gold
        ? AppColors.gold
        : (dark ? AppColors.goldLight : AppColors.navy);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withOpacity(dark ? 0.15 : 0.09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600,
                    color: dark ? Colors.white54 : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: dark ? Colors.white : AppColors.textPrimary,
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

// ─────────────────────────────────────────────
//  My Devices: آخر الجلسات (sessions) بتاعة اليوزر
// ─────────────────────────────────────────────
IconData _platformIcon(String p) {
  switch (p) {
    case 'android':
      return Icons.android_rounded;
    case 'ios':
      return Icons.phone_iphone_rounded;
    case 'web':
      return Icons.language_rounded;
    case 'windows':
      return Icons.desktop_windows_rounded;
    default:
      return Icons.devices_other_rounded;
  }
}

class _DevicesSection extends StatefulWidget {
  /// null = أجهزتي أنا (/sessions/my)
  /// موجود = أجهزة اليوزر ده (/sessions/user/:id) للأدمن
  final String? userId;
  final String title;
  const _DevicesSection({this.userId, this.title = 'My Devices'});

  @override
  State<_DevicesSection> createState() => _DevicesSectionState();
}

class _DevicesSectionState extends State<_DevicesSection> {
  static const _platforms = ['android', 'ios', 'web', 'windows'];
  static const _limit = 5;

  final _svc = SessionsService();
  final _search = TextEditingController();
  Timer? _debounce;

  final List<DeviceSession> _items = [];
  SessionsFilter _filter = const SessionsFilter();
  int _page = 1;
  int _total = 0;
  bool _hasNext = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _reqId = 0; // عشان نتجاهل الردود القديمة

  Future<DeviceSessionsPage> _fetch(int page) => widget.userId == null
      ? _svc.getMySessions(page: page, limit: _limit, filter: _filter)
      : _svc.getUserSessions(
          widget.userId!,
          page: page,
          limit: _limit,
          filter: _filter,
        );

  // لو الأدمن بدّل اليوزر والـ widget نفسه فضل موجود
  @override
  void didUpdateWidget(covariant _DevicesSection old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId) {
      _search.clear();
      _filter = const SessionsFilter();
      _load();
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = ++_reqId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // final p = await _svc.getMySessions(
      //   page: 1,
      //   limit: _limit,
      //   filter: _filter,
      // );
      final p = await _fetch(1);
      if (!mounted || id != _reqId) return;
      setState(() {
        _items
          ..clear()
          ..addAll(p.items);
        _page = p.currentPage;
        _total = p.totalItems;
        _hasNext = p.hasNext;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasNext) return;
    final id = _reqId;
    setState(() => _loadingMore = true);
    try {
      final p = await _fetch(_page + 1);
      if (!mounted || id != _reqId) return;
      setState(() {
        _items.addAll(p.items);
        _page = p.currentPage;
        _hasNext = p.hasNext;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _applyFilter(SessionsFilter f) {
    _filter = f;
    _load();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _applyFilter(_filter.copyWith(keyword: v));
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = dark ? const Color(0xFF1E1E1E) : AppColors.white;
    final border = dark ? Colors.white10 : AppColors.border;
    final textC = dark ? Colors.white : AppColors.textPrimary;
    final sub = dark ? Colors.white54 : AppColors.textSecondary;
    final accent = dark ? AppColors.goldLight : AppColors.navy;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.devices_rounded, size: 18, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    //  'My Devices',
                    widget.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textC,
                    ),
                  ),
                ),
                if (!_loading && _error == null)
                  Text(
                    '$_total',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: sub,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Search
            TextField(
              controller: _search,
              onChanged: _onSearch,
              cursorColor: AppColors.gold,
              style: TextStyle(fontSize: 14, color: textC),
              decoration: InputDecoration(
                hintText: 'Search (e.g. chrome)',
                hintStyle: TextStyle(fontSize: 13.5, color: sub),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: accent),
                filled: true,
                fillColor: dark
                    ? const Color(0xFF262626)
                    : AppColors.background,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.gold,
                    width: 1.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Platform chips
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final p in _platforms)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          final s = {..._filter.platforms};
                          s.contains(p) ? s.remove(p) : s.add(p);
                          _applyFilter(_filter.copyWith(platforms: s));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _filter.platforms.contains(p)
                                ? AppColors.gold.withOpacity(0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _filter.platforms.contains(p)
                                  ? AppColors.gold
                                  : border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _platformIcon(p),
                                size: 15,
                                color: _filter.platforms.contains(p)
                                    ? accent
                                    : sub,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                p[0].toUpperCase() + p.substring(1),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: _filter.platforms.contains(p)
                                      ? accent
                                      : sub,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Body
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_error != null)
              Center(
                child: Column(
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFE5484D),
                        fontSize: 13,
                      ),
                    ),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              )
            else if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    _filter.isActive
                        ? 'No sessions match your filters'
                        : 'No devices yet',
                    style: TextStyle(color: sub, fontWeight: FontWeight.w600),
                  ),
                ),
              )
            else ...[
              for (int i = 0; i < _items.length; i++) ...[
                _DeviceTile(
                  s: _items[i],
                  isLatest: i == 0 && !_filter.isActive,
                  border: border,
                  textC: textC,
                  sub: sub,
                  accent: accent,
                  dark: dark,
                ),
                if (i != _items.length - 1) const SizedBox(height: 8),
              ],
              if (_hasNext) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton(
                    onPressed: _loadingMore ? null : _loadMore,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: const BorderSide(color: AppColors.gold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _loadingMore
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Show more',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final DeviceSession s;
  final bool isLatest;
  final Color border, textC, sub, accent;
  final bool dark;

  const _DeviceTile({
    required this.s,
    required this.isLatest,
    required this.border,
    required this.textC,
    required this.sub,
    required this.accent,
    required this.dark,
  });

  String _ago(DateTime? d) {
    if (d == null) return '—';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final loc = s.locationText;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF262626) : AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity(dark ? 0.15 : 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_platformIcon(s.platform), size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        s.prettyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: textC,
                        ),
                      ),
                    ),
                    if (isLatest) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Latest',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    s.platform.toUpperCase(),
                    if (s.ip.isNotEmpty) s.ip,
                  ].join('  •  '),
                  style: TextStyle(fontSize: 11.5, color: sub),
                ),
                if (loc != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 12, color: sub),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          loc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: sub),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _ago(s.lastLoginAt),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: sub,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  My Activity: آخر عمليات اليوزر الحالي بس
//  بينادي /profile/activity (isAdmin: false) فمش بيجيب لوجز حد تاني
//  حتى لو اليوزر Admin، لأن ده بروفايله هو
// ─────────────────────────────────────────────
class _ActivitySection extends StatefulWidget {
  const _ActivitySection();

  @override
  State<_ActivitySection> createState() => _ActivitySectionState();
}

class _ActivitySectionState extends State<_ActivitySection> {
  static const _limit = 5;

  final _svc = MyActivityService();
  final List<MyActivityItem> _items = [];
  String? _nextBefore; // cursor للصفحة اللي بعدها
  bool _hasNext = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _svc.fetch(limit: _limit);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(p.items);
        _nextBefore = p.nextBefore;
        _hasNext = p.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasNext) return;
    setState(() => _loadingMore = true);
    try {
      final p = await _svc.fetch(limit: _limit, before: _nextBefore);
      if (!mounted) return;
      setState(() {
        _items.addAll(p.items);
        _nextBefore = p.nextBefore;
        _hasNext = p.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  // أيقونة حسب نوع العملية
  IconData _icon(String a) {
    switch (a) {
      case 'create':
        return Icons.add_circle_outline_rounded;
      case 'delete':
        return Icons.delete_outline_rounded;
      case 'assign':
        return Icons.person_add_alt_rounded;
      case 'change_stage':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.edit_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = dark ? const Color(0xFF1E1E1E) : AppColors.white;
    final border = dark ? Colors.white10 : AppColors.border;
    final textC = dark ? Colors.white : AppColors.textPrimary;
    final sub = dark ? Colors.white54 : AppColors.textSecondary;
    final accent = dark ? AppColors.goldLight : AppColors.navy;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.history_rounded, size: 18, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'My Activity',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textC,
                    ),
                  ),
                ),
                // زرار refresh
                InkWell(
                  onTap: _loading ? null : _load,
                  child: Icon(Icons.refresh_rounded, size: 20, color: sub),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Body
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_error != null)
              Center(
                child: Column(
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFE5484D),
                        fontSize: 13,
                      ),
                    ),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              )
            else if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No activity yet',
                    style: TextStyle(color: sub, fontWeight: FontWeight.w600),
                  ),
                ),
              )
            else ...[
              for (int i = 0; i < _items.length; i++) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xFF262626)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(dark ? 0.15 : 0.09),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          _icon(_items[i].type), // ← كان _items[i].action
                          size: 19,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _items[i].summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: textC,
                              ),
                            ),
                            const SizedBox(height: 3),
                            // التاريخ بنظام AM/PM
                            Text(
                              _items[i].timeText,
                              style: TextStyle(fontSize: 11.5, color: sub),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (i != _items.length - 1) const SizedBox(height: 8),
              ],
              if (_hasNext) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton(
                    onPressed: _loadingMore ? null : _loadMore,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: const BorderSide(color: AppColors.gold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _loadingMore
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Show more',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
