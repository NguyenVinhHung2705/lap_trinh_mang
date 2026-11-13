import 'package:flutter/material.dart';
import '../../data/models/food_item.dart';
import '../../data/models/food_batch.dart';
import '../../shared/pantry_colors.dart';

class FoodCard extends StatelessWidget {
  const FoodCard({
    super.key,
    required this.food,
    this.onTap,
    this.onAddBatch,
  });

  final FoodItem food;
  final VoidCallback? onTap;
  final VoidCallback? onAddBatch;

  @override
  Widget build(BuildContext context) {
    Color badgeBg;
    Color badgeText;
    String badgeLabel;

    switch (food.expiryStatus) {
      case ExpiryStatus.expired:
        badgeBg = AppColors.statusDangerTint;
        badgeText = AppColors.statusDanger;
        badgeLabel = 'Đã hết hạn';
        break;
      case ExpiryStatus.warning:
        badgeBg = AppColors.statusWarningTint;
        badgeText = AppColors.statusWarning;
        badgeLabel = 'Sắp hết hạn';
        break;
      case ExpiryStatus.good:
        badgeBg = AppColors.statusSuccessTint;
        badgeText = AppColors.statusSuccess;
        badgeLabel = 'Còn hạn';
        break;
    }

    return Card(
      color: AppColors.surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon thực phẩm
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.fastfood_outlined, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),

              // Thông tin thực phẩm
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            food.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeLabel,
                            style: TextStyle(
                              color: badgeText,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Danh mục: ${food.categoryName}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                            children: [
                              const TextSpan(text: 'Tồn kho: '),
                              TextSpan(
                                text: '${food.totalStock} ${food.baseUnit}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                        if (food.isLowStock) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.statusWarningTint,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Sắp hết',
                              style: TextStyle(fontSize: 10, color: AppColors.statusWarning, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
