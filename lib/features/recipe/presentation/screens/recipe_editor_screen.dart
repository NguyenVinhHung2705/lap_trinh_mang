import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/recipe.dart';
import '../../data/models/recipe_ingredient.dart';
import '../providers/recipe_detail_provider.dart';
import '../providers/recipe_list_provider.dart';

/// Screen for creating a new recipe or editing an existing recipe.
class RecipeEditorScreen extends ConsumerStatefulWidget {
  const RecipeEditorScreen({
    super.key,
    this.recipeId,
  });

  /// Recipe ID to edit, or `null` when creating a new recipe.
  final String? recipeId;

  static const Color primary = Color(0xFF16A36A);
  static const Color primaryDark = Color(0xFF087F55);
  static const Color background = Color(0xFFF7F9F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5EBE6);
  static const Color textPrimary = Color(0xFF202B26);
  static const Color textSecondary = Color(0xFF77847C);

  @override
  ConsumerState<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends ConsumerState<RecipeEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _instructionsController;
  late TextEditingController _imageUrlController;
  late TextEditingController _baseServingsController;
  late TextEditingController _cookingMinutesController;

  RecipeVisibility _visibility = RecipeVisibility.private;
  bool _isLoading = false;
  bool _isInitialized = false;

  final List<_IngredientDraft> _ingredients = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _instructionsController = TextEditingController();
    _imageUrlController = TextEditingController();
    _baseServingsController = TextEditingController(text: '2');
    _cookingMinutesController = TextEditingController(text: '30');

    if (widget.recipeId == null) {
      // Default initial ingredient row
      _ingredients.add(_IngredientDraft(
        foodName: '',
        unitSymbol: 'g',
        quantity: 100,
      ));
      _isInitialized = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized && widget.recipeId != null) {
      _loadExistingRecipe();
    }
  }

  Future<void> _loadExistingRecipe() async {
    final recipeId = widget.recipeId!;
    try {
      final detailData = await ref.read(recipeDetailDataProvider(recipeId).future);
      final r = detailData.recipe;
      _nameController.text = r.name;
      _descriptionController.text = r.description ?? '';
      _instructionsController.text = r.instructions;
      _imageUrlController.text = r.imageUrl ?? '';
      _baseServingsController.text = r.baseServings.toStringAsFixed(r.baseServings == r.baseServings.roundToDouble() ? 0 : 1);
      _cookingMinutesController.text = r.cookingMinutes.toString();
      _visibility = r.visibility;

      _ingredients.clear();
      for (final ing in detailData.ingredients) {
        _ingredients.add(_IngredientDraft(
          foodId: ing.foodId,
          foodName: ing.foodName,
          unitId: ing.unitId,
          unitSymbol: ing.unitSymbol,
          quantity: ing.baseQuantity,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _imageUrlController.dispose();
    _baseServingsController.dispose();
    _cookingMinutesController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Công thức phải có ít nhất 1 nguyên liệu.')),
      );
      return;
    }

    // Validate ingredient draft entries
    for (int i = 0; i < _ingredients.length; i++) {
      final ing = _ingredients[i];
      if (ing.foodName.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nguyên liệu dòng ${i + 1} chưa nhập tên.')),
        );
        return;
      }
      if (ing.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nguyên liệu "${ing.foodName}" có số lượng phải > 0.')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final userId = ref.read(currentUserIdProvider);
      final service = ref.read(recipeServiceProvider);

      final baseServings = double.parse(_baseServingsController.text.trim());
      final cookingMinutes = int.parse(_cookingMinutesController.text.trim());

      final recipeId = widget.recipeId ?? 'new';
      final recipe = Recipe(
        id: recipeId,
        authorId: userId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        instructions: _instructionsController.text.trim(),
        imageUrl: _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
        baseServings: baseServings,
        cookingMinutes: cookingMinutes,
        source: RecipeSource.user,
        visibility: _visibility,
      );

      final ingredientList = _ingredients.map((draft) {
        final foodId = draft.foodId.isEmpty
            ? 'food_${draft.foodName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_')}'
            : draft.foodId;
        final unitId = draft.unitId.isEmpty ? 'unit_${draft.unitSymbol}' : draft.unitId;

        return RecipeIngredient(
          id: foodId,
          recipeId: recipeId,
          foodId: foodId,
          foodName: draft.foodName.trim(),
          unitId: unitId,
          unitSymbol: draft.unitSymbol.trim(),
          baseQuantity: draft.quantity,
        );
      }).toList();

      if (widget.recipeId == null) {
        await service.createRecipe(
          userId: userId,
          recipe: recipe,
          ingredients: ingredientList,
        );
      } else {
        await service.updateRecipe(
          userId: userId,
          recipe: recipe,
          ingredients: ingredientList,
        );
        ref.invalidate(recipeDetailDataProvider(widget.recipeId!));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.recipeId == null ? 'Đã tạo công thức mới' : 'Đã cập nhật công thức')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu công thức: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Công thức nấu ăn')),
        body: const Center(child: CircularProgressIndicator(color: RecipeEditorScreen.primary)),
      );
    }

    final isEditing = widget.recipeId != null;

    return Scaffold(
      backgroundColor: RecipeEditorScreen.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: RecipeEditorScreen.surface,
        title: Text(
          isEditing ? 'Chỉnh sửa công thức' : 'Tạo công thức mới',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: RecipeEditorScreen.textPrimary,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Metadata Card
              _buildSectionCard(
                title: 'Thông tin chung',
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration('Tên món ăn *', hint: 'VD: Phở bò Hà Nội'),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Vui lòng nhập tên món ăn';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: _inputDecoration('Mô tả ngắn', hint: 'VD: Món phở bò truyền thống đậm đà...'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _baseServingsController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _inputDecoration('Khẩu phần gốc *', hint: 'VD: 2'),
                          validator: (val) {
                            final n = double.tryParse(val ?? '');
                            if (n == null || n <= 0) return 'Khẩu phần > 0';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _cookingMinutesController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('Thời gian (phút) *', hint: 'VD: 30'),
                          validator: (val) {
                            final n = int.tryParse(val ?? '');
                            if (n == null || n < 0) return 'Thời gian >= 0';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _imageUrlController,
                    decoration: _inputDecoration('URL Hình ảnh (tùy chọn)', hint: 'https://example.com/image.jpg'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<RecipeVisibility>(
                    initialValue: _visibility,
                    decoration: _inputDecoration('Quyền riêng tư'),
                    items: RecipeVisibility.values.map((v) {
                      return DropdownMenuItem(
                        value: v,
                        child: Text(v.labelVi),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _visibility = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Dynamic Ingredients Table Card
              _buildSectionCard(
                title: 'Danh sách nguyên liệu (Khẩu phần gốc)',
                action: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _ingredients.add(_IngredientDraft(
                        foodName: '',
                        unitSymbol: 'g',
                        quantity: 100,
                      ));
                    });
                  },
                  icon: const Icon(Icons.add, size: 18, color: RecipeEditorScreen.primary),
                  label: const Text(
                    'Thêm dòng',
                    style: TextStyle(
                      color: RecipeEditorScreen.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                children: [
                  ..._ingredients.asMap().entries.map((entry) {
                    final index = entry.key;
                    final draft = entry.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              initialValue: draft.foodName,
                              decoration: _inputDecoration('Tên nguyên liệu', hint: 'Tên thực phẩm'),
                              onChanged: (val) => draft.foodName = val,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              initialValue: draft.quantity.toStringAsFixed(draft.quantity == draft.quantity.roundToDouble() ? 0 : 1),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: _inputDecoration('Định lượng', hint: 'Số lượng'),
                              onChanged: (val) => draft.quantity = double.tryParse(val) ?? 0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              initialValue: draft.unitSymbol,
                              decoration: _inputDecoration('Đơn vị', hint: 'g / ml / quả'),
                              onChanged: (val) => draft.unitSymbol = val,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444)),
                            onPressed: _ingredients.length > 1
                                ? () => setState(() => _ingredients.removeAt(index))
                                : null,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),

              // Cooking Instructions Card
              _buildSectionCard(
                title: 'Hướng dẫn cách làm *',
                children: [
                  TextFormField(
                    controller: _instructionsController,
                    maxLines: 6,
                    decoration: _inputDecoration(
                      'Các bước thực hiện',
                      hint: 'Bước 1: Sơ chế nguyên liệu...\nBước 2: Ướp gia vị...\nBước 3: Nấu trong 20 phút...',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Vui lòng nhập hướng dẫn cách làm';
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RecipeEditorScreen.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _onSave,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          isEditing ? 'Lưu thay đổi' : 'Tạo công thức',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    Widget? action,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RecipeEditorScreen.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RecipeEditorScreen.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: RecipeEditorScreen.textPrimary,
                ),
              ),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(fontSize: 13, color: RecipeEditorScreen.textSecondary),
      hintStyle: const TextStyle(fontSize: 13, color: RecipeEditorScreen.textSecondary),
      filled: true,
      fillColor: RecipeEditorScreen.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: RecipeEditorScreen.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: RecipeEditorScreen.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: RecipeEditorScreen.primary, width: 1.5),
      ),
    );
  }
}

class _IngredientDraft {
  _IngredientDraft({
    this.foodId = '',
    required this.foodName,
    this.unitId = '',
    required this.unitSymbol,
    required this.quantity,
  });

  String foodId;
  String foodName;
  String unitId;
  String unitSymbol;
  double quantity;
}
