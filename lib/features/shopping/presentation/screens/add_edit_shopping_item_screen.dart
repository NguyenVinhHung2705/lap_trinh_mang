import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/adapters/pantry_adapter.dart';
import '../../data/models/shopping_item.dart';
import '../providers/shopping_providers.dart';

/// Form screen for manual item creation and editing (MOD-02-02 / FR-10).
class AddEditShoppingItemScreen extends ConsumerStatefulWidget {
  const AddEditShoppingItemScreen({
    super.key,
    required this.userId,
    required this.listId,
    this.editingItem,
  });

  final String userId;
  final String listId;
  final ShoppingItem? editingItem;

  @override
  ConsumerState<AddEditShoppingItemScreen> createState() =>
      _AddEditShoppingItemScreenState();
}

class _AddEditShoppingItemScreenState
    extends ConsumerState<AddEditShoppingItemScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _foodNameController;
  late TextEditingController _quantityController;
  late TextEditingController _noteController;

  String? _selectedFoodId;
  String? _selectedUnitId;
  String? _selectedUnitName;
  String? _selectedCategoryId;
  String? _selectedCategoryName;

  bool get _isEditing => widget.editingItem != null;

  @override
  void initState() {
    super.initState();
    final item = widget.editingItem;
    _foodNameController = TextEditingController(text: item?.foodName ?? '');
    _quantityController = TextEditingController(
      text: item != null ? item.plannedQuantity.toString() : '1',
    );
    _noteController = TextEditingController(text: item?.note ?? '');

    _selectedFoodId = item?.foodId;
    _selectedUnitId = item?.unitId ?? 'kg';
    _selectedUnitName = item?.unitName ?? 'kg';
    _selectedCategoryId = item?.categoryId;
    _selectedCategoryName = item?.categoryName;
  }

  @override
  void dispose() {
    _foodNameController.dispose();
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foodsAsync = ref.watch(pantryFoodsProvider(widget.userId));
    final unitsAsync = ref.watch(measurementUnitsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Chỉnh sửa mục mua' : 'Thêm thực phẩm cần mua',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fast food catalog picker
              if (!_isEditing) ...[
                const Text(
                  'Chọn nhanh từ kho thực phẩm:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                foodsAsync.when(
                  data: (foods) {
                    if (foods.isEmpty) return const SizedBox.shrink();
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: foods.take(8).map((food) {
                          final isChosen = _selectedFoodId == food.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              label: Text(food.name),
                              backgroundColor: isChosen
                                  ? AppColors.primary
                                  : AppColors.surface,
                              labelStyle: TextStyle(
                                color: isChosen
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontWeight: isChosen
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedFoodId = food.id;
                                  _foodNameController.text = food.name;
                                  _selectedCategoryId = food.categoryId;
                                  _selectedCategoryName = food.categoryName;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
              ],

              // Food Name Input
              TextFormField(
                controller: _foodNameController,
                decoration: InputDecoration(
                  labelText: 'Tên thực phẩm *',
                  hintText: 'Ví dụ: Thịt bò, Cà chua, Sữa tươi...',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppColors.radiusInput),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập tên thực phẩm';
                  }
                  return null;
                },
                onChanged: (val) {
                  // If user manually changed name, ensure foodId is keyed
                  if (_selectedFoodId == null || _selectedFoodId!.isEmpty) {
                    _selectedFoodId = 'food_${val.trim().toLowerCase().replaceAll(' ', '_')}';
                  }
                },
              ),
              const SizedBox(height: 16),

              // Quantity & Unit Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Planned Quantity
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Số lượng cần *',
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppColors.radiusInput),
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                      ),
                      validator: (val) {
                        final parsed = double.tryParse(val ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'Phải > 0';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Unit Dropdown
                  Expanded(
                    flex: 3,
                    child: unitsAsync.when(
                      data: (units) => DropdownButtonFormField<String>(
                        value: _selectedUnitId != null &&
                                units.any((u) => u.id == _selectedUnitId)
                            ? _selectedUnitId
                            : units.first.id,
                        decoration: InputDecoration(
                          labelText: 'Đơn vị *',
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppColors.radiusInput),
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                        ),
                        items: units.map((u) {
                          return DropdownMenuItem<String>(
                            value: u.id,
                            child: Text(
                              '${u.name} (${u.symbol})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final unit = units.firstWhere((u) => u.id == val);
                            setState(() {
                              _selectedUnitId = unit.id;
                              _selectedUnitName = unit.symbol.isNotEmpty
                                  ? unit.symbol
                                  : unit.name;
                            });
                          }
                        },
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text('Lỗi tải đơn vị'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Note Input
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Ghi chú thêm (tùy chọn)',
                  hintText: 'Ví dụ: Mua loại ít đường, tươi...',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppColors.radiusInput),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppColors.radiusInput),
                    ),
                  ),
                  child: Text(
                    _isEditing ? 'Lưu thay đổi' : 'Thêm vào danh sách',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final foodName = _foodNameController.text.trim();
    final quantity = double.parse(_quantityController.text.trim());
    final note = _noteController.text.trim();
    final foodId = _selectedFoodId ??
        'food_${foodName.toLowerCase().replaceAll(' ', '_')}';
    final unitId = _selectedUnitId ?? 'kg';
    final unitName = _selectedUnitName ?? 'kg';

    try {
      if (_isEditing) {
        final updated = widget.editingItem!.copyWith(
          foodName: foodName,
          plannedQuantity: quantity,
          unitId: unitId,
          unitName: unitName,
          note: note.isNotEmpty ? note : null,
        );
        await ref.read(shoppingRepositoryProvider).updateItem(
              userId: widget.userId,
              listId: widget.listId,
              item: updated,
            );
      } else {
        await ref.read(shoppingServiceProvider).addItemManual(
              userId: widget.userId,
              listId: widget.listId,
              foodId: foodId,
              foodName: foodName,
              unitId: unitId,
              unitName: unitName,
              plannedQuantity: quantity,
              categoryId: _selectedCategoryId,
              categoryName: _selectedCategoryName,
              note: note.isNotEmpty ? note : null,
            );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Đã cập nhật $foodName'
                : 'Đã thêm $foodName vào danh sách mua'),
            backgroundColor: AppColors.statusSuccess,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.statusDanger,
          ),
        );
      }
    }
  }
}

