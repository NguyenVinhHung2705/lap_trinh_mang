import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/food_item.dart';
import '../providers/pantry_providers.dart';
import '../widgets/food_card.dart';
import '../widgets/barcode_scanner_dialog.dart';
import 'food_detail_screen.dart';
import 'add_batch_screen.dart';
import 'stock_movement_screen.dart';
import 'storage_locations_screen.dart';
import '../../shared/pantry_colors.dart';

class PantryHomeScreen extends ConsumerStatefulWidget {
  const PantryHomeScreen({super.key});

  @override
  ConsumerState<PantryHomeScreen> createState() => _PantryHomeScreenState();
}

class _PantryHomeScreenState extends ConsumerState<PantryHomeScreen> {
  final _searchController = TextEditingController();
  final Map<String, GlobalKey> _categoryKeys = {};

  static const List<String> _statusFilters = [
    'Tất cả',
    'Sắp hết hạn',
    'Đã hết hạn',
    'Sắp hết tồn',
  ];

  GlobalKey _keyForCategory(String cat) {
    return _categoryKeys.putIfAbsent(cat, () => GlobalKey());
  }

  void _selectCategoryAndScroll(String cat) {
    ref.read(selectedCategoryFilterProvider.notifier).state = cat;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _categoryKeys[cat]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _showAddCustomCategoryDialog({
    VoidCallback? onBeforeSelect,
  }) async {
    final controller = TextEditingController();
    String? errorText;

    final createdName = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Thêm loại thực phẩm mới',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            onChanged: (_) {
              if (errorText != null) setDialogState(() => errorText = null);
            },
            decoration: InputDecoration(
              labelText: 'Tên loại mới *',
              hintText: 'VD: Bánh kẹo, Đồ ăn vặt, Đồ chay...',
              errorText: errorText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                final val = controller.text.trim();
                if (val.isEmpty) {
                  setDialogState(
                    () => errorText = 'Vui lòng nhập tên loại thực phẩm',
                  );
                  return;
                }
                if (val.toLowerCase() == 'tất cả') {
                  setDialogState(
                    () => errorText = 'Tên này đã được hệ thống sử dụng',
                  );
                  return;
                }
                Navigator.pop(ctx, val);
              },
              child: const Text('Thêm loại'),
            ),
          ],
        ),
      ),
    );

    if (createdName == null || !mounted) return;

    final existingAll = ref.read(allFoodCategoriesProvider);
    final matchExisting = existingAll.cast<String?>().firstWhere(
          (c) => c?.toLowerCase() == createdName.toLowerCase(),
          orElse: () => null,
        );

    final finalCategory = matchExisting ?? createdName;
    if (matchExisting == null) {
      final currentCustom = ref.read(customFoodCategoriesProvider);
      ref.read(customFoodCategoriesProvider.notifier).state = [
        ...currentCustom,
        finalCategory,
      ];
    }

    onBeforeSelect?.call();
    _selectCategoryAndScroll(finalCategory);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        content: Text(
          matchExisting == null
              ? 'Đã thêm loại "$finalCategory" vào danh sách!'
              : 'Đã chọn loại "$finalCategory" có sẵn.',
        ),
      ),
    );
  }

  /// Mở bảng chọn đầy đủ tất cả danh mục kèm số lượng thực phẩm trong từng nhóm
  void _showAllCategoriesSheet(
    List<String> categories,
    List<FoodItem> allFoods,
    String selectedCategory,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Chọn loại thực phẩm',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (selectedCategory != 'Tất cả')
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _selectCategoryAndScroll('Tất cả');
                        },
                        child: const Text('Mặc định'),
                      ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showAddCustomCategoryDialog();
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text(
                        'Thêm loại',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: [
                    ...categories.map((cat) {
                      final count = cat == 'Tất cả'
                          ? allFoods.length
                          : allFoods.where((f) => f.categoryName == cat).length;
                      final isSelected = cat == selectedCategory;

                      return _buildUnifiedPill(
                        label: '$cat ($count)',
                        isSelected: isSelected,
                        onTap: () {
                          Navigator.pop(ctx);
                          _selectCategoryAndScroll(cat);
                        },
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Chip lọc đồng bộ kích thước, độ bo, viền và dấu tick cho cả 2 thanh lọc
  Widget _buildUnifiedPill({
    Key? key,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color activeColor = AppColors.primary,
    Color activeBg = AppColors.primaryTint,
    bool expandWidth = false,
  }) {
    final contentRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSelected) ...[
          Icon(Icons.check_rounded, size: 15, color: activeColor),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12.5,
          ),
        ),
      ],
    );

    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          padding: EdgeInsets.symmetric(
            horizontal: expandWidth ? 6 : 13,
          ),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : AppColors.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : AppColors.border,
              width: 1.2,
            ),
          ),
          alignment: expandWidth ? Alignment.center : null,
          child: expandWidth
              ? FittedBox(fit: BoxFit.scaleDown, child: contentRow)
              : contentRow,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foodsAsync = ref.watch(pantryFoodsStreamProvider);
    final allFoods = foodsAsync.value ?? [];
    final filteredFoods = ref.watch(filteredFoodsProvider);
    final selectedCategory = ref.watch(selectedCategoryFilterProvider);
    final selectedStatus = ref.watch(selectedExpiryFilterProvider);
    final searchQuery = ref.watch(pantrySearchQueryProvider);
    final expiringAsync = ref.watch(expiringBatchesStreamProvider);
    final expiringBatches = expiringAsync.value ?? [];
    final allCategories = ref.watch(allFoodCategoriesProvider);

    if (_searchController.text != searchQuery &&
        !FocusScope.of(context).hasFocus) {
      _searchController.text = searchQuery;
    }

    final categories = <String>[
      'Tất cả',
      ...allCategories.where((c) => c != 'Tất cả'),
    ];

    final urgentCount =
        expiringBatches.where((b) => b.daysRemaining <= 3).length;

    // Tự động trả bộ lọc về 'Tất cả' nếu đã xử lý hết sạch các lô cận/quá hạn
    if (!expiringAsync.isLoading &&
        urgentCount == 0 &&
        selectedStatus == 'Ưu tiên dùng') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            ref.read(selectedExpiryFilterProvider) == 'Ưu tiên dùng') {
          ref.read(selectedExpiryFilterProvider.notifier).state = 'Tất cả';
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Kho Thực Phẩm',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.kitchen_outlined, color: AppColors.primary),
            tooltip: 'Vị trí lưu trữ',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StorageLocationsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.primary),
            tooltip: 'Lịch sử biến động kho',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StockMovementHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Thanh tìm kiếm + Quét mã vạch
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                ref.read(pantrySearchQueryProvider.notifier).state = val;
              },
              decoration: InputDecoration(
                hintText: 'Tìm tên thực phẩm hoặc mã vạch...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        tooltip: 'Xóa tìm kiếm',
                        onPressed: () {
                          _searchController.clear();
                          ref.read(pantrySearchQueryProvider.notifier).state =
                              '';
                        },
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.qr_code_scanner,
                        color: AppColors.primary,
                      ),
                      tooltip: 'Quét mã vạch',
                      onPressed: () {
                        BarcodeScannerDialog.show(
                          context,
                          onScanned: (barcode, name) {
                            final keyword = name.isNotEmpty ? name : barcode;
                            _searchController.text = keyword;
                            ref.read(pantrySearchQueryProvider.notifier).state =
                                keyword;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  name.isNotEmpty
                                      ? 'Đã nhận diện mã: $barcode ($name)'
                                      : 'Đang lọc theo mã vạch: $barcode',
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
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

          // 2. Banner cảnh báo ưu tiên dùng
          if (urgentCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  final next = selectedStatus == 'Ưu tiên dùng'
                      ? 'Tất cả'
                      : 'Ưu tiên dùng';
                  ref.read(selectedExpiryFilterProvider.notifier).state = next;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.statusWarningTint,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selectedStatus == 'Ưu tiên dùng'
                          ? AppColors.statusWarning
                          : AppColors.statusWarning.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.statusWarning,
                        size: 22,
                      ),
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
                      Text(
                        selectedStatus == 'Ưu tiên dùng'
                            ? 'Bỏ lọc'
                            : 'Xem ngay',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.statusWarning,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 3. Cụm 2 thanh lọc đồng bộ (Không bị cắt mép + Mở xem toàn bộ loại)
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Column(
              children: [
                // Hàng 1: Thanh cuộn danh mục (hỗ trợ kéo chuột Web + nút mở bảng đầy đủ)
                Row(
                  children: [
                    Expanded(
                      child: ShaderMask(
                        shaderCallback: (bounds) {
                          return const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.90, 1.0],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.dstIn,
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            dragDevices: {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.mouse,
                              PointerDeviceKind.trackpad,
                            },
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(right: 16),
                            child: Row(
                              children: [
                                for (var i = 0; i < categories.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 8),
                                  _buildUnifiedPill(
                                    key: _keyForCategory(categories[i]),
                                    label: categories[i],
                                    isSelected:
                                        categories[i] == selectedCategory,
                                    onTap: () =>
                                        _selectCategoryAndScroll(categories[i]),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Nút mở bảng lưới xem toàn bộ danh mục thực phẩm
                    Tooltip(
                      message: 'Xem tất cả loại thực phẩm',
                      child: InkWell(
                        onTap: () => _showAllCategoriesSheet(
                          categories,
                          allFoods,
                          selectedCategory,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: selectedCategory != 'Tất cả'
                                ? AppColors.primaryTint
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selectedCategory != 'Tất cả'
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            Icons.grid_view_rounded,
                            size: 17,
                            color: selectedCategory != 'Tất cả'
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Hàng 2: 4 trạng thái HSD/Tồn chia đều 4 cột vừa khít 100% khung ngang
                Row(
                  children: [
                    for (var i = 0; i < _statusFilters.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final st = _statusFilters[i];
                            Color activeColor = AppColors.primary;
                            Color activeBg = AppColors.primaryTint;
                            if (st == 'Sắp hết hạn' || st == 'Sắp hết tồn') {
                              activeColor = AppColors.statusWarning;
                              activeBg = AppColors.statusWarningTint;
                            } else if (st == 'Đã hết hạn') {
                              activeColor = AppColors.statusDanger;
                              activeBg = AppColors.statusDangerTint;
                            }

                            return _buildUnifiedPill(
                              label: st,
                              isSelected: st == selectedStatus,
                              activeColor: activeColor,
                              activeBg: activeBg,
                              expandWidth: true,
                              onTap: () {
                                ref
                                    .read(
                                      selectedExpiryFilterProvider.notifier,
                                    )
                                    .state = st;
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // 4. Danh sách thực phẩm
          Expanded(
            child: foodsAsync.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : allFoods.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: AppColors.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Kho thực phẩm trống',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'Nhấn "+ Nhập kho" bên dưới để thêm thực phẩm đầu tiên của bạn',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      )
                    : filteredFoods.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Không có thực phẩm khớp với bộ lọc hiện tại',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    ref
                                        .read(
                                          pantrySearchQueryProvider.notifier,
                                        )
                                        .state = '';
                                    ref
                                        .read(
                                          selectedCategoryFilterProvider
                                              .notifier,
                                        )
                                        .state = 'Tất cả';
                                    ref
                                        .read(
                                          selectedExpiryFilterProvider.notifier,
                                        )
                                        .state = 'Tất cả';
                                  },
                                  child: const Text('Đặt lại bộ lọc'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                            itemCount: filteredFoods.length,
                            itemBuilder: (context, index) {
                              final food = filteredFoods[index];
                              return FoodCard(
                                food: food,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          FoodDetailScreen(food: food),
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
        label: const Text(
          'Nhập kho',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddBatchScreen()),
          );
        },
      ),
    );
  }
}
