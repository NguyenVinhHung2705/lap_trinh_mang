import 'package:flutter/material.dart';

/// Standard Design Tokens for Smart Food Life.
///
/// Matches `AGENTS.md` and `UI_imgs/DESIGN_PREVIEW.md`.
abstract class AppColors {
  // Brand Emerald & Accent
  static const Color primary = Color(0xFF16A36A);
  static const Color primaryDark = Color(0xFF087F55);
  static const Color primaryTint = Color(0xFFE7F6EF);
  static const Color secondary = Color(0xFFA3D977);

  // Background & Surfaces
  static const Color background = Color(0xFFF7F9F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5EBE6);

  // Typography
  static const Color textPrimary = Color(0xFF202B26);
  static const Color textSecondary = Color(0xFF77847C);

  // Semantic Status Colors
  static const Color statusSuccess = Color(0xFF22C55E); // Còn hạn / Đã hoàn thành
  static const Color statusSuccessTint = Color(0xFFE7FAEE);
  static const Color statusWarning = Color(0xFFF59E0B); // Sắp hết hạn / sắp hết số lượng
  static const Color statusWarningTint = Color(0xFFFEF5E2);
  static const Color statusDanger = Color(0xFFEF4444);  // Đã hết hạn / Lỗi
  static const Color statusDangerTint = Color(0xFFFEECEC);
  static const Color statusPlanned = Color(0xFF2563EB); // Đã lên lịch · Chưa trừ kho
  static const Color statusPlannedTint = Color(0xFFEFF6FF);

  // Corner Radii Constants
  static const double radiusBadge = 8.0;
  static const double radiusInput = 12.0;
  static const double radiusCard = 16.0;
  static const double radiusModal = 24.0;
}

