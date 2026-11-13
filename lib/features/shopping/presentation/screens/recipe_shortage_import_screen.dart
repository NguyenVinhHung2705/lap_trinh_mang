import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/models/food_shortage_item.dart';
import '../providers/shopping_providers.dart';

/// Screen for importing ingredient shortages from recipes into the shopping list (MOD-02-03 / FR-11).
class RecipeShortageImportScreen extends ConsumerStatefulWidget {
  const RecipeShortageImportScreen({
    super.key,
    required this.userId,
    required this.listId,
    this.initialRecipeId,
  });

  final String userId;
  final String listId;
  final String? initialRecipeId;

  @override
  ConsumerState<RecipeShortageImportScreen> createState() =>
      _RecipeShortageImportScreenState();
}

class _RecipeShortageImportScreenState
    extends ConsumerState<RecipeShortageImportScreen> {
  late TextEditingController _recipeIdController;
  late TextEditingController _servingsController;

  List<FoodShortageItem> _shortages = [];
  bool _isLoading = false;
  String? _error;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _recipeIdController =
        TextEditingController(text: widget.initialRecipeId ?? 'rec_beef_pho');
    _servingsController = TextEditingController(text: '4');

    if (widget.initialRecipeId != null) {
      _loadShortages();
    }
  }

  @override
  void dispose() {
    _recipeIdController.dispose();
    _servingsController.dispose();
    super.dispose();
  }

  Future<void> _loadShortages() async {
    final recipeId = _recipeIdController.text.trim();
    final servings = double.tryParse(_servingsController.text.trim()) ?? 1.0;

    if (recipeId.isEmpty || servings <= 0) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _hasSearched = true;
    });

    try {
      final items = await ref
          .read(shoppingSuggestionsControllerProvider.notifier)
          .loadRecipeShortages(
            userId: widget.userId,
            listId: widget.listId,
            recipeId: recipeId,
            servings: servings,
          );

      if (mounted) {
        setState(() {
          _shortages = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Thiếu từ Công thức nấu ăn',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          // Input Section: Recipe ID & Servings
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _recipeIdController,
                        decoration: InputDecoration(
                          labelText: 'Mã hoặc tên công thức',
                          hintText: 'rec_beef_pho...',
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppColors.radiusInput),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _servingsController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Khẩu phần',
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppColors.radiusInput),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _loadShortages,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppColors.radiusInput),
                        ),
                      ),
                      child: const Icon(Icons.search, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Hệ thống tự động so khớp với kho thực phẩm, chỉ đề xuất nguyên liệu thực sự thiếu.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Shortages List
          Expanded(
            child: _buildShortagesList(),
          ),
        ],
      ),
      bottomNavigationBar: _shortages.isNotEmpty
          ? Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleImport,
                icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                label: Text(
                  'Thêm vào danh sách mua (${_shortages.where((s) => s.isSelected).length} món)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppColors.radiusInput),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildShortagesList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Lỗi: $_error',
            style: const TextStyle(color: AppColors.statusDanger),
          ),
        ),
      );
    }

    if (!_hasSearched) {
      return const Center(
        child: Text(
          'Nhập công thức và số khẩu phần để kiểm tra nguyên liệu thiếu.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    if (_shortages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline,
                  size: 56, color: AppColors.statusSuccess),
              SizedBox(height: 16),
              Text(
                'Kho thực phẩm đã đủ nguyên liệu!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Không có nguyên liệu nào bị thiếu cho khẩu phần đã chọn.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _shortages.length,
      itemBuilder: (context, index) {
        final item = _shortages[index];

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusCard),
            side: BorderSide(
              color: item.alreadyInList
                  ? AppColors.statusWarning
                  : (item.isSelected ? AppColors.primary : AppColors.border),
              width: item.isSelected ? 1.5 : 1,
            ),
          ),
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Checkbox(
                  value: item.isSelected,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() {
                      _shortages[index] =
                          item.copyWith(isSelected: val ?? false);
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.foodName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Thiếu: ${item.shortageQuantity} ${item.unitName}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.statusDanger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (item.alreadyInList) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.statusWarningTint,
                            borderRadius:
                                BorderRadius.circular(AppColors.radiusBadge),
                          ),
                          child: Text(
                            'Đã có ${item.existingPendingQuantity} ${item.unitName} trong DS mua (tránh cộng trùng)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.statusWarning,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Adjustable Quantity Input
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    initialValue: item.approvedQuantity.toString(),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: item.unitName,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppColors.radiusBadge),
                      ),
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val) ?? item.shortageQuantity;
                      if (parsed > 0) {
                        _shortages[index] =
                            item.copyWith(approvedQuantity: parsed);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleImport() async {
    final selected = _shortages.where((s) => s.isSelected).toList();
    if (selected.isEmpty) return;

    final count = await ref
        .read(shoppingSuggestionsControllerProvider.notifier)
        .importShortages(
          userId: widget.userId,
          listId: widget.listId,
          shortages: selected,
        );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm $count nguyên liệu thiếu vào danh sách mua!'),
          backgroundColor: AppColors.statusSuccess,
        ),
      );
    }
  }
}

