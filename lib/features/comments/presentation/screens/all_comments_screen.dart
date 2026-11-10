// ignore_for_file: deprecated_member_use, unnecessary_underscores
import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/features/comments/data/all_comments_model.dart';
import 'package:flutter_application_1/features/comments/data/last_comment_model.dart';
import 'package:flutter_application_1/features/comments/presentation/widgets/comment_card.dart';
import 'package:flutter_application_1/features/comments/presentation/widgets/lead_comment_sheet.dart';
import 'package:flutter_application_1/features/comments/providers/comments_service.dart';
import 'package:flutter_application_1/features/leads/data/lead_model.dart';
import 'package:flutter_application_1/features/leads/presentation/widgets/lead_details_widget.dart';

// بتجيب كل كومنتات الـ lead من الـ API. بترجّع true لو اتضاف كومنت.
import 'package:flutter_application_1/core/widgets/lead_action_sheet.dart'
    show StageOpt;

class AllCommentsScreen extends StatefulWidget {
  final LeadItem lead;
  final List<StageOpt> stages; // ← اتغيّرت
  final List<({String id, String name})> projects; // ← جديدة
  final bool canComment;
  final String currentUserId;
  final bool isAdmin;
  final bool canSkipStage; // 👈 admin بس: كومنت من غير تغيير stage

  const AllCommentsScreen({
    super.key,
    required this.lead,
    required this.stages,
    this.projects = const [], // ← جديدة
    this.canComment = true,
    this.currentUserId = '',
    this.isAdmin = false,
    this.canSkipStage = false, // 👈 الافتراضي: لازم يغيّر stage
  });

  @override
  State<AllCommentsScreen> createState() => _AllCommentsScreenState();
}

class _AllCommentsScreenState extends State<AllCommentsScreen> {
  final _svc = CommentsService();
  List<CommentItem> _list = [];
  bool _loading = true;
  String? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final res = await _svc.getComments(widget.lead.id);
      if (!mounted) return;
      setState(() {
        _list = CommentItem.parseList(res);
        _error = null;
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

  Future<void> _add() async {
    final added = await showLeadCommentSheet(
      context,
      leadId: widget.lead.id,
      leadName: widget.lead.name,
      lastComment: _list.isEmpty ? null : LastComment.tryParse(_list.first.raw),
      currentStageId: widget.lead.stageId,
      stages: widget.stages,
      projects: widget.projects, // ← جديدة
      canSkipStage: widget.canSkipStage, // 👈
    );
    if (!added || !mounted) return;
    _changed = true;
    await _load(silent: true);
  }

  void _back() => Navigator.of(context).pop(_changed);

  @override
  Widget build(BuildContext context) {
    final t = LdTheme.of(context);
    final top = MediaQuery.of(context).padding.top;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(16, top + 10, 16, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: t.dark
                      ? [const Color(0xFF1A1F2E), AppColors.navy]
                      : [AppColors.navy, AppColors.navyLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  LdBackBtn(onTap: _back),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'All Comments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.lead.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_list.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _list.isEmpty
                  ? LdErrorView(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      onRefresh: () => _load(silent: true),
                      child: _list.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: 240,
                                  child: Center(
                                    child: Text(
                                      'No comments yet',
                                      style: TextStyle(
                                        color: t.sub,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              padding: const EdgeInsets.all(16),
                              itemCount: _list.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) => CommentCard(
                                comment: _list[i],
                                leadId: widget.lead.id,
                                svc: _svc,
                                canReply: widget.canComment,
                                currentUserId: widget.currentUserId,
                                isAdmin: widget.isAdmin,
                                onChanged: () {
                                  _changed = true;
                                  _load(silent: true);
                                },
                              ),
                            ),
                    ),
            ),

            // Add comment bar (بس لو الـ role يقدر)
            if (widget.canComment)
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  decoration: BoxDecoration(
                    color: t.card,
                    border: Border(top: BorderSide(color: t.border)),
                  ),
                  child: LdBottomBtn(
                    icon: Icons.add_comment_rounded,
                    label: 'Add comment',
                    filled: true,
                    onTap: _add,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
