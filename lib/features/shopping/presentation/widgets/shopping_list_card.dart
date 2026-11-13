import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/models/shopping_list.dart';
import 'shopping_progress_bar.dart';

/// Card widget representing a shopping list on the overview screen.
class ShoppingListCard extends StatelessWidget {
  const ShoppingListCard({
    super.key,
    required this.list,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final ShoppingList list;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isCompleted = list.isCompleted;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        side: BorderSide(
          color: isCompleted ? AppColors.border : AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.background
                          : AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isCompleted
                          ? Icons.check_circle_outline
                          : Icons.shopping_bag_outlined,
                      color: isCompleted
                          ? AppColors.textSecondary
                          : AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          list.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(list.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(list.status),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                    onSelected: (val) {
                      if (val == 'rename') onRename();
                      if (val == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Đổi tên'),
                          ],
                        ),
                      ),
                      if (!isCompleted)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 18, color: AppColors.statusDanger),
                              SizedBox(width: 8),
                              Text('Xóa danh sách',
                                  style: TextStyle(color: AppColors.statusDanger)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ShoppingProgressBar(
                boughtCount: list.boughtItems,
                totalCount: list.totalItems,
                syncedCount: list.syncedItems,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ShoppingListStatus status) {
    Color bg;
    Color fg;
    switch (status) {
      case ShoppingListStatus.completed:
        bg = AppColors.statusSuccessTint;
        fg = AppColors.statusSuccess;
        break;
      case ShoppingListStatus.open:
        bg = AppColors.primaryTint;
        fg = AppColors.primaryDark;
        break;
      case ShoppingListStatus.cancelled:
        bg = AppColors.statusDangerTint;
        fg = AppColors.statusDanger;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppColors.radiusBadge),
      ),
      child: Text(
        status.labelVi,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return 'Tạo lúc ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

