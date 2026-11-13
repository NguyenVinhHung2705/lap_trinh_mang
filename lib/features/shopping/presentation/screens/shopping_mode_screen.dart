import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/models/shopping_item.dart';
import '../providers/shopping_providers.dart';
import '../widgets/shopping_mode_tile.dart';
import '../widgets/shopping_progress_bar.dart';
import 'shopping_sync_screen.dart';

/// In-store shopping trip screen (MOD-02-05 & MOD-02-06 / FR-13, FR-14).
///
/// Features:
/// - Category/Aisle filter tabs
/// - Search within list
/// - One-tap bought toggle (does NOT sync to pantry)
/// - Direct actual quantity adjustments (+ / - / text)
/// - Fast transition to pantry sync
class ShoppingModeScreen extends ConsumerStatefulWidget {
  const ShoppingModeScreen({
    super.key,
    required this.userId,
    required this.listId,
  });

  final String userId;
  final String listId;

  @override
  ConsumerState<ShoppingModeScreen> createState() => _ShoppingModeScreenState();
}

class _ShoppingModeScreenState extends ConsumerState<ShoppingModeScreen> {
  String _selectedCategory = 'Tất cả';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(
      shoppingItemsStreamProvider((userId: widget.userId, listId: widget.listId)),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Chế độ Đi mua',
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
      body: itemsAsync.when(
        data: (items) => _buildModeContent(context, items),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Text('Lỗi: $err',
              style: const TextStyle(color: AppColors.statusDanger)),
        ),
      ),
      bottomNavigationBar: itemsAsync.maybeWhen(
        data: (items) => _buildBottomBar(context, items),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildModeContent(BuildContext context, List<ShoppingItem> items) {
    final boughtCount = items.where((it) => it.isBought || it.isSynced).length;
    final totalCount = items.length;

    // Extract categories
    final categories = <String>{'Tất cả'};
    for (final it in items) {
      if (it.categoryName != null && it.categoryName!.trim().isNotEmpty) {
        categories.add(it.categoryName!.trim());
      }
    }

    // Filter items
    final filtered = items.where((it) {
      final matchesCat = _selectedCategory == 'Tất cả' ||
          it.categoryName?.trim() == _selectedCategory;
      final matchesQuery = _searchQuery.isEmpty ||
          it.foodName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesQuery;
    }).toList();

    return Column(
      children: [
        // Sticky Header: Progress & Search & Category Chips
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShoppingProgressBar(
                boughtCount: boughtCount,
                totalCount: totalCount,
              ),
              const SizedBox(height: 12),
              // Search Input
              TextField(
                onChanged: (q) => setState(() => _searchQuery = q.trim()),
                decoration: InputDecoration(
                  hintText: 'Tìm thực phẩm trong giỏ...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusInput),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                ),
              ),
              const SizedBox(height: 10),
              // Aisle / Category Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.background,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCategory = cat);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Items List
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'Không có thực phẩm nào trong danh mục này.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return ShoppingModeTile(
                      item: item,
                      onToggleBought: (isBought) {
                        ref.read(shoppingServiceProvider).toggleItemBought(
                              userId: widget.userId,
                              listId: widget.listId,
                              itemId: item.id,
                              isBought: isBought,
                            );
                      },
                      onQuantityChanged: (newQty) {
                        ref.read(shoppingRepositoryProvider).updateItemActualDetails(
                              userId: widget.userId,
                              listId: widget.listId,
                              itemId: item.id,
                              actualQuantity: newQty,
                              expiryDate: item.expiryDate,
                              locationId: item.locationId,
                              locationName: item.locationName,
                            );
                      },
                      onEditDetails: () =>
                          _showItemDetailsModal(context, item),
                    );
                  },
                ),
        ),
      ],
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
        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
        label: Text(
          'Hoàn tất & Nhập kho ($boughtUnsyncedCount món)',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
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
    );
  }

  void _showItemDetailsModal(BuildContext context, ShoppingItem item) {
    final qtyController = TextEditingController(
      text: (item.actualQuantity > 0
              ? item.actualQuantity
              : item.plannedQuantity)
          .toString(),
    );
    DateTime? selectedExpiry = item.expiryDate;
    String? selectedLocationId = item.locationId;
    String? selectedLocationName = item.locationName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final locationsAsync =
                ref.watch(storageLocationsProvider(widget.userId));

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.foodName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Actual Quantity
                  TextField(
                    controller: qtyController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Số lượng thực mua (${item.unitName}) *',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppColors.radiusInput),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Expiry Date Picker
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppColors.radiusInput),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    leading: const Icon(Icons.calendar_today,
                        color: AppColors.primary),
                    title: Text(
                      selectedExpiry != null
                          ? 'HSD: ${selectedExpiry!.day}/${selectedExpiry!.month}/${selectedExpiry!.year}'
                          : 'Chọn hạn sử dụng *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selectedExpiry != null
                            ? AppColors.textPrimary
                            : AppColors.statusWarning,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedExpiry ??
                            now.add(const Duration(days: 7)),
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 365 * 3)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedExpiry = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Location Dropdown
                  locationsAsync.when(
                    data: (locs) => DropdownButtonFormField<String>(
                      value: selectedLocationId != null &&
                              locs.any((l) => l.id == selectedLocationId)
                          ? selectedLocationId
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Vị trí lưu trữ *',
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppColors.radiusInput),
                        ),
                      ),
                      items: locs.map((loc) {
                        return DropdownMenuItem<String>(
                          value: loc.id,
                          child: Text(loc.name),
                        );
                      }).toList(),
                      onChanged: (locId) {
                        if (locId != null) {
                          final loc = locs.firstWhere((l) => l.id == locId);
                          setModalState(() {
                            selectedLocationId = loc.id;
                            selectedLocationName = loc.name;
                          });
                        }
                      },
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Không tải được vị trí kho'),
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final parsedQty =
                            double.tryParse(qtyController.text.trim()) ?? 0.0;
                        if (parsedQty <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Số lượng thực mua phải lớn hơn 0'),
                            ),
                          );
                          return;
                        }

                        Navigator.of(ctx).pop();
                        await ref
                            .read(shoppingRepositoryProvider)
                            .updateItemActualDetails(
                              userId: widget.userId,
                              listId: widget.listId,
                              itemId: item.id,
                              actualQuantity: parsedQty,
                              expiryDate: selectedExpiry,
                              locationId: selectedLocationId,
                              locationName: selectedLocationName,
                            );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppColors.radiusInput),
                        ),
                      ),
                      child: const Text(
                        'Lưu chi tiết',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

