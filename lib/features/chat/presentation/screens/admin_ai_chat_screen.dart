// ignore_for_file: deprecated_member_use

// lib/features/admin/presentation/screens/admin_ai_chat_screen.dart
// شات AI لكل الرولز: الاسم والاقتراحات حسب اليوزر الحالي، والـ limit بتاعه هو.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/features/auth/providers/auth_provider.dart';
import 'package:flutter_application_1/features/chat/provider/chat_provider.dart';
import 'package:flutter_application_1/features/chat/provider/chat_service.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────
//  Wrapper: بيعمل الـ Provider محلياً للشاشة
// ─────────────────────────────────────────────
class AiChatScreen extends StatelessWidget {
  const AiChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AiChatProvider()..loadUsage(),
      child: const _ChatView(),
    );
  }
}

// ─────────────────────────────────────────────
//  اقتراحات سريعة حسب الرول
// ─────────────────────────────────────────────
String _normRole(String? role) =>
    (role ?? '').toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');

List<String> _suggestionsFor(String? role) {
  switch (_normRole(role)) {
    case 'sales':
      return const [
        'كام ليد عندي النهارده؟',
        'اعرضلي المتابعات المتأخرة',
        'اعرضلي الليدز اللي ملهاش كومنت',
      ];
    case 'teamleader':
      return const [
        'كام ليد عند فريقي النهارده؟',
        'مين أحسن سيلز في فريقي الشهر ده؟',
        'اعرضلي المتابعات المتأخرة',
      ];
    case 'marketer':
      return const [
        'اعرضلي الحملات النشطة',
        'كام ليد جه من حملاتي النهارده؟',
        'أي قناة جابت أكتر ليدز؟',
      ];
    default: // admin / manager
      return const [
        'اعرضلي المشاريع النشطة',
        'كام ليد عندنا النهارده؟',
        'مين أحسن سيلز الشهر ده؟',
      ];
  }
}

String _emptySubtitleFor(String? role) {
  switch (_normRole(role)) {
    case 'sales':
      return 'Ask about your leads and follow-ups';
    case 'teamleader':
      return 'Ask about your team and their leads';
    case 'marketer':
      return 'Ask about your campaigns and leads';
    default:
      return 'Ask about projects, leads or your team';
  }
}

// عربي ولا إنجليزي؟ عشان اتجاه النص يطلع صح
TextDirection _dirOf(String s) => RegExp(r'[\u0600-\u06FF]').hasMatch(s)
    ? TextDirection.rtl
    : TextDirection.ltr;

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  int _lastCount = 0; // عشان نعمل auto-scroll لما رسالة جديدة توصل

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }
  void _send([String? preset]) {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty) return;
    _input.clear();
    context.read<AiChatProvider>().send(text);
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chat = context.watch<AiChatProvider>();
    final role = context.select<AuthProvider, String?>((a) => a.role);
    // رسالة جديدة أو typing indicator → انزل لآخر الشات
    final count = chat.messages.length + (chat.sending ? 1 : 0);
    if (count != _lastCount) {
      _lastCount = count;
      _scrollToBottom();
    }
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            _Header(
              usage: chat.usage,
              canClear: chat.messages.isNotEmpty && !chat.sending,
              onClear: chat.clear,
            ),
            // ── Messages ──
            Expanded(
              child: chat.messages.isEmpty && !chat.sending
                  ? _EmptyState(
                      suggestions: _suggestionsFor(role),
                      subtitle: _emptySubtitleFor(role),
                      onPick: _send,
                      enabled: !chat.limitReached,
                    )
                  : ListView.builder(
                      controller: _scroll,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      itemCount: count,
                      itemBuilder: (_, i) {
                        // آخر عنصر = typing indicator لو لسه بيستنى الرد
                        if (i == chat.messages.length) {
                          return const _TypingBubble();
                        }
                        final m = chat.messages[i];
                        final isLast = i == chat.messages.length - 1;
                        return _Bubble(
                          message: m,
                          // Retry على آخر رسالة خطأ بس، ومش لو الحد اليومي خلص
                          onRetry:
                              (m.isError &&
                                  isLast &&
                                  !chat.limitReached &&
                                  !chat.sending)
                              ? chat.retry
                              : null,
                        );
                      },
                    ),
            ),
            // ── لو الحد اليومي خلص ──
            if (chat.limitReached) const _LimitBanner(),
            // ── Input ──
            _InputBar(
              controller: _input,
              enabled: !chat.limitReached,
              sending: chat.sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────
//  Header: عنوان + اسم اليوزر/عداد الاستهلاك + مسح المحادثة
// ─────────────────────────────────────────────
class _Header extends StatelessWidget {
  final AiUsage? usage;
  final bool canClear;
  final VoidCallback onClear;

  const _Header({
    required this.usage,
    required this.canClear,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final top = MediaQuery.of(context).padding.top;
    // اسم اليوزر اللي عامل لوجين
    final name = context.select<AuthProvider, String>((a) => a.name);

    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 14, 16, 18),
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
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold.withOpacity(0.5)),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.goldLight,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Assistant',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  // العداد اليومي: المتبقي من حد اليوزر الحالي
                  usage == null
                      ? (name.isEmpty
                            ? 'Ask about your CRM data'
                            : 'Hi $name, ask about your CRM data')
                      : usage!.unlimited
                      ? 'Unlimited questions'
                      : '${usage!.remaining} of ${usage!.limit} questions left today',
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
          // زرار مسح المحادثة
          if (canClear)
            IconButton(
              tooltip: 'New chat',
              onPressed: onClear,
              icon: const Icon(
                Icons.add_comment_rounded,
                color: AppColors.goldLight,
                size: 22,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Message bubble
// ─────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry; // لو مش null يظهر زرار Retry
  const _Bubble({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = message.isUser;
    final maxW = MediaQuery.of(context).size.width * 0.82;

    final Color textColor = isUser
        ? Colors.white
        : message.isError
        ? Colors.redAccent
        : (isDark ? Colors.white : AppColors.textPrimary);

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        gradient: isUser
            ? const LinearGradient(
                colors: [AppColors.navy, AppColors.navyLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isUser
            ? null
            : (isDark ? const Color(0xFF1E1E1E) : AppColors.white),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isUser ? 18 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 18),
        ),
        border: isUser
            ? null
            : Border.all(
                color: message.isError
                    ? Colors.redAccent.withOpacity(0.5)
                    : (isDark ? Colors.white10 : AppColors.border),
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // اتجاه النص حسب اللغة (عربي RTL / إنجليزي LTR)
          Directionality(
            textDirection: _dirOf(message.content),
            child: SelectableText(
              message.content,
              style: TextStyle(fontSize: 14, height: 1.5, color: textColor),
            ),
          ),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gold,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: isUser
            ? bubble
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const _AiAvatar(),
                  const SizedBox(width: 8),
                  Flexible(child: bubble),
                ],
              ),
      ),
    );
  }
}

class _AiAvatar extends StatelessWidget {
  const _AiAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.18),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold.withOpacity(0.5)),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        size: 14,
        color: AppColors.gold,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Typing indicator (3 نقط بتنبض)
// ─────────────────────────────────────────────
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _AiAvatar(),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.white10 : AppColors.border,
                ),
              ),
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    // كل نقطة بتبدأ متأخرة شوية عن اللي قبلها
                    final t = ((_c.value - i * 0.2) % 1.0);
                    final opacity = 0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2);
                    return Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(
                          opacity.clamp(0.3, 1.0),
                        ),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Empty state + اقتراحات سريعة (حسب الرول)
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final List<String> suggestions;
  final String subtitle;
  final ValueChanged<String> onPick;
  final bool enabled;
  const _EmptyState({
    required this.suggestions,
    required this.subtitle,
    required this.onPick,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 34,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'How can I help?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: suggestions
                  .map(
                    (s) => ActionChip(
                      label: Text(s),
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.goldLight : AppColors.navy,
                      ),
                      backgroundColor: isDark
                          ? const Color(0xFF1E1E1E)
                          : AppColors.white,
                      side: BorderSide(
                        color: isDark ? Colors.white10 : AppColors.border,
                      ),
                      onPressed: enabled ? () => onPick(s) : null,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Banner: الحد اليومي خلص
// ─────────────────────────────────────────────
class _LimitBanner extends StatelessWidget {
  const _LimitBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withOpacity(0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_clock_rounded, size: 18, color: AppColors.gold),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'You reached your daily AI limit. Try again tomorrow.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Input bar
// ─────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canSend = enabled && !sending;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : AppColors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? Colors.white10 : AppColors.border,
                ),
              ),
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => canSend ? onSend() : null,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Ask anything...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // زرار الإرسال
          GestureDetector(
            onTap: canSend
                ? () {
                    HapticFeedback.selectionClick();
                    onSend();
                  }
                : null,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: canSend ? 1 : 0.5,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.navy, AppColors.navyLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: AppColors.gold, width: 1.5),
                ),
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.gold,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        size: 20,
                        color: AppColors.gold,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}