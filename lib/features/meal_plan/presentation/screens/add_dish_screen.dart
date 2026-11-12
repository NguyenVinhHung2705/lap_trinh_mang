import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/meal_repository.dart';
import '../../data/models/meal.dart';
import '../../domain/meal_service.dart';
import '../providers/meal_calendar_provider.dart';

/// Provides [RecipeCatalogReader] (`MOD-03` integration point).
final recipeCatalogReaderProvider = Provider<RecipeCatalogReader>((ref) {
  return FirestoreRecipeCatalogReader();
});

/// Provides [FoodCatalogReader] (`MOD-01` integration point).
final foodCatalogReaderProvider = Provider<FoodCatalogReader>((ref) {
  return FirestoreFoodCatalogReader();
});

/// Provides [MealService] for adding and managing meal items.
final mealServiceProvider = Provider<MealService>((ref) {
  return MealService(
    mealRepository: ref.watch(mealRepositoryProvider),
    recipeReader: ref.watch(recipeCatalogReaderProvider),
    foodReader: ref.watch(foodCatalogReaderProvider),
  );
});

enum _AddDishTab {
  recipe('Công thức'),
  standaloneFood('Thực phẩm ăn liền');

  const _AddDishTab(this.labelVi);
  final String labelVi;
}

/// Screen to add a recipe (`MOD-04-03`) or standalone food (`MOD-04-04`) to a planned meal.
///
/// Adding items here never deducts pantry stock.
class AddDishScreen extends ConsumerStatefulWidget {
  const AddDishScreen({
    super.key,
    required this.meal,
  });

  final Meal meal;

  @override
  ConsumerState<AddDishScreen> createState() => _AddDishScreenState();
}

class _AddDishScreenState extends ConsumerState<AddDishScreen> {
  static const Color _primary = Color(0xFF16A36A);
  static const Color _background = Color(0xFFF7F9F7);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _border = Color(0xFFE5EBE6);
  static const Color _textPrimary = Color(0xFF202B26);
  static const Color _textSecondary = Color(0xFF77847C);

  final TextEditingController _searchController = TextEditingController();
  _AddDishTab _activeTab = _AddDishTab.recipe;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorText;
  List<RecipeSummary> _recipes = const [];
  List<FoodSummary> _foods = const [];

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || userId.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final query = _searchController.text;
      if (_activeTab == _AddDishTab.recipe) {
        final result = await ref
            .read(recipeCatalogReaderProvider)
            .searchAccessibleRecipes(userId, query: query);
        if (!mounted) return;
        setState(() => _recipes = result);
      } else {
        final result =
            await ref.read(foodCatalogReaderProvider).searchFoods(query: query);
        if (!mounted) return;
        setState(() => _foods = result);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = 'Không tải được danh sách: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onSelectRecipe(RecipeSummary recipe) async {
    final servings = await _promptQuantity(
      title: recipe.name,
      fieldLabel: 'Số khẩu phần',
      initialValue: recipe.baseServings > 0 ? recipe.baseServings : 1,
    );
    if (servings == null || !mounted) return;

    await _runSubmit(() async {
      await ref.read(mealServiceProvider).addRecipeDish(
            userId: widget.meal.userId,
            mealId: widget.meal.id,
            recipeId: recipe.id,
            servings: servings,
          );
    }, successMessage: 'Đã thêm "${recipe.name}" vào kế hoạch (chưa trừ kho).');
  }

  Future<void> _onSelectFood(FoodSummary food) async {
    final foodReader = ref.read(foodCatalogReaderProvider);
    final units = await foodReader.getCompatibleUnits(food.baseUnitId);
    if (!mounted) return;

    if (units.isEmpty) {
      _showSnackBar('Thực phẩm chưa có đơn vị quy đổi hợp lệ.', isError: true);
      return;
    }

    final result = await _promptFoodQuantityAndUnit(food: food, units: units);
    if (result == null || !mounted) return;

    await _runSubmit(() async {
      await ref.read(mealServiceProvider).addStandaloneFood(
            userId: widget.meal.userId,
            mealId: widget.meal.id,
            foodId: food.id,
            unitId: result.unit.id,
            quantity: result.quantity,
          );
    }, successMessage: 'Đã thêm "${food.name}" vào kế hoạch (chưa trừ kho).');
  }

  Future<void> _runSubmit(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    setState(() => _isSubmitting = true);
    try {
      await action();
      if (!mounted) return;
      _showSnackBar(successMessage);
      Navigator.of(context).pop(true);
    } on MealPlanException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Thêm món thất bại: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<double?> _promptQuantity({
    required String title,
    required String fieldLabel,
    required double initialValue,
  }) async {
    final controller = TextEditingController(
      text: initialValue == initialValue.roundToDouble()
          ? initialValue.toInt().toString()
          : initialValue.toString(),
    );
    String? error;

    return showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: fieldLabel,
              errorText: error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text.trim());
                if (parsed == null || parsed <= 0) {
                  setDialogState(() => error = 'Vui lòng nhập số > 0');
                  return;
                }
                Navigator.of(ctx).pop(parsed);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Thêm vào bữa'),
            ),
          ],
        ),
      ),
    );
  }

  Future<({double quantity, UnitInfo unit})?> _promptFoodQuantityAndUnit({
    required FoodSummary food,
    required List<UnitInfo> units,
  }) async {
    final controller = TextEditingController(text: '1');
    UnitInfo selectedUnit = units.firstWhere(
      (u) => u.id == food.baseUnitId,
      orElse: () => units.first,
    );
    String? error;

    return showDialog<({double quantity, UnitInfo unit})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(food.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Số lượng dự kiến',
                  errorText: error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<UnitInfo>(
                value: selectedUnit,
                decoration: InputDecoration(
                  labelText: 'Đơn vị',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: units
                    .map(
                      (u) => DropdownMenuItem(
                        value: u,
                        child: Text('${u.name} (${u.symbol})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedUnit = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text.trim());
                if (parsed == null || parsed <= 0) {
                  setDialogState(() => error = 'Vui lòng nhập số > 0');
                  return;
                }
                Navigator.of(ctx).pop((quantity: parsed, unit: selectedUnit));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Thêm vào bữa'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFEF4444) : _primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Thêm món · Bữa ${widget.meal.slot.labelVi}',
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFFEFF6FF),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const Text(
                  'Đã lên lịch · Thêm món vào kế hoạch chưa trừ tồn kho',
                  style: TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildTabAndSearch(),
              Expanded(child: _buildListBody()),
            ],
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: _primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabAndSearch() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        children: [
          Row(
            children: _AddDishTab.values.map((tab) {
              final selected = tab == _activeTab;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: tab == _AddDishTab.recipe ? 6 : 0,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      if (_activeTab == tab) return;
                      setState(() => _activeTab = tab);
                      _loadCatalog();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? _primary : _background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? _primary : _border,
                        ),
                      ),
                      child: Text(
                        tab.labelVi,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? Colors.white : _textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onSubmitted: (_) => _loadCatalog(),
            decoration: InputDecoration(
              hintText: _activeTab == _AddDishTab.recipe
                  ? 'Tìm công thức nấu ăn...'
                  : 'Tìm thực phẩm ăn liền...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: _loadCatalog,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              filled: true,
              fillColor: _background,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _border),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (_errorText != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorText!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFEF4444)),
          ),
        ),
      );
    }

    if (_activeTab == _AddDishTab.recipe) {
      if (_recipes.isEmpty) {
        return const Center(
          child: Text(
            'Không có công thức phù hợp.',
            style: TextStyle(color: _textSecondary),
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _recipes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final recipe = _recipes[index];
          return _CatalogCard(
            icon: Icons.menu_book_rounded,
            title: recipe.name,
            subtitle:
                '${recipe.baseServings} khẩu phần · ${recipe.cookingMinutes} phút',
            onTap: () => _onSelectRecipe(recipe),
          );
        },
      );
    }

    if (_foods.isEmpty) {
      return const Center(
        child: Text(
          'Không có thực phẩm phù hợp.',
          style: TextStyle(color: _textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _foods.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final food = _foods[index];
        return _CatalogCard(
          icon: Icons.fastfood_outlined,
          title: food.name,
          subtitle: 'Đơn vị cơ sở: ${food.baseUnitId}',
          onTap: () => _onSelectFood(food),
        );
      },
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _AddDishScreenState._surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _AddDishScreenState._border),
        ),
        child: Row(
          children: [
            Icon(icon, color: _AddDishScreenState._primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _AddDishScreenState._textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _AddDishScreenState._textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.add_circle_outline_rounded,
              color: _AddDishScreenState._primary,
            ),
          ],
        ),
      ),
    );
  }
}

