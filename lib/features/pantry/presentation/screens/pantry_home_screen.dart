import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pantry_providers.dart';
import '../widgets/food_card.dart';
import 'food_detail_screen.dart';
import 'add_batch_screen.dart';
import 'stock_movement_screen.dart';
import '../../shared/pantry_colors.dart';

class PantryHomeScreen extends ConsumerStatefulWidget {
  const PantryHomeScreen({super.key});

  @override
  ConsumerState<PantryHomeScreen> createState() => _PantryHomeScreenState();
}

class _PantryHomeScreenState extends ConsumerState<PantryHomeScreen> {
  final _searchController = TextEditingController();

  final List<String> _categories = [
    'Tất cả',
    'Rau củ',
    'Thịt cá',
    'Đồ uống',
    'Gia vị',
    'Trứng',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFoods = ref.watch(filteredFoodsProvider);
    final selectedCategory = ref.watch(selectedCategoryFilterProvider);
    final selectedExpiry = ref.watch(selectedExpiryFilterProvider);
    final expiringBatches = ref.watch(expiringBatchesStreamProvider).value ?? [];

    // Đếm số lượng thực phẩm sắp hết hạn và đã hết hạn
    final urgentCount = expiringBatches.where((b) => b.daysRemaining <= 3).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Kho Thực Phẩm (MOD-01)',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.primary),
            tooltip: 'Biến động kho',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StockMovementHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Thanh tìm kiếm
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                ref.read(pantrySearchQueryProvider.notifier).state = val;
              },
              decoration: InputDecoration(
                hintText: 'Tìm thực phẩm trong kho...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 2. Banner cảnh báo nếu có thực phẩm sắp/đã hết hạn (Theo thiết kế Dashboard)
          if (urgentCount > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.statusWarningTint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.statusWarning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.statusWarning, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Có $urgentCount lô thực phẩm cần ưu tiên dùng (sắp/đã hết hạn)!',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 3. Thanh lọc Danh mục (Horizontal Scroll Chips)
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = cat == selectedCategory;

                  return FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (val) {
                      ref.read(selectedCategoryFilterProvider.notifier).state = cat;
                    },
                    selectedColor: AppColors.primaryTint,
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    backgroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // 4. Danh sách thực phẩm
          Expanded(
            child: filteredFoods.isEmpty
                ? const Center(
                    child: Text(
                      'Không tìm thấy thực phẩm nào phù hợp',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredFoods.length,
                    itemBuilder: (context, index) {
                      final food = filteredFoods[index];
                      return FoodCard(
                        food: food,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FoodDetailScreen(food: food),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add),
        label: const Text('Nhập kho', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddBatchScreen()),
          );
        },
      ),
    );
  }
}
