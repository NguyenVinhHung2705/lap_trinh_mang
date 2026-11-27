import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/pantry_providers.dart';
import '../../shared/pantry_colors.dart';
import '../widgets/barcode_scanner_dialog.dart';
import '../widgets/ai_image_recognition_dialog.dart';
import 'storage_locations_screen.dart';

class AddBatchScreen extends ConsumerStatefulWidget {
  const AddBatchScreen({
    super.key,
    this.initialFoodName,
    this.initialCategory,
    this.initialUnit,
    this.initialBarcode,
  });

  final String? initialFoodName;
  final String? initialCategory;
  final String? initialUnit;
  final String? initialBarcode;

  @override
  ConsumerState<AddBatchScreen> createState() => _AddBatchScreenState();
}

class _AddBatchScreenState extends ConsumerState<AddBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController(text: 'kg');
  final _barcodeController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isSubmitting = false;
  String _selectedCategory = 'Rau củ';
  String _selectedLocation = 'Ngăn mát tủ lạnh';
  DateTime _selectedExpiryDate = DateTime.now().add(const Duration(days: 7));

  final List<String> _categories = [
    'Rau củ',
    'Thịt cá',
    'Đồ uống',
    'Gia vị',
    'Trứng',
    'Trái cây',
    'Đồ khô',
    'Khác',
  ];

  static const List<String> _fallbackLocations = [
    'Ngăn mát tủ lạnh',
    'Ngăn đông tủ lạnh',
    'Hộc rau quả',
    'Cánh cửa tủ lạnh',
    'Tủ gia vị khô',
    'Kệ bếp',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialFoodName != null &&
        widget.initialFoodName!.trim().isNotEmpty) {
      _nameController.text = widget.initialFoodName!.trim();
    }
    if (widget.initialCategory != null &&
        widget.initialCategory!.trim().isNotEmpty) {
      final cat = widget.initialCategory!.trim();
      if (!_categories.contains(cat)) {
        _categories.insert(0, cat);
      }
      _selectedCategory = cat;
    }
    if (widget.initialUnit != null && widget.initialUnit!.trim().isNotEmpty) {
      _unitController.text = widget.initialUnit!.trim();
    }
    if (widget.initialBarcode != null &&
        widget.initialBarcode!.trim().isNotEmpty) {
      _barcodeController.text = widget.initialBarcode!.trim();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _barcodeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _showAddCustomCategoryDialog() async {
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
              labelText: 'Tên loại thực phẩm *',
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
              child: const Text('Thêm'),
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

    final finalCat = matchExisting ?? createdName;
    if (matchExisting == null) {
      final currentCustom = ref.read(customFoodCategoriesProvider);
      ref.read(customFoodCategoriesProvider.notifier).state = [
        ...currentCustom,
        finalCat,
      ];
    }

    setState(() {
      if (!_categories.contains(finalCat)) {
        _categories.insert(0, finalCat);
      }
      _selectedCategory = finalCat;
    });
  }

  Future<void> _selectExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpiryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() {
        _selectedExpiryDate = picked;
      });
    }
  }

  void _openBarcodeQuickFill() {
    BarcodeScannerDialog.show(
      context,
      onScanned: (_, __) {},
      onProductResolved: (product, isKnown) {
        final code = product['code'] ?? '';
        setState(() {
          _barcodeController.text = code;
          if (isKnown) {
            _nameController.text = product['name'] ?? '';
            final cat = product['category'] ?? '';
            if (cat.isNotEmpty) {
              if (!_categories.contains(cat)) _categories.insert(0, cat);
              _selectedCategory = cat;
            }
            if ((product['unit'] ?? '').isNotEmpty) {
              _unitController.text = product['unit']!;
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor:
                isKnown ? AppColors.primary : AppColors.statusWarning,
            content: Text(
              isKnown
                  ? 'Đã điền thông tin mã $code. Vui lòng nhập số lượng & kiểm tra HSD trước khi lưu!'
                  : 'Mã $code chưa có trong danh mục mẫu. Vui lòng nhập tên thực phẩm thủ công!',
            ),
          ),
        );
      },
    );
  }

  void _openAiRecognitionQuickFill() {
    AiImageRecognitionDialog.show(
      context,
      onSelected: (suggestion) {
        setState(() {
          _nameController.text = suggestion.name;
          if (!_categories.contains(suggestion.category)) {
            _categories.insert(0, suggestion.category);
          }
          _selectedCategory = suggestion.category;
          _unitController.text = suggestion.unit;
          _noteController.text =
              'Nhận diện AI (${suggestion.confidencePercent}% tin cậy)';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            content: Text(
              'Đã điền gợi ý "${suggestion.name}". Vui lòng kiểm tra số lượng & hạn dùng trước khi lưu!',
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit(String effectiveLocation) async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(pantryRepositoryProvider);
      final userId = ref.read(pantryUserIdProvider);
      final quantity = double.parse(_quantityController.text.trim());
      final foodName = _nameController.text.trim();

      await repo.addFoodBatch(
        userId: userId,
        foodName: foodName,
        categoryName: _selectedCategory,
        baseUnit: _unitController.text.trim().isEmpty
            ? 'phần'
            : _unitController.text.trim(),
        locationName: effectiveLocation,
        quantity: quantity,
        expiryDate: _selectedExpiryDate,
        barcode: _barcodeController.text.trim(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      ref.invalidate(pantryFoodsStreamProvider);
      ref.invalidate(expiringBatchesStreamProvider);
      ref.invalidate(stockMovementsStreamProvider);
      ref.invalidate(storageLocationsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          content: Text('Đã nhập lô "$foodName" vào kho thành công!'),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusDanger,
          content: Text('Lỗi khi thêm thực phẩm: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sharedCategories = ref.watch(allFoodCategoriesProvider);
    final availableCategories = <String>{
      ...sharedCategories,
      ..._categories,
    }.toList();
    final effectiveCategory = availableCategories.contains(_selectedCategory)
        ? _selectedCategory
        : availableCategories.first;

    final locationsAsync = ref.watch(storageLocationsProvider);
    final dynamicLocations = (locationsAsync.value ?? [])
        .map((l) => (l['ten_vi_tri'] as String? ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final availableLocations =
        dynamicLocations.isNotEmpty ? dynamicLocations : _fallbackLocations;

    final effectiveLocation = availableLocations.contains(_selectedLocation)
        ? _selectedLocation
        : availableLocations.first;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(
      _selectedExpiryDate.year,
      _selectedExpiryDate.month,
      _selectedExpiryDate.day,
    );
    final isPastExpiry = selectedDay.isBefore(today);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Nhập kho thực phẩm',
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Thanh công cụ điền nhanh: Quét mã vạch (MOD-01-02) & Nhận diện AI (MOD-01-03)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hỗ trợ điền nhanh biểu mẫu:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.qr_code_scanner, size: 18),
                          label: const Text(
                            'Quét mã / QR',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _openBarcodeQuickFill,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: const Text(
                            'Nhận diện ảnh AI',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _openAiRecognitionQuickFill,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tên thực phẩm
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Tên thực phẩm *',
                hintText: 'Ví dụ: Cà chua Bi, Trứng gà, Sữa tươi...',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập tên thực phẩm'
                  : null,
            ),
            const SizedBox(height: 16),

            // Danh mục (hỗ trợ tạo loại mới) & Vị trí lưu trữ động (MOD-01-04)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: effectiveCategory,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Danh mục',
                      filled: true,
                      fillColor: AppColors.surface,
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Thêm loại thực phẩm mới',
                        onPressed: _showAddCustomCategoryDialog,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: availableCategories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              c,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedCategory = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: effectiveLocation,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Vị trí lưu trữ',
                      filled: true,
                      fillColor: AppColors.surface,
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.add_location_alt_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Quản lý vị trí',
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const StorageLocationsScreen(),
                            ),
                          );
                          ref.invalidate(storageLocationsProvider);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: availableLocations
                        .map(
                          (l) => DropdownMenuItem(
                            value: l,
                            child: Text(
                              l,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedLocation = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Số lượng & Đơn vị (TC-03: Kiểm tra lượng nhập dương > 0)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Số lượng nhập (> 0) *',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Vui lòng nhập số lượng';
                      }
                      final num = double.tryParse(v.trim());
                      if (num == null || num.isNaN || num <= 0) {
                        return 'Số lượng phải lớn hơn 0';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _unitController,
                    decoration: InputDecoration(
                      labelText: 'Đơn vị *',
                      hintText: 'kg, g, hộp...',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nhập ĐV' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Hạn sử dụng
            InkWell(
              onTap: _selectExpiryDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPastExpiry
                        ? AppColors.statusWarning
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: isPastExpiry
                          ? AppColors.statusWarning
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hạn sử dụng (HSD) *',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${_selectedExpiryDate.day}/${_selectedExpiryDate.month}/${_selectedExpiryDate.year}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (isPastExpiry)
                            const Text(
                              'Cảnh báo: Ngày chọn đã qua hạn sử dụng!',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.statusWarning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Text(
                      'Thay đổi',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Mã vạch & Ghi chú tùy chọn
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: 'Mã vạch (tùy chọn)',
                      prefixIcon: const Icon(Icons.qr_code, size: 18),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      labelText: 'Ghi chú lô',
                      hintText: 'VD: Mua siêu thị...',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Nút Lưu
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed:
                    _isSubmitting ? null : () => _submit(effectiveLocation),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Lưu vào kho',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
