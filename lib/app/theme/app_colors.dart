import 'package:flutter/material.dart';

/// ألوان Closer CRM — نفس أسامي ملف الـ PDF (crmTokens.js)
class AppColors {
  AppColors._();

  // ── الألوان الأساسية ──
  static const Color primary = Color(0xFF00A4BD);
  static const Color primarySoft = Color(0x1F00A4BD); // rgba(0,164,189,0.12)
  static const Color accent = Color(0xFFFF7A59); // البراند بس، مش للأزرار
  static const Color link = Color(0xFF0091AE);
  static const Color info = Color(0xFF2D7FF9);
  static const Color topbar = Color(0xFF1B2129);
  static const Color text = Color(0xFF33475B);
  static const Color textMuted = Color(0xFF7C98B6);
  static const Color bg = Color(0xFFF5F8FA);
  static const Color panel = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFE5E8ED);

  // ── ألوان الحالات ──
  static const Color success = Color(0xFF5FAE82);
  static const Color warning = Color(0xFFD9A441);
  static const Color danger = Color(0xFFF2545B);
  static const Color dangerText = Color(0xFFB4232B);
  static const Color neutral = Color(0xFF8B95A3);

  // ── حالات المتابعات (fg) ──
  static const Color late = Color(0xFFD93F47);
  static const Color today = Color(0xFF0091AE);
  static const Color soon = Color(0xFFB7791F);
  static const Color ok = Color(0xFF00806F);

  // ── tone: الخلفية والحد لكل حالة ──
  static const Tone toneLate = Tone(
    fg: Color(0xFFD93F47),
    bg: Color(0x1AF2545B), // 0.10
    line: Color(0x59F2545B), // 0.35
  );
  static const Tone toneToday = Tone(
    fg: Color(0xFF0091AE),
    bg: Color(0x140091AE), // 0.08
    line: Color(0x400091AE), // 0.25
  );
  static const Tone toneSoon = Tone(
    fg: Color(0xFFB7791F),
    bg: Color(0x24E8B339), // 0.14
    line: Color(0x73E8B339), // 0.45
  );
  static const Tone toneOk = Tone(
    fg: Color(0xFF00806F),
    bg: Color(0x1A00A38D), // 0.10
    line: Color(0x5900A38D), // 0.35
  );

  // ── Stage لو الباك رجّع color فاضي ──
  static const Color stageFallback = Color(0xFF8B95A3);

  // ── Avatar (بالترتيب حسب الاسم) ──
  static const List<Color> avatar = [
    Color(0xFF516F90),
    Color(0xFF00A38D),
    Color(0xFFE8B339),
    Color(0xFFF2545B),
    Color(0xFF7C6FD6),
    Color(0xFF2E8BC0),
    Color(0xFFC4703D),
  ];

  static Color avatarFor(String name) {
    final n = name.trim();
    if (n.isEmpty) return avatar.first;
    return avatar[n.codeUnits.fold<int>(0, (a, b) => a + b) % avatar.length];
  }

  // ── Radius ──
  static const double radiusSm = 6, radiusMd = 10, radiusLg = 16;

  // ── لوجو (للـ gradients والأيقونات على الغامق) ──
  static const Color logoTeal = Color(0xFF31D8C8);
  static const Color logoNavy = Color(0xFF0E3D58);

  // ═════════════════════════════════════════
  //  Aliases قديمة — شيلها بعد ما تستبدل الاستخدامات
  // ═════════════════════════════════════════
  @Deprecated('use topbar')
  static const Color navy = topbar;
  @Deprecated('use topbar (أو درجة أفتح منه)')
  static const Color navyLight = Color(0xFF28323F);
  @Deprecated('use primary')
  static const Color gold = primary;
  @Deprecated('use logoTeal')
  static const Color goldLight = logoTeal;
  @Deprecated('use bg')
  static const Color background = bg;
  @Deprecated('use panel')
  static const Color white = panel;
  @Deprecated('use text')
  static const Color textPrimary = text;
  @Deprecated('use textMuted')
  static const Color textSecondary = textMuted;
  @Deprecated('use line')
  static const Color border = line;
  @Deprecated('use accent')
  static const Color brandAccent = accent;
  @Deprecated('use avatar')
  static const List<Color> avatars = avatar;
}

class Tone {
  final Color fg, bg, line;
  const Tone({required this.fg, required this.bg, required this.line});
}
