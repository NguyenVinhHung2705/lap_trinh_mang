import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/models/shopping_item.dart';
import '../../data/models/shopping_list.dart';
import '../providers/shopping_providers.dart';
import '../widgets/shopping_item_tile.dart';
import '../widgets/shopping_progress_bar.dart';
import 'add_edit_shopping_item_screen.dart';
import 'low_stock_suggestions_screen.dart';
import 'recipe_shortage_import_screen.dart';
import 'shopping_mode_screen.dart';
import 'shopping_sync_screen.dart';

/// Detail screen for a specific shopping list (MOD-02-02).
///
/// Provides access to:
/// - Manual item addition & editing (MOD-02-02)
/// - Importing shortages from recipes (MOD-02-03)
/// - Importing low stock suggestions (MOD-02-04)
/// - In-store shopping mode (MOD-02-05)
/// - Pantry synchronization (MOD-02-08)
class ShoppingDetailScreen extends ConsumerStatefulWidget {
  const ShoppingDetailScreen({
    super.key,
    required this.userId,
    required this.listId,
  });

  final String userId;
  final String listId;

  @override
  ConsumerState<ShoppingDetailScreen> createState() =>
      _ShoppingDetailScreenState();
}

class _ShoppingDetailScreenState extends ConsumerState<ShoppingDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(
      shoppingItemsStreamProvider((userId: widget.userId, listId: widget.listId)),
    );

    // Watch shopping lists to get parent list metadata
    final listsAsync = ref.watch(shoppingListsStreamProvider(widget.userId));

    final parentList = listsAsync.value?.firstWhere(
      (l) => l.id == widget.listId,
      orElse: () => ShoppingList(
        id: widget.listId,
        userId: widget.userId,
        name: 'Chi tiết mua sắm',
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          parentList?.name ?? 'Chi tiết danh sách',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_outlined, color: AppColors.primary),
            tooltip: 'Gợi ý sắp hết',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LowStockSuggestionsScreen(
                    userId: widget.userId,
                    listId: widget.listId,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.restaurant_menu_outlined,
                color: AppColors.primary),
            tooltip: 'Thiếu từ công thức',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RecipeShortageImportScreen(
                    userId: widget.userId,
                    listId: widget.listId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: itemsAsync.when(
        data: (items) => _buildContent(context, parentList, items),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Lỗi tải mục mua sắm: $err',
              style: const TextStyle(color: AppColors.statusDanger),
            ),
          ),
        ),
      ),
      bottomNavigationBar: itemsAsync.maybeWhen(
        data: (items) => _buildBottomBar(context, items),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ShoppingList? list,
    List<ShoppingItem> items,
  ) {
    final boughtCount = items.where((it) => it.isBought || it.isSynced).length;
    final syncedCount = items.where((it) => it.isSynced).length;

    return CustomScrollView(
      slivers: [
        // Header Summary Card
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppColors.radiusCard),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShoppingProgressBar(
                  boughtCount: boughtCount,
                  totalCount: items.length,
                  syncedCount: syncedCount,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildShortcutPill(
                      icon: Icons.add,
                      label: 'Thêm mục',
                      onTap: () => _openAddEditItemScreen(context),
                    ),
                    _buildShortcutPill(
                      icon: Icons.receipt_long_outlined,
                      label: 'Từ công thức',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RecipeShortageImportScreen(
                              userId: widget.userId,
                              listId: widget.listId,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildShortcutPill(
                      icon: Icons.trending_down_outlined,
                      label: 'Gợi ý sắp hết',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LowStockSuggestionsScreen(
                              userId: widget.userId,
                              listId: widget.listId,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Items List or Empty View
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shopping_basket_outlined,
                      size: 56,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Danh sách mua đang trống',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Thêm thực phẩm cần mua hoặc nhận gợi ý từ công thức nấu ăn.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => _openAddEditItemScreen(context),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Thêm thực phẩm',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppColors.radiusInput),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = items[index];
                  return ShoppingItemTile(
                    item: item,
                    onToggleBought: (isBought) {
                      ref.read(shoppingServiceProvider).toggleItemBought(
                            userId: widget.userId,
                            listId: widget.listId,
                            itemId: item.id,
                            isBought: isBought,
                          );
                    },
                    onEdit: () =>
                        _openAddEditItemScreen(context, item: item),
                    onDelete: () => _confirmDeleteItem(context, item),
                  );
                },
                childCount: items.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildShortcutPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusBadge),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(AppColors.radiusBadge),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primaryDark),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, List<ShoppingItem> items) {
    final boughtUnsyncedCount =
        items.where((it) => it.isBought && !it.isSynced).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Shopping Mode Button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ShoppingModeScreen(
                      userId: widget.userId,
                      listId: widget.listId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.shopping_cart_checkout,
                  color: AppColors.primary),
              label: const Text(
                'Đi mua ngay',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusInput),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Pantry Sync Button (MOD-02-08)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: boughtUnsyncedCount > 0
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ShoppingSyncScreen(
                            userId: widget.userId,
                            listId: widget.listId,
                          ),
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.archive_outlined, color: Colors.white),
              label: Text(
                'Nhập kho ($boughtUnsyncedCount)',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.border,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusInput),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openAddEditItemScreen(BuildContext context, {ShoppingItem? item}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditShoppingItemScreen(
          userId: widget.userId,
          listId: widget.listId,
          editingItem: item,
        ),
      ),
    );
  }

  void _confirmDeleteItem(BuildContext context, ShoppingItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusModal),
        ),
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa "${item.foodName}" khỏi danh sách?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(shoppingRepositoryProvider).removeItem(
                    userId: widget.userId,
                    listId: widget.listId,
                    itemId: item.id,
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusDanger,
            ),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

