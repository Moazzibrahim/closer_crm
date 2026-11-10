// users_screen.dart
// ignore_for_file: deprecated_member_use, unnecessary_null_comparison, unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/core/constants/api_constants.dart';
import 'package:flutter_application_1/features/auth/presentation/widgets/change_password_widget.dart';
import 'package:flutter_application_1/features/auth/providers/auth_service.dart';
import 'package:flutter_application_1/features/crud/data/channels_model.dart';
import 'package:flutter_application_1/features/crud/data/users_model.dart';
import 'package:flutter_application_1/features/crud/providers/crud_service.dart';

const _danger = Color(0xFFE5484D);
const _roles = ['Admin', 'Manager', 'Team Leader', 'Sales', 'Marketer'];

// الحساب الأساسي: ممنوع Deactivate عليه
const _protectedEmail = 'admin@closer.com';
bool _isProtected(UserModel u) => u.email == _protectedEmail;

// ─────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _svc = AuthService();
  List<UserModel> _users = [];
  bool _loading = true;
  String? _error;

  String _query = '';
  String _role = 'All';
  bool? _showActive = true;
  final Set<String> _selected = {};

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
      final body = await _svc.getAllUsers();
      final raw = (body['data'] as List? ?? []);
      _users = raw
          .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((u) => u.id != null && u.id!.isNotEmpty)
          .toList();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  List<UserModel> get _filtered {
    final q = _query.toLowerCase();
    return _users.where((u) {
      if (_showActive != null && u.active != _showActive) return false;
      if (_role != 'All' && u.role != _role) return false;
      if (q.isEmpty) return true;
      return u.fullName.toLowerCase().contains(q) ||
          (u.email ?? '').toLowerCase().contains(q) ||
          (u.phone ?? '').contains(q);
    }).toList();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? _danger : AppColors.navy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------- Actions ----------
  Future<void> _openForm([UserModel? user]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserFormSheet(user: user, svc: _svc),
    );
    if (saved == true) {
      _snack(user == null ? 'User added' : 'User updated');
      _load();
    }
  }

  Future<void> _setActive(List<String> ids, bool active) async {
    if (ids.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          active ? 'Activate' : 'Delete (Deactivate)',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          active
              ? 'Activate ${ids.length} user(s)?'
              : '${ids.length} user(s) will be deactivated and moved out of the active list. You can restore them later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              active ? 'Activate' : 'Deactivate',
              style: TextStyle(
                color: active ? AppColors.navy : _danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.bulkSetActive(ids, active: active);
      setState(_selected.clear);
      _snack(active ? 'Activated' : 'Deactivated');
      _load();
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  Future<void> _changePassword(UserModel u) async {
    final userId = u.id?.trim();
    if (userId == null || userId.isEmpty) {
      _snack('User ID is missing', error: true);
      return;
    }

    final newPass = await showDialog<String>(
      context: context,
      builder: (_) => PasswordDialog(name: u.firstName ?? ''),
    );
    if (newPass == null) return;

    try {
      await _svc.adminChangePassword(userId, newPass);
      _snack('Password changed');
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  void _toggle(String id) => setState(
    () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
  );

  void _bulkAction() {
    final sel = _users.where((u) => _selected.contains(u.id)).toList();
    final hasActive = sel.any((u) => u.active);
    if (hasActive) {
      // Deactivate الـ active بس
      _setActive(sel.where((u) => u.active).map((u) => u.id!).toList(), false);
    } else {
      _setActive(sel.map((u) => u.id!).toList(), true);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final list = _filtered;
    final selecting = _selected.isNotEmpty;
    final activeFilter = _showActive ?? true;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.background,
      appBar: AppBar(
        title: Text(
          selecting ? '${_selected.length} selected' : 'Users',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: isDark ? const Color(0xFF121212) : AppColors.white,
        foregroundColor: isDark ? AppColors.goldLight : AppColors.navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: selecting
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(_selected.clear),
              )
            : null,
        actions: [
          if (selecting)
            IconButton(
              icon: Icon(
                _users.any((u) => _selected.contains(u.id) && u.active)
                    ? Icons.person_off_rounded
                    : Icons.person_add_alt_1_rounded,
              ),
              onPressed: _bulkAction,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navy,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          'Add User',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search name, email or phone',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white10 : AppColors.border,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white10 : AppColors.border,
                  ),
                ),
              ),
            ),
          ),
          // Status + Role chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chip('All', _showActive == null, () {
                  setState(() {
                    _showActive = null;
                    _selected.clear();
                  });
                }),
                _chip('Active', _showActive == true, () {
                  setState(() {
                    _showActive = true;
                    _selected.clear();
                  });
                }),
                _chip('Inactive', _showActive == false, () {
                  setState(() {
                    _showActive = false;
                    _selected.clear();
                  });
                }),
                const SizedBox(width: 8),
                for (final r in [..._roles])
                  _chip(
                    r,
                    _role == r,
                    () => setState(() => _role = r),
                    gold: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _body(list, isDark)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback tap, {bool gold = false}) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: on
                  ? (gold ? AppColors.navy : Colors.white)
                  : AppColors.textSecondary,
            ),
          ),
          selected: on,
          showCheckmark: false,
          selectedColor: gold ? AppColors.gold : AppColors.navy,
          onSelected: (_) => tap(),
        ),
      );

  Widget _body(List<UserModel> list, bool isDark) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: _danger)),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'No users found',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final u = list[i];
          final id = u.id!; // مضمون مش null بعد الفلتر في _load
          final protected = _isProtected(u);
          return _UserCard(
            user: u,
            selected: _selected.contains(id),
            isDark: isDark,
            canDeactivate: !protected,
            onTap: () => _selected.isNotEmpty
                ? (protected ? null : _toggle(id))
                : _openForm(u),
            onLongPress: () {
              if (!protected) _toggle(id);
            },
            onAction: (a) {
              switch (a) {
                case 'edit':
                  _openForm(u);
                case 'password':
                  _changePassword(u);
                case 'toggle':
                  _setActive([id], !u.active);
              }
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  User card
// ─────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final UserModel user;
  final bool selected, isDark, canDeactivate;
  final VoidCallback onTap, onLongPress;
  final ValueChanged<String> onAction;

  const _UserCard({
    required this.user,
    required this.selected,
    required this.isDark,
    required this.canDeactivate,
    required this.onTap,
    required this.onLongPress,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final name = user.fullName.isEmpty ? 'Unnamed' : user.fullName;
    final channels = user.channelNames;

    return Material(
      color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AppColors.gold
                  : (isDark ? Colors.white10 : AppColors.border),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, color: AppColors.gold)
                    : Text(
                        user.initial,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.goldLight : AppColors.navy,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email ?? '—',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            user.role ?? '—',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppColors.goldLight
                                  : AppColors.navy,
                            ),
                          ),
                        ),
                        if (channels.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : AppColors.navy)
                                  .withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              channels,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: onAction,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                    value: 'password',
                    child: Text('Change password'),
                  ),
                  if (canDeactivate)
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(
                        user.active ? 'Delete (Deactivate)' : 'Activate',
                        style: TextStyle(color: user.active ? _danger : null),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Add / Edit bottom sheet
// ─────────────────────────────────────────────
class _UserFormSheet extends StatefulWidget {
  final UserModel? user; // null = add
  final AuthService svc;
  const _UserFormSheet({this.user, required this.svc});

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  final _key = GlobalKey<FormState>();
  late final _first = TextEditingController(text: widget.user?.firstName);
  late final _last = TextEditingController(text: widget.user?.lastName);
  late final _email = TextEditingController(text: widget.user?.email);
  late final _phone = TextEditingController(text: widget.user?.phone);
  final _pass = TextEditingController();
  late String _role = _roles.contains(widget.user?.role)
      ? widget.user!.role!
      : 'Sales';
  bool _saving = false, _hide = true;

  // ---- Channels (multi-select) ----
  final _channelsApi = CrudService(Endpoints.channels);
  List<ChannelModel> _allChannels = [];
  final Set<String> _selectedChannels = {}; // الـ IDs المختارة
  bool _channelsLoading = false;
  String? _channelsError;
  bool _channelsFetched = false; // عشان منحمّلهمش أكتر من مرة

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    // الـ IDs الحالية للـ user (بنفترض إنها comma separated زي ما كانت في الـ TextField)
    final existing = widget.user?.channelIds ?? '';
    _selectedChannels.addAll(
      existing
          .toString()
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty),
    );
    // لو بنعدّل Marketer، حمّل القنوات علطول
    if (_role == 'Marketer') _loadChannels();
  }

  Future<void> _loadChannels() async {
    if (_channelsFetched || _channelsLoading) return;
    setState(() {
      _channelsLoading = true;
      _channelsError = null;
    });
    try {
      final body = await _channelsApi.getAll(params: {'limit': 200});
      final res = ChannelsResponse.fromJson(body);
      // بنعرض الـ active بس + أي قناة مختارة قبل كده (حتى لو بقت inactive)
      _allChannels = res.data
          .where(
            (c) =>
                c.id != null && (c.active || _selectedChannels.contains(c.id)),
          )
          .toList();
      _channelsFetched = true;
    } catch (e) {
      _channelsError = e.toString();
    }
    if (mounted) setState(() => _channelsLoading = false);
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    // Marketer بس هو اللي بيبعت channels
    final channels = _role == 'Marketer' ? _selectedChannels.toList() : null;
    try {
      if (_isEdit) {
        await widget.svc.updateUser(widget.user!.id!, {
          'firstName': _first.text.trim(),
          'lastName': _last.text.trim(),
          'email': _email.text.trim(),
          'phone': _phone.text.trim(),
          'role': _role,
          'channels': ?channels,
        });
      } else {
        await widget.svc.addUser(
          firstName: _first.text.trim(),
          lastName: _last.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          password: _pass.text,
          role: _role,
          channels: channels,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: _danger),
      );
    }
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  // ---- UI بتاع اختيار القنوات ----
  Widget _channelsPicker(bool isDark) {
    Widget child;
    if (_channelsLoading) {
      child = const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (_channelsError != null) {
      child = Row(
        children: [
          Expanded(
            child: Text(
              _channelsError!,
              style: const TextStyle(color: _danger),
            ),
          ),
          TextButton(onPressed: _loadChannels, child: const Text('Retry')),
        ],
      );
    } else if (_allChannels.isEmpty) {
      child = const Text(
        'No channels available',
        style: TextStyle(color: AppColors.textSecondary),
      );
    } else {
      child = Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final c in _allChannels)
            FilterChip(
              label: Text(
                c.displayName,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _selectedChannels.contains(c.id)
                      ? AppColors.navy
                      : AppColors.textSecondary,
                ),
              ),
              selected: _selectedChannels.contains(c.id),
              showCheckmark: true,
              checkmarkColor: AppColors.navy,
              selectedColor: AppColors.gold,
              onSelected: (on) => setState(() {
                on
                    ? _selectedChannels.add(c.id!)
                    : _selectedChannels.remove(c.id);
              }),
            ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white24 : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                'Channels (${_selectedChannels.length} selected)',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isEdit ? 'Edit User' : 'Add User',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _first,
                        validator: _req,
                        decoration: _dec('First name', Icons.person_rounded),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _last,
                        validator: _req,
                        decoration: _dec(
                          'Last name',
                          Icons.person_outline_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Invalid email' : null,
                  decoration: _dec('Email', Icons.email_rounded),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  validator: _req,
                  decoration: _dec('Phone', Icons.phone_rounded),
                ),
                if (!_isEdit) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pass,
                    obscureText: _hide,
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Min 6 characters' : null,
                    decoration: _dec('Password', Icons.lock_rounded).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _hide
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: _dec('Role', Icons.badge_rounded),
                  items: _roles
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _role = v ?? _role);
                    // أول ما يختار Marketer حمّل القنوات
                    if (_role == 'Marketer') _loadChannels();
                  },
                ),
                if (_role == 'Marketer') ...[
                  const SizedBox(height: 12),
                  _channelsPicker(isDark),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.navy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _isEdit ? 'Save changes' : 'Create user',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
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
