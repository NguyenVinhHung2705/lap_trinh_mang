import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pantry_providers.dart';
import '../../shared/pantry_colors.dart';

class AddBatchScreen extends ConsumerStatefulWidget {
  const AddBatchScreen({super.key});

  @override
  ConsumerState<AddBatchScreen> createState() => _AddBatchScreenState();
}

class _AddBatchScreenState extends ConsumerState<AddBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController(text: 'kg');

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
    'Khác'
  ];

  final List<String> _locations = [
    'Ngăn mát tủ lạnh',
    'Ngăn đông tủ lạnh',
    'Hộc rau quả',
    'Cánh cửa tủ lạnh',
    'Tủ gia vị',
    'Kệ bếp',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    super.dispose();
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(pantryRepositoryProvider);
    final quantity = double.tryParse(_quantityController.text) ?? 1.0;

    repo.addFoodBatch(
      userId: 'mock_user_nguyen_van_dinh',
      foodName: _nameController.text.trim(),
      categoryName: _selectedCategory,
      baseUnit: _unitController.text.trim(),
      locationName: _selectedLocation,
      quantity: quantity,
      expiryDate: _selectedExpiryDate,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        content: Text('Đã nhập lô "${_nameController.text.trim()}" vào kho thành công!'),
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Nhập kho thực phẩm',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
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
            // Tên thực phẩm
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Tên thực phẩm *',
                hintText: 'Ví dụ: Cà chua Bi, Trứng gà, Sữa tươi...',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên thực phẩm' : null,
            ),
            const SizedBox(height: 16),

            // Danh mục & Vị trí
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Danh mục',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedLocation,
                    decoration: InputDecoration(
                      labelText: 'Vị trí lưu trữ',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _locations.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => setState(() => _selectedLocation = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Số lượng & Đơn vị
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Số lượng *',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Nhập số lượng';
                      final num = double.tryParse(v);
                      if (num == null || num <= 0) return 'Số lượng > 0';
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
                      labelText: 'Đơn vị',
                      hintText: 'kg, g, hộp...',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hạn sử dụng (HSD)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text(
                          '${_selectedExpiryDate.day}/${_selectedExpiryDate.month}/${_selectedExpiryDate.year}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Text('Thay đổi', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Nút Lưu
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Lưu vào kho', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
