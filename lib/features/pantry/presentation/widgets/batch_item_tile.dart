import 'package:flutter/material.dart';
import '../../data/models/food_batch.dart';
import '../../shared/pantry_colors.dart';

class BatchItemTile extends StatelessWidget {
  const BatchItemTile({
    super.key,
    required this.batch,
    this.onDiscard,
  });

  final FoodBatch batch;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;

    if (batch.daysRemaining < 0) {
      statusColor = AppColors.statusDanger;
      statusText = 'Đã hết hạn (${batch.daysRemaining.abs()} ngày trước)';
    } else if (batch.daysRemaining == 0) {
      statusColor = AppColors.statusWarning;
      statusText = 'Hết hạn hôm nay!';
    } else if (batch.daysRemaining <= 3) {
      statusColor = AppColors.statusWarning;
      statusText = 'Còn ${batch.daysRemaining} ngày';
    } else {
      statusColor = AppColors.statusSuccess;
      statusText = 'Còn ${batch.daysRemaining} ngày';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.inventory_2_outlined, color: statusColor, size: 20),
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${batch.locationName}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'HSD: ${batch.expiryDate.day}/${batch.expiryDate.month}/${batch.expiryDate.year} ($statusText)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                ),
              ],
            ),
          ),
          if (onDiscard != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.statusDanger, size: 20),
              tooltip: 'Hủy lô',
              onPressed: onDiscard,
            ),
        ],
      ),
    );
  }
}
