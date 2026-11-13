// Shared UI and Design Tokens based on UI_imgs/DESIGN_PREVIEW.md
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand Emerald
  static const Color primary = Color(0xFF16A36A);
  static const Color primaryDark = Color(0xFF087F55);
  static const Color primaryTint = Color(0xFFE7F6EF);
  static const Color secondary = Color(0xFFA3D977);

  // Backgrounds & Neutral Surfaces
  static const Color background = Color(0xFFF7F9F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5EBE6);

  // Typography
  static const Color textPrimary = Color(0xFF202B26);
  static const Color textSecondary = Color(0xFF77847C);
  static const Color textMuted = Color(0xFFA0ABA4);

  // Semantic Status Colors
  static const Color statusSuccess = Color(0xFF22C55E); // Còn hạn
  static const Color statusSuccessTint = Color(0xFFE7FAEE);

  static const Color statusWarning = Color(0xFFF59E0B); // Sắp hết hạn (<= 3 ngày) / Sắp hết số lượng
  static const Color statusWarningTint = Color(0xFFFEF5E2);

  static const Color statusDanger = Color(0xFFEF4444); // Đã hết hạn
  static const Color statusDangerTint = Color(0xFFFEECEC);

  static const Color statusPlanned = Color(0xFF2563EB); // Đã lên lịch
  static const Color statusPlannedTint = Color(0xFFEFF6FF);
}
