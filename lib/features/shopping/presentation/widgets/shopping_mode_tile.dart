import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/models/shopping_item.dart';

/// Touch-friendly tile designed for supermarket in-store shopping mode (MOD-02-05 & MOD-02-06).
class ShoppingModeTile extends StatelessWidget {
  const ShoppingModeTile({
    super.key,
    required this.item,
    required this.onToggleBought,
    required this.onQuantityChanged,
    required this.onEditDetails,
  });

  final ShoppingItem item;
  final ValueChanged<bool> onToggleBought;
  final ValueChanged<double> onQuantityChanged;
  final VoidCallback onEditDetails;

  @override
  Widget build(BuildContext context) {
    final isBought = item.isBought;
    final isSynced = item.isSynced;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isBought
            ? (isSynced ? AppColors.background : AppColors.primaryTint.withOpacity(0.5))
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        border: Border.all(
          color: isBought ? AppColors.primary : AppColors.border,
          width: isBought ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // Checkbox touch area
                InkWell(
                  onTap: isSynced ? null : () => onToggleBought(!isBought),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      isBought || isSynced
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: isSynced
                          ? AppColors.textSecondary
                          : (isBought ? AppColors.primary : AppColors.textSecondary),
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Title & Category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.foodName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isBought
                              ? AppColors.textPrimary
                              : AppColors.textPrimary,
                          decoration: isSynced ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'Cần: ${item.plannedQuantity} ${item.unitName}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (item.categoryName != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '· ${item.categoryName}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Edit details button (for HSD & Location)
                if (!isSynced)
                  IconButton(
                    icon: Icon(
                      item.isReadyForSync
                          ? Icons.check_circle_outline
                          : Icons.add_alarm_outlined,
                      color: item.isReadyForSync
                          ? AppColors.statusSuccess
                          : AppColors.statusWarning,
                      size: 22,
                    ),
                    tooltip: 'Hạn dùng & Vị trí',
                    onPressed: onEditDetails,
                  ),
              ],
            ),

            // Actual Quantity Controller when item is bought
            if (isBought && !isSynced) ...[
              const Divider(height: 16, color: AppColors.border),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Số lượng thực mua:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      _buildQuickButton(
                        icon: Icons.remove,
                        onPressed: () {
                          final current = item.actualQuantity > 0
                              ? item.actualQuantity
                              : item.plannedQuantity;
                          if (current > 1) {
                            onQuantityChanged(current - 1);
                          } else if (current > 0.1) {
                            onQuantityChanged(
                              double.parse((current - 0.1).toStringAsFixed(1)),
                            );
                          }
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppColors.radiusBadge),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '${item.actualQuantity > 0 ? item.actualQuantity : item.plannedQuantity} ${item.unitName}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      _buildQuickButton(
                        icon: Icons.add,
                        onPressed: () {
                          final current = item.actualQuantity > 0
                              ? item.actualQuantity
                              : item.plannedQuantity;
                          onQuantityChanged(current + 1);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 16, color: AppColors.textPrimary),
      ),
    );
  }
}

