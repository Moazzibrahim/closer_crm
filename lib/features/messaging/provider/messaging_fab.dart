// messaging_fab.dart
// الزرار الثابت فوق الـ nav bar يمين — بيتحط في الـ MainShell فوق الـ IndexedStack
// فبيفضل ظاهر في كل التابات وكل الصفحات الفرعية جواها.

// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/app/theme/app_colors.dart';
import 'package:flutter_application_1/features/messaging/presentation/inbox_screen.dart';
import 'package:provider/provider.dart';

import 'messaging_provider.dart';

class MessagingFab extends StatelessWidget {
  const MessagingFab({super.key});

  Future<void> _open(BuildContext context, {String? direct}) async {
    HapticFeedback.mediumImpact();
    final provider = context.read<MessagingProvider>();

    String? choice = direct;
    choice ??= await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_rounded),
              title: const Text('WhatsApp (Unifonic)'),
              trailing: _CountBadge(provider.unreadUnifonic),
              onTap: () => Navigator.pop(sheetCtx, 'messaging'),
            ),
            ListTile(
              leading: const Icon(Icons.sms_rounded),
              title: const Text('Unisent'),
              trailing: _CountBadge(provider.unreadUnisent),
              onTap: () => Navigator.pop(sheetCtx, 'unisent'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    provider.switchProvider(choice);

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: const InboxScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MessagingProvider>();
    // مستخدم مالوش صلاحية / لسه بيحمّل / فيه error → مفيش زرار
    if (!p.ready) return const SizedBox.shrink();
    // اخفيه لو الكيبورد مفتوح
    final keyboard = MediaQueryData.fromView(
      View.of(context),
    ).viewInsets.bottom;
    if (keyboard > 0) return const SizedBox.shrink();
    return Semantics(
      button: true,
      label: 'Messages',
      child: GestureDetector(
        onTap: () => _open(context),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
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
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  size: 24,
                  color: AppColors.gold,
                ),
              ),
              if (p.totalUnread > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      p.totalUnread > 99 ? '99+' : '${p.totalUnread}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// class _UnreadPill extends StatelessWidget {
//   final String label;
//   final IconData icon;
//   final int count;
//   final VoidCallback onTap;
//   const _UnreadPill({
//     required this.label,
//     required this.icon,
//     required this.count,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
//         decoration: BoxDecoration(
//           color: AppColors.panel,
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(color: AppColors.primary, width: 1.2),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.12),
//               blurRadius: 10,
//               offset: const Offset(0, 3),
//             ),
//           ],
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(icon, size: 14, color: AppColors.primary),
//             const SizedBox(width: 5),
//             Text(
//               label,
//               style: const TextStyle(
//                 fontSize: 11.5,
//                 fontWeight: FontWeight.w700,
//                 color: AppColors.text,
//                 decoration: TextDecoration.none,
//               ),
//             ),
//             const SizedBox(width: 6),
//             _CountBadge(count),
//           ],
//         ),
//       ),
//     );
//   }
// }

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge(this.count);

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      constraints: const BoxConstraints(minWidth: 18),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
