import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/pantry_providers.dart';
import '../../shared/pantry_colors.dart';
import '../../data/models/stock_movement.dart';

class StockMovementHistoryScreen extends ConsumerWidget {
  const StockMovementHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(stockMovementsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Lịch sử biến động kho',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: movementsAsync.when(
        data: (movements) {
          if (movements.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có lịch sử biến động kho nào',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: movements.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final mov = movements[index];
              final isOut = mov.outQuantity > 0;
              final qtyText =
                  isOut ? '-${mov.outQuantity}' : '+${mov.inQuantity}';

              Color accentColor;
              IconData iconData;
              switch (mov.type) {
                case StockMovementType.inStock:
                  accentColor = AppColors.statusSuccess;
                  iconData = Icons.south_west_rounded;
                  break;
                case StockMovementType.consume:
                  accentColor = AppColors.statusPlanned;
                  iconData = Icons.restaurant_rounded;
                  break;
                case StockMovementType.adjust:
                  accentColor = AppColors.statusWarning;
                  iconData = Icons.tune_rounded;
                  break;
                case StockMovementType.expired:
                  accentColor = AppColors.statusDanger;
                  iconData = Icons.event_busy_rounded;
                  break;
                case StockMovementType.discard:
                  accentColor = AppColors.statusDanger;
                  iconData = Icons.delete_outline_rounded;
                  break;
              }

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(iconData, color: accentColor, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mov.foodName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            mov.type.labelVi +
                                (mov.note != null && mov.note!.trim().isNotEmpty
                                    ? ' • ${mov.note}'
                                    : ''),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${mov.timestamp.hour.toString().padLeft(2, '0')}:${mov.timestamp.minute.toString().padLeft(2, '0')} ngày ${mov.timestamp.day}/${mov.timestamp.month}/${mov.timestamp.year}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      qtyText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isOut
                            ? AppColors.statusDanger
                            : AppColors.statusSuccess,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
      ),
    );
  }
}
