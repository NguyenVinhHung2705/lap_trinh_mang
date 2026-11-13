import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

/// Clean progress bar showing shopping trip completion.
class ShoppingProgressBar extends StatelessWidget {
  const ShoppingProgressBar({
    super.key,
    required this.boughtCount,
    required this.totalCount,
    this.syncedCount = 0,
    this.showLabels = true,
  });

  final int boughtCount;
  final int totalCount;
  final int syncedCount;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final ratio = totalCount > 0 ? (boughtCount / totalCount).clamp(0.0, 1.0) : 0.0;
    final percent = (ratio * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabels) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tiến độ mua: $boughtCount/$totalCount món ($percent%)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (syncedCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(AppColors.radiusBadge),
                  ),
                  child: Text(
                    'Đã nhập kho $syncedCount món',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(
              ratio >= 1.0 ? AppColors.statusSuccess : AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

