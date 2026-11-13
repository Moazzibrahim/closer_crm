// ignore_for_file: deprecated_member_use
// reshuffle_rules_screen.dart
// قايمة قواعد الـ Reshuffle للأدمن: تفعيل/تعطيل، تعديل، حذف، إضافة.
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/features/Reshuffle/presentation/screens/reshuffle_rule_form_screen.dart';
import 'package:flutter_application_1/features/Reshuffle/provider/reshuffle_service.dart';
import 'package:flutter_application_1/features/reshuffle/data/reshuffle_rule_model.dart';
import 'package:flutter_application_1/features/reshuffle/presentation/widgets/reshuffle_widgets.dart';

class ReshuffleRulesScreen extends StatefulWidget {
  const ReshuffleRulesScreen({super.key});

  @override
  State<ReshuffleRulesScreen> createState() => _ReshuffleRulesScreenState();
}

class _ReshuffleRulesScreenState extends State<ReshuffleRulesScreen> {
  final _svc = ReshuffleService();
  List<RsRule> _rules = [];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {}; // قواعد بتتفعّل/بتتحذف دلوقتي

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final r = await _svc.list();
      if (!mounted) return;
      setState(() {
        _rules = r;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggle(RsRule r, bool on) async {
    if (_busy.contains(r.id)) return;
    setState(() => _busy.add(r.id));
    try {
      final u = await _svc.toggle(r.id, on);
      if (!mounted) return;
      setState(() {
        final i = _rules.indexWhere((x) => x.id == r.id);
        if (i >= 0) _rules[i] = u;
      });
      rsToast(
        context,
        on
            ? 'Rule activated — applies to leads entering these stages from now on'
            : 'Rule deactivated — its scheduled leads were cancelled',
      );
    } catch (e) {
      rsToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  Future<void> _delete(RsRule r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete rule?'),
        content: Text(
          '"${r.name}" will be deleted permanently and all leads scheduled on it will be cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE5484D),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy.add(r.id));
    try {
      await _svc.delete(r.id);
      if (!mounted) return;
      setState(() => _rules.removeWhere((x) => x.id == r.id));
      rsToast(context, 'Rule deleted');
    } catch (e) {
      rsToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  Future<void> _openForm([RsRule? r]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ReshuffleRuleFormScreen(ruleId: r?.id)),
    );
    if (saved != true || !mounted) return;
    rsToast(
      context,
      r == null
          ? 'Rule created (inactive) — activate it when you are ready'
          : 'Rule updated',
    );
    _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final active = _rules.where((r) => r.isActive).length;
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navy,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New rule',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          RsHeader(
            title: 'Reshuffle Rules',
            subtitle: '${_rules.length} rules · $active active',
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(silent: true),
              child: _content(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    // ListView دايمًا عشان الـ pull-to-refresh يشتغل حتى في الحالات الفاضية
    if (_loading && _rules.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }
    if (_error != null && _rules.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFE5484D)),
          ),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }
    if (_rules.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 300,
            child: Center(
              child: Text(
                'No reshuffle rules yet',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _rules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final r = _rules[i];
        return _RuleCard(
          rule: r,
          busy: _busy.contains(r.id),
          onToggle: (v) => _toggle(r, v),
          onEdit: () => _openForm(r),
          onDelete: () => _delete(r),
        );
      },
    );
  }
}

class _RuleCard extends StatelessWidget {
  final RsRule rule;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit, onDelete;
  const _RuleCard({
    required this.rule,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final r = rule;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: r.isActive
              ? AppColors.gold.withOpacity(0.6)
              : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (r.description.isNotEmpty)
                            Text(
                              r.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'P${r.priority}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                    busy
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Switch(
                            value: r.isActive,
                            activeColor: AppColors.navy,
                            activeTrackColor: AppColors.gold,
                            onChanged: onToggle,
                          ),
                  ],
                ),
                const SizedBox(height: 8),
                // الـ stages اللي الـ rule شغالة عليها
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in r.stages)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: (s.stage?.color ?? AppColors.gold).withOpacity(
                            0.12,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: s.stage?.color ?? AppColors.gold,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              s.label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    _Info(Icons.groups_rounded, r.poolSummary),
                    _Info(Icons.schedule_rounded, r.workingHours.summary),
                    _Info(Icons.repeat_rounded, 'max ${r.maxReshuffles}'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: busy ? null : onEdit,
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: busy ? null : onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Info(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
