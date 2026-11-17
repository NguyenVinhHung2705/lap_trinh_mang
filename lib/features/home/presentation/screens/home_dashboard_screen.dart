import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../auth/auth_module.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../meal_plan/data/models/meal.dart';
import '../../../meal_plan/presentation/providers/meal_calendar_provider.dart'
    hide currentUserIdProvider;
import '../../../pantry/data/models/food_batch.dart';
import '../../../pantry/presentation/providers/pantry_providers.dart';
import '../../../pantry/presentation/screens/add_batch_screen.dart';
import '../../../pantry/presentation/widgets/barcode_scanner_dialog.dart';
import '../../../recipe/presentation/screens/recipe_editor_screen.dart';
import '../../../shopping/presentation/providers/shopping_providers.dart';

/// Màn hình Trang chủ (Dashboard tổng quan) - Hub trung tâm kết nối 5 phân hệ.
///
/// Tuân thủ Design System trong `UI_imgs/DESIGN_PREVIEW.md` (mục 2.2).
class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({
    super.key,
    required this.onNavigateTab,
  });

  /// Callback chuyển tab điều hướng:
  /// 0: Trang chủ, 1: Kho, 2: Mua sắm, 3: Công thức, 4: Kế hoạch
  final void Function(int tabIndex) onNavigateTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final isLocal = user == null;
    final displayName = user?.displayName ??
        (user?.email != null ? user!.email!.split('@').first : 'Khách (Local)');
    final userId = user?.uid ?? 'mock_user_nguyen_van_dinh';

    // Dữ liệu từ các Module
    final foodsAsync = ref.watch(pantryFoodsStreamProvider);
    final foods = foodsAsync.value ?? [];

    final expiringBatchesAsync = ref.watch(expiringBatchesStreamProvider);
    final expiringBatches = expiringBatchesAsync.value ?? [];
    final urgentBatches = expiringBatches.where((b) => b.daysRemaining <= 3).toList();

    final shoppingListsAsync = ref.watch(shoppingListsStreamProvider(userId));
    final shoppingLists = shoppingListsAsync.value ?? [];

    final mealsAsync = ref.watch(mealsInRangeProvider);
    final allMeals = mealsAsync.value ?? [];
    final now = DateTime.now();
    final todayKey = Meal.formatLocalDate(now);
    final todayMeals = allMeals.where((m) => Meal.formatLocalDate(m.mealDate) == todayKey).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.eco, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'Smart Food Life',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 19,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: AppColors.textPrimary),
            tooltip: 'Thông báo',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chức năng thông báo đang được kích hoạt.')),
              );
            },
          ),
          IconButton(
            icon: CircleAvatar(
              radius: 15,
              backgroundColor: isLocal ? AppColors.statusWarningTint : AppColors.primaryTint,
              child: isLocal
                  ? const Icon(Icons.person_pin, size: 18, color: AppColors.statusWarning)
                  : Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
            tooltip: isLocal ? 'Tài khoản Local - Chạm để đăng nhập' : 'Tài khoản ($displayName)',
            onPressed: () => AuthModule.openProfile(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pantryFoodsStreamProvider);
          ref.invalidate(expiringBatchesStreamProvider);
          ref.invalidate(shoppingListsStreamProvider(userId));
          ref.invalidate(mealsInRangeProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Lời chào & Thanh tìm kiếm
              _buildGreetingHeader(displayName),
              const SizedBox(height: 16),
              _buildSearchBar(context, ref),
              const SizedBox(height: 20),

              // 2. 4 Summary Cards (2x2 Grid)
              _buildSectionTitle('Tổng quan hôm nay'),
              const SizedBox(height: 12),
              _buildSummaryGrid(
                ref: ref,
                foodCount: foods.length,
                urgentCount: urgentBatches.length,
                shoppingCount: shoppingLists.length,
                mealCount: todayMeals.length,
              ),
              const SizedBox(height: 24),

              // 3. Thao tác nhanh (Quick Actions)
              _buildSectionTitle('Thao tác nhanh'),
              const SizedBox(height: 12),
              _buildQuickActions(context),
              const SizedBox(height: 24),

              // 4. Thực phẩm sắp hết hạn ưu tiên (MOD-01)
              _buildExpiringSection(urgentBatches),
              const SizedBox(height: 24),

              // 5. Bữa ăn hôm nay (MOD-04)
              _buildTodayMealsSection(todayMeals),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingHeader(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Xin chào, $name! 👋',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Hôm nay bạn muốn nấu món gì hay kiểm tra thực phẩm?',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusInput),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => onNavigateTab(1), // Mở Kho thực phẩm để tìm
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Bạn đang tìm thực phẩm hay công thức?',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary, size: 22),
            tooltip: 'Quét mã vạch',
            onPressed: () {
              BarcodeScannerDialog.show(
                context,
                onScanned: (barcode, name) {
                  ref.read(pantrySearchQueryProvider.notifier).state = name;
                  onNavigateTab(1);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã nhận diện: $barcode ($name)')),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {VoidCallback? onAction, String? actionText}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        if (onAction != null && actionText != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(50, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionText,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryGrid({
    required WidgetRef ref,
    required int foodCount,
    required int urgentCount,
    required int shoppingCount,
    required int mealCount,
  }) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          title: 'Kho thực phẩm',
          value: '$foodCount',
          subtitle: 'Mặt hàng trong kho',
          icon: Icons.kitchen,
          color: AppColors.primary,
          tintColor: AppColors.primaryTint,
          onTap: () => onNavigateTab(1),
        ),
        _buildStatCard(
          title: 'Sắp hết hạn',
          value: '$urgentCount',
          subtitle: urgentCount > 0 ? 'Ưu tiên dùng ngay' : 'Đang an toàn',
          icon: Icons.warning_amber_rounded,
          color: AppColors.statusWarning,
          tintColor: AppColors.statusWarningTint,
          onTap: () {
            ref.read(selectedExpiryFilterProvider.notifier).state = 'Sắp hết hạn';
            onNavigateTab(1);
          },
        ),
        _buildStatCard(
          title: 'Mua sắm',
          value: '$shoppingCount',
          subtitle: 'Danh sách mua',
          icon: Icons.shopping_cart_outlined,
          color: const Color(0xFF2563EB),
          tintColor: const Color(0xFFEFF6FF),
          onTap: () => onNavigateTab(2),
        ),
        _buildStatCard(
          title: 'Bữa ăn hôm nay',
          value: '$mealCount',
          subtitle: 'Bữa đã lên lịch',
          icon: Icons.calendar_month_outlined,
          color: const Color(0xFF7C3AED),
          tintColor: const Color(0xFFF5F3FF),
          onTap: () => onNavigateTab(4),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color tintColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: tintColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionBtn(
            icon: Icons.add_circle_outline,
            label: 'Thêm kho',
            color: AppColors.primary,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddBatchScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionBtn(
            icon: Icons.playlist_add,
            label: 'Tạo DS mua',
            color: const Color(0xFF2563EB),
            onTap: () => onNavigateTab(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionBtn(
            icon: Icons.menu_book,
            label: 'Tạo món',
            color: const Color(0xFFD97706),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RecipeEditorScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionBtn(
            icon: Icons.calendar_today,
            label: 'Lên lịch',
            color: const Color(0xFF7C3AED),
            onTap: () => onNavigateTab(4),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusInput),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppColors.radiusInput),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiringSection(List<FoodBatch> urgentBatches) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Thực phẩm sắp hết hạn',
          actionText: 'Xem tất cả',
          onAction: () => onNavigateTab(1),
        ),
        const SizedBox(height: 12),
        if (urgentBatches.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppColors.radiusCard),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: AppColors.statusSuccess, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tuyệt vời! Không có thực phẩm nào sắp hết hạn trong 3 ngày tới.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: urgentBatches.take(3).length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final batch = urgentBatches[index];
              final isExpired = batch.daysRemaining < 0;
              final statusColor = isExpired ? AppColors.statusDanger : AppColors.statusWarning;
              final statusTint = isExpired ? AppColors.statusDangerTint : AppColors.statusWarningTint;

              return InkWell(
                onTap: () => onNavigateTab(1),
                borderRadius: BorderRadius.circular(AppColors.radiusCard),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppColors.radiusCard),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusTint,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.access_time_filled, color: statusColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              batch.foodName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${batch.locationName} · ${batch.quantity} ${batch.unit}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusTint,
                          borderRadius: BorderRadius.circular(AppColors.radiusBadge),
                        ),
                        child: Text(
                          isExpired ? 'Đã hết hạn' : 'Còn ${batch.daysRemaining} ngày',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTodayMealsSection(List<Meal> todayMeals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Bữa ăn hôm nay',
          actionText: 'Xem lịch',
          onAction: () => onNavigateTab(4),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildMealSlotCard('Sáng', MealSlot.breakfast, todayMeals),
            const SizedBox(width: 8),
            _buildMealSlotCard('Trưa', MealSlot.lunch, todayMeals),
            const SizedBox(width: 8),
            _buildMealSlotCard('Tối', MealSlot.dinner, todayMeals),
          ],
        ),
      ],
    );
  }

  Widget _buildMealSlotCard(String slotName, MealSlot slot, List<Meal> meals) {
    final meal = meals.cast<Meal?>().firstWhere(
          (m) => m?.slot == slot,
          orElse: () => null,
        );

    final isPlanned = meal != null;
    final isDone = meal?.status == MealStatus.completed;

    Color badgeColor = AppColors.textSecondary;
    Color badgeTint = AppColors.border;
    String statusLabel = 'Chưa lên lịch';

    if (isDone) {
      badgeColor = AppColors.statusSuccess;
      badgeTint = AppColors.statusSuccessTint;
      statusLabel = 'Đã hoàn thành';
    } else if (isPlanned) {
      badgeColor = AppColors.statusPlanned;
      badgeTint = AppColors.statusPlannedTint;
      statusLabel = 'Đã lên lịch';
    }

    return Expanded(
      child: InkWell(
        onTap: () => onNavigateTab(4),
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppColors.radiusCard),
            border: Border.all(
              color: isPlanned ? AppColors.primary.withOpacity(0.3) : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slotName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isPlanned
                    ? (meal.reminderAt != null
                        ? 'Nhắc: ${meal.reminderAt!.hour.toString().padLeft(2, '0')}:${meal.reminderAt!.minute.toString().padLeft(2, '0')}'
                        : 'Bữa ăn đã lên lịch')
                    : '—',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeTint,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
