import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/models/shopping_list.dart';
import '../providers/shopping_providers.dart';
import '../widgets/shopping_list_card.dart';
import 'shopping_detail_screen.dart';

/// Primary overview screen for MOD-02 (MOD-02-01 / FR-09).
///
/// Displays user shopping lists, summary cards, filter tabs, and creation dialog.
class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({
    super.key,
    this.userId,
    this.onSelectList,
  });

  /// Optional injected userId (defaults to FirebaseAuth.instance.currentUser?.uid).
  final String? userId;

  /// Optional callback when user taps a list.
  final ValueChanged<ShoppingList>? onSelectList;

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String get _currentUserId {
    return widget.userId ??
        FirebaseAuth.instance.currentUser?.uid ??
        'test_user_id';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = _currentUserId;
    final listsAsync = ref.watch(shoppingListsStreamProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Danh sách Mua sắm',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Tất cả'),
            Tab(text: 'Đang mở'),
            Tab(text: 'Đã hoàn tất'),
          ],
        ),
      ),
      body: listsAsync.when(
        data: (lists) => _buildBody(context, lists),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.statusDanger),
                const SizedBox(height: 12),
                Text(
                  'Không thể tải danh sách mua sắm: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.refresh(shoppingListsStreamProvider(userId)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Thử lại',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateListDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Tạo danh sách mới',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<ShoppingList> lists) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildListTab(context, lists),
        _buildListTab(
          context,
          lists.where((l) => l.isOpen).toList(),
          emptyMessage: 'Chưa có chuyến mua sắm nào đang mở.',
        ),
        _buildListTab(
          context,
          lists.where((l) => l.isCompleted).toList(),
          emptyMessage: 'Chưa có chuyến mua sắm nào đã hoàn tất.',
        ),
      ],
    );
  }

  Widget _buildListTab(
    BuildContext context,
    List<ShoppingList> filteredLists, {
    String emptyMessage = 'Bạn chưa có danh sách mua sắm nào.',
  }) {
    if (filteredLists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tạo danh sách mua hoặc nhận gợi ý từ tủ lạnh và thực đơn nấu ăn.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _showCreateListDialog(context),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Tạo ngay',
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
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: filteredLists.length,
      itemBuilder: (context, index) {
        final list = filteredLists[index];
        return ShoppingListCard(
          list: list,
          onTap: () {
            if (widget.onSelectList != null) {
              widget.onSelectList!(list);
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ShoppingDetailScreen(
                    userId: _currentUserId,
                    listId: list.id,
                  ),
                ),
              );
            }
          },
          onRename: () => _showRenameDialog(context, list),
          onDelete: () => _showDeleteConfirmDialog(context, list),
        );
      },
    );
  }

  void _showCreateListDialog(BuildContext context) {
    final controller = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusModal),
        ),
        title: const Text(
          'Tạo danh sách mua sắm',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Tên danh sách *',
                hintText: 'Ví dụ: Đi siêu thị cuối tuần',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusInput),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: 'Ghi chú (tùy chọn)',
                hintText: 'Ví dụ: Mua cho cả tuần tới',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusInput),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              Navigator.of(ctx).pop();
              final created = await ref
                  .read(shoppingListControllerProvider.notifier)
                  .createList(
                    userId: _currentUserId,
                    name: name,
                    note: noteController.text.trim(),
                  );

              if (created != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã tạo danh sách "${created.name}"'),
                    backgroundColor: AppColors.statusSuccess,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusInput),
              ),
            ),
            child: const Text('Tạo',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, ShoppingList list) {
    final controller = TextEditingController(text: list.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusModal),
        ),
        title: const Text('Đổi tên danh sách'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Tên danh sách',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusInput),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == list.name) {
                Navigator.of(ctx).pop();
                return;
              }

              Navigator.of(ctx).pop();
              final success = await ref
                  .read(shoppingListControllerProvider.notifier)
                  .renameList(
                    userId: _currentUserId,
                    listId: list.id,
                    newName: newName,
                  );

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã cập nhật tên danh sách')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Lưu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, ShoppingList list) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusModal),
        ),
        title: const Text('Xác nhận xóa danh sách'),
        content: Text(
          'Bạn có chắc chắn muốn xóa "${list.name}" và toàn bộ các mục bên trong không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await ref
                  .read(shoppingListControllerProvider.notifier)
                  .deleteList(
                    userId: _currentUserId,
                    listId: list.id,
                  );

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xóa danh sách mua sắm')),
                );
              }
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

