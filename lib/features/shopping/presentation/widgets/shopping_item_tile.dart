import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/models/shopping_item.dart';

/// Tile displaying an item inside the shopping list detail screen.
class ShoppingItemTile extends StatelessWidget {
  const ShoppingItemTile({
    super.key,
    required this.item,
    required this.onToggleBought,
    required this.onEdit,
    required this.onDelete,
  });

  final ShoppingItem item;
  final ValueChanged<bool> onToggleBought;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isSynced = item.isSynced;
    final isBought = item.isBought;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusInput),
        border: Border.all(
          color: isSynced
              ? AppColors.statusSuccess.withOpacity(0.3)
              : (isBought ? AppColors.primary.withOpacity(0.3) : AppColors.border),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Checkbox
            Transform.scale(
              scale: 1.1,
              child: Checkbox(
                value: isBought || isSynced,
                onChanged: isSynced ? null : (val) => onToggleBought(val ?? false),
                activeColor: isSynced ? AppColors.statusSuccess : AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Item Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.foodName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isSynced
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            decoration: isSynced ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildSyncBadge(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Cần: ${item.plannedQuantity} ${item.unitName}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (item.actualQuantity > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '· Thực mua: ${item.actualQuantity} ${item.unitName}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSynced
                                ? AppColors.statusSuccess
                                : AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.categoryName != null && item.categoryName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius:
                              BorderRadius.circular(AppColors.radiusBadge),
                        ),
                        child: Text(
                          item.categoryName!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Actions (only if unsynced)
            if (!isSynced) ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: AppColors.textSecondary,
                tooltip: 'Sửa mục',
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppColors.statusDanger,
                tooltip: 'Xóa mục',
                onPressed: onDelete,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSyncBadge() {
    if (item.isSynced) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.statusSuccessTint,
          borderRadius: BorderRadius.circular(AppColors.radiusBadge),
        ),
        child: const Text(
          'Đã nhập kho',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.statusSuccess,
          ),
        ),
      );
    }
    if (item.isBought) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(AppColors.radiusBadge),
        ),
        child: const Text(
          'Đã mua',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

