// inbox_screen.dart — قايمة المحادثات (Unifonic / Unisent)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/features/messaging/data/messaging_model.dart';
import 'package:flutter_application_1/features/messaging/presentation/chat_screen.dart';
import 'package:flutter_application_1/features/messaging/presentation/quick_send_sheet.dart';
import 'package:flutter_application_1/features/messaging/provider/messaging_provider.dart';
import 'package:flutter_application_1/features/sales/presentation/sales_picker.dart';
import 'package:provider/provider.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});
  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  // المحادثات المحددة (long press)
  final Set<String> _selected = {};
  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        context.read<MessagingProvider>().loadMore();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<MessagingProvider>();
      p.load();
      p.refreshUnread();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _open(WaConversation c) {
    final p = context.read<MessagingProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: p,
          child: ChatScreen(conversation: c),
        ),
      ),
    );
  }

  void _toggle(String id) => setState(
    () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
  );

  Future<void> _assignSelected() async {
    final p = context.read<MessagingProvider>();
    final s = await pickSales(
      context,
      p.salesOptions,
      title: 'Assign ${_selected.length} chat(s) to…',
    );
    if (s == null || !mounted) return;
    try {
      final r = await p.assignMany(_selected.toList(), s.id);
      if (!mounted) return;
      setState(_selected.clear);
      final parts = [
        '${r.assigned} assigned to ${r.salesName.isEmpty ? s.label : r.salesName}',
        if (r.already > 0) '${r.already} already',
        if (r.noLead > 0) '${r.noLead} no lead',
        if (r.notAllowed > 0) '${r.notAllowed} not allowed',
      ];
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parts.join(' · '))));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MessagingProvider>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final me = p.me!;
    final canQuickSend =
        me.role == 'admin' || me.role == 'manager' || me.role == 'salesmanager';

    final barBg = dark ? AppColors.navyLight : AppColors.white;
    final barFg = dark ? AppColors.goldLight : AppColors.navy;

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        // زرار back يلغي التحديد بدل ما يقفل الشاشة
        if (!didPop && _selecting) setState(_selected.clear);
      },
      child: Scaffold(
        backgroundColor: dark ? AppColors.navy : AppColors.background,
        appBar: _selecting
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(_selected.clear),
                ),
                title: Text('${_selected.length} selected'),
                backgroundColor: barBg,
                foregroundColor: barFg,
                elevation: 0,
                actions: [
                  IconButton(
                    tooltip: 'Select all',
                    icon: const Icon(Icons.select_all_rounded),
                    onPressed: () => setState(
                      () => _selected.addAll(p.visible.map((c) => c.id)),
                    ),
                  ),
                  if (me.canAssign && p.salesOptions.isNotEmpty)
                    IconButton(
                      tooltip: 'Assign to sales',
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      onPressed: _assignSelected,
                    ),
                ],
              )
            : AppBar(
                title: Text(
                  p.archivedView
                      ? 'Archived chats'
                      : (p.isUnisent ? 'Unisent' : 'WhatsApp'),
                ),
                backgroundColor: barBg,
                foregroundColor: barFg,
                elevation: 0,
                actions: [
                  if (canQuickSend)
                    IconButton(
                      tooltip: 'Quick send',
                      icon: const Icon(Icons.send_rounded),
                      onPressed: () => showQuickSendSheet(context),
                    ),
                  IconButton(
                    tooltip: p.archivedView ? 'Active chats' : 'Archived',
                    icon: Icon(
                      p.archivedView
                          ? Icons.inbox_rounded
                          : Icons.archive_outlined,
                    ),
                    onPressed: () => p.setFilters(archived: !p.archivedView),
                  ),
                ],
              ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: TextField(
                controller: _search,
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(
                    const Duration(milliseconds: 400),
                    () => p.setFilters(q: v),
                  );
                },
                decoration: InputDecoration(
                  hintText: 'Search by name or number',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  FilterChip(
                    label: const Text('Unread'),
                    selected: p.unreadOnly,
                    onSelected: (v) => p.setFilters(unread: v),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    avatar: const Icon(
                      Icons.circle,
                      size: 10,
                      color: Colors.green,
                    ),
                    label: const Text('Interested'),
                    selected: p.interestFilter == 'interested',
                    onSelected: (v) => v
                        ? p.setFilters(interest: 'interested')
                        : p.setFilters(clearInterest: true),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    avatar: const Icon(
                      Icons.circle,
                      size: 10,
                      color: Colors.red,
                    ),
                    label: const Text('Not interested'),
                    selected: p.interestFilter == 'not_interested',
                    onSelected: (v) => v
                        ? p.setFilters(interest: 'not_interested')
                        : p.setFilters(clearInterest: true),
                  ),
                  const SizedBox(width: 8),
                  if (me.canFilter && p.salesOptions.isNotEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.person_outline, size: 16),
                      label: Text(
                        p.salesOptions
                                .where((s) => s.id == p.salesFilter)
                                .map((s) => s.label)
                                .firstOrNull ??
                            'All sales',
                      ),
                      onPressed: () async {
                        final s = await pickSales(
                          context,
                          p.salesOptions,
                          title: 'Filter by sales',
                          includeAll: true,
                        );
                        if (s == null) return; // اتقفلت من غير اختيار
                        if (s.id.isEmpty) {
                          p.setFilters(clearSales: true);
                        } else {
                          p.setFilters(sales: s.id);
                        }
                      },
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await p.load();
                  await p.refreshUnread();
                },
                child: _body(p, dark, me.canAssign),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(MessagingProvider p, bool dark, bool canAssign) {
    final items = p.visible; // بعد فلتر الـ interest

    if (p.loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p.error != null && items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(child: Text(p.error!, textAlign: TextAlign.center)),
          TextButton(onPressed: p.load, child: const Text('Retry')),
        ],
      );
    }
    if (items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('No conversations')),
        ],
      );
    }
    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length + (p.loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (_, i) {
        if (i >= items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final c = items[i];
        return _ConversationTile(
          c: c,
          dark: dark,
          selected: _selected.contains(c.id),
          onTap: () => _selecting ? _toggle(c.id) : _open(c),
          // التحديد للي يقدر يعمل assign بس (Sales بياخد 403)
          onLongPress: canAssign ? () => _toggle(c.id) : null,
        );
      },
    );
  }
}

String fmtTime(DateTime? t) {
  if (t == null) return '';
  final now = DateTime.now();
  final sameDay =
      t.year == now.year && t.month == now.month && t.day == now.day;
  if (sameDay) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
  return '${t.day}/${t.month}';
}

class _ConversationTile extends StatelessWidget {
  final WaConversation c;
  final bool dark;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _ConversationTile({
    required this.c,
    required this.dark,
    required this.onTap,
    this.selected = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final sub = dark ? Colors.white60 : AppColors.textSecondary;
    final interestColor = c.interest == 'interested'
        ? Colors.green
        : c.interest == 'not_interested'
        ? Colors.red
        : null;

    return ListTile(
      selected: selected,
      selectedTileColor: AppColors.gold.withOpacity(0.15),
      onTap: onTap,
      onLongPress: onLongPress,
      leading: selected
          ? const CircleAvatar(
              backgroundColor: AppColors.gold,
              child: Icon(Icons.check_rounded, color: AppColors.navy),
            )
          : CircleAvatar(
              backgroundColor: AppColors.navy,
              child: Text(
                c.title.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      title: Row(
        children: [
          if (c.pinned)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.push_pin, size: 14),
            ),
          Expanded(
            child: Text(
              c.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: c.unread > 0 ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          if (interestColor != null)
            Icon(Icons.circle, size: 10, color: interestColor),
        ],
      ),
      subtitle: Row(
        children: [
          if (c.lastDirection == 'out')
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.done_all_rounded, size: 14, color: sub),
            ),
          Expanded(
            child: Text(
              c.preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: sub),
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(fmtTime(c.lastAt), style: TextStyle(fontSize: 11, color: sub)),
          const SizedBox(height: 4),
          if (c.unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${c.unread}',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else if (!c.windowOpen)
            Icon(Icons.lock_clock_outlined, size: 16, color: sub),
        ],
      ),
    );
  }
}
