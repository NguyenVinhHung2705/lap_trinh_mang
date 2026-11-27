import 'package:flutter/material.dart';
import '../../data/models/food_batch.dart';
import '../../shared/pantry_colors.dart';

class BatchItemTile extends StatelessWidget {
  const BatchItemTile({
    super.key,
    required this.batch,
    this.onMoveLocation,
    this.onAdjustQuantity,
    this.onDiscard,
  });

  final FoodBatch batch;
  final VoidCallback? onMoveLocation;
  final VoidCallback? onAdjustQuantity;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    Color statusTint;
    String statusBadge;

    if (batch.daysRemaining < 0) {
      statusColor = AppColors.statusDanger;
      statusTint = AppColors.statusDangerTint;
      statusBadge = 'Quá hạn ${batch.daysRemaining.abs()} ngày';
    } else if (batch.daysRemaining == 0) {
      statusColor = AppColors.statusWarning;
      statusTint = AppColors.statusWarningTint;
      statusBadge = 'Hết hạn hôm nay';
    } else if (batch.daysRemaining <= 3) {
      statusColor = AppColors.statusWarning;
      statusTint = AppColors.statusWarningTint;
      statusBadge = 'Còn ${batch.daysRemaining} ngày';
    } else {
      statusColor = AppColors.statusSuccess;
      statusTint = AppColors.statusSuccessTint;
      statusBadge = 'Còn ${batch.daysRemaining} ngày';
    }

    final impStr =
        '${batch.importDate.day.toString().padLeft(2, '0')}/${batch.importDate.month.toString().padLeft(2, '0')}/${batch.importDate.year}';
    final expStr =
        '${batch.expiryDate.day.toString().padLeft(2, '0')}/${batch.expiryDate.month.toString().padLeft(2, '0')}/${batch.expiryDate.year}';

    final actionButtons = <Widget>[
      if (onMoveLocation != null)
        Expanded(
          child: _ActionPill(
            icon: Icons.drive_file_move_outline,
            label: 'Đổi vị trí',
            color: AppColors.primaryDark,
            bgColor: AppColors.primaryTint,
            borderColor: AppColors.primary.withOpacity(0.25),
            onTap: onMoveLocation!,
          ),
        ),
      if (onAdjustQuantity != null)
        Expanded(
          child: _ActionPill(
            icon: Icons.tune_rounded,
            label: 'Điều chỉnh SL',
            color: AppColors.statusPlanned,
            bgColor: AppColors.statusPlannedTint,
            borderColor: AppColors.statusPlanned.withOpacity(0.25),
            onTap: onAdjustQuantity!,
          ),
        ),
      if (onDiscard != null)
        Expanded(
          child: _ActionPill(
            icon: Icons.delete_outline,
            label: batch.daysRemaining < 0 ? 'Hủy quá hạn' : 'Loại bỏ lô',
            color: AppColors.statusDanger,
            bgColor: AppColors.statusDangerTint,
            borderColor: AppColors.statusDanger.withOpacity(0.25),
            onTap: onDiscard!,
          ),
        ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dải màu nhấn trạng thái bên trái thẻ lô
            Container(width: 4.5, color: statusColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: statusTint,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: statusColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${batch.quantity} ${batch.unit}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.place_outlined,
                                            size: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              batch.locationName,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Nhập: $impStr  •  HSD: $expStr',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusTint,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusBadge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (actionButtons.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: AppColors.border),
                      ),
                      // 3 nút chia đều 3 cột bằng nhau 100% từ trái sang phải
                      Row(
                        children: [
                          for (var i = 0; i < actionButtons.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            actionButtons[i],
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
