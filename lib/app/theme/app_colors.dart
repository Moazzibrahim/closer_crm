import 'package:flutter/material.dart';

// ✅ لو الـ AppColors في ملف تاني، استورده هنا:
// import 'package:your_app/core/app_colors.dart';

class AppColors {
  // الكحلي بقى أسود. navyLight رمادي غامق جدًا عشان الـ gradients والكروت
  // في الدارك مود لسه يبان فيها فرق بين الطبقات (لو الاتنين أسود صافي هتبقى مسطحة)
  static const Color navy = Color(0xFF000000);
  static const Color navyLight = Color(0xFF1C1C1E);

  // الجولد زي ما هو
  static const Color gold = Color(0xFFC9A45C);
  static const Color goldLight = Color(0xFFE3C98A);

  static const Color background = Color(0xFFF6F7F9);
  static const Color white = Colors.white;

  static const Color textPrimary = Color(0xFF17212B);
  static const Color textSecondary = Color(0xFF718096);

  static const Color border = Color(0xFFE2E8F0);
}
