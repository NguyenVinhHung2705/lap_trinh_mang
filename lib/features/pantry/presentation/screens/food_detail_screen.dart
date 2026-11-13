import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/food_item.dart';
import '../../data/models/food_batch.dart';
import '../providers/pantry_providers.dart';
import '../../shared/pantry_colors.dart';
import '../widgets/batch_item_tile.dart';

class FoodDetailScreen extends ConsumerWidget {
  const FoodDetailScreen({
    super.key,
    required this.food,
  });

  final FoodItem food;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(pantryRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          food.name,
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: StreamBuilder<List<FoodBatch>>(
        stream: repo.watchBatchesForFood('mock_user_nguyen_van_dinh', food.id),
        builder: (context, snapshot) {
          final batches = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thẻ thông tin tổng quan
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tổng tồn kho:', style: TextStyle(color: AppColors.textSecondary)),
                          Text(
                            '${food.totalStock} ${food.baseUnit}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: AppColors.border),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Danh mục:', style: TextStyle(color: AppColors.textSecondary)),
                          Text(food.categoryName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ngưỡng cảnh báo sắp hết:', style: TextStyle(color: AppColors.textSecondary)),
                          Text('${food.minimumStock} ${food.baseUnit}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Danh sách lô (FEFO: Lô cận date nhất ở trên cùng)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Danh sách các lô hàng (FEFO)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      '${batches.length} lô',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (batches.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: Text('Hiện không còn lô nào trong kho', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  )
                else
                  ...batches.map(
                    (batch) => BatchItemTile(
                      batch: batch,
                      onDiscard: () {
                        repo.discardBatch(
                          userId: 'mock_user_nguyen_van_dinh',
                          batchId: batch.id,
                          reason: 'Người dùng hủy lô khỏi kho',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã hủy lô ${batch.quantity} ${batch.unit}')),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
