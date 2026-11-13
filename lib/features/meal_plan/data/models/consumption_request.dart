import '../models/meal.dart';
import '../models/meal_item.dart';
import '../../domain/meal_service.dart';
import '../meal_repository.dart';

/// Single normalized ingredient line prepared for meal completion (`MOD-04-07`).
///
/// Quantities are normalized to the food's inventory base unit ([baseUnitId]).
class ConsumptionItem {
  ConsumptionItem({
    required this.mealItemId,
    required this.foodId,
    required this.foodName,
    required this.sourceLabel,
    required this.baseUnitId,
    required this.baseUnitSymbol,
    required this.expectedQuantity,
    required this.actualQuantity,
    this.isIncluded = true,
  }) {
    if (expectedQuantity < 0 || expectedQuantity.isNaN || expectedQuantity.isInfinite) {
      throw ArgumentError.value(
        expectedQuantity,
        'expectedQuantity',
        'Expected quantity must be >= 0',
      );
    }
    if (actualQuantity < 0 || actualQuantity.isNaN || actualQuantity.isInfinite) {
      throw ArgumentError.value(
        actualQuantity,
        'actualQuantity',
        'Actual quantity must be >= 0',
      );
    }
  }

  /// Source `mon_an_ke_hoach` document ID (`ma_mon_an`).
  final String mealItemId;

  /// Referenced food ID (`ma_thuc_pham`).
  final String foodId;

  /// Display name of the food for confirmation UI.
  final String foodName;

  /// Name of the dish/recipe or standalone source for user clarity.
  final String sourceLabel;

  /// Base unit ID matching `thuc_pham.ma_don_vi_co_so`.
  final String baseUnitId;

  /// Display symbol of [baseUnitId] (e.g. `g`, `ml`, `quả`).
  final String baseUnitSymbol;

  /// Expected quantity calculated from recipe servings or standalone plan.
  final double expectedQuantity;

  /// User-adjusted actual quantity in [baseUnitId] (`>= 0`).
  final double actualQuantity;

  /// Allows excluding an unused ingredient (`MOD-04-07`).
  final bool isIncluded;

  double get effectiveQuantity => isIncluded ? actualQuantity : 0.0;

  ConsumptionItem copyWith({
    double? actualQuantity,
    bool? isIncluded,
  }) {
    return ConsumptionItem(
      mealItemId: mealItemId,
      foodId: foodId,
      foodName: foodName,
      sourceLabel: sourceLabel,
      baseUnitId: baseUnitId,
      baseUnitSymbol: baseUnitSymbol,
      expectedQuantity: expectedQuantity,
      actualQuantity: actualQuantity ?? this.actualQuantity,
      isIncluded: isIncluded ?? this.isIncluded,
    );
  }
}

/// User-approved consumption payload produced by `MOD-04-07` and consumed by `MOD-04-08`.
class ConsumptionRequest {
  ConsumptionRequest({
    required this.userId,
    required this.meal,
    required List<ConsumptionItem> items,
  }) : items = List.unmodifiable(
          items.where((item) => item.effectiveQuantity > 0),
        ) {
    if (!meal.isPlanned) {
      throw const MealAlreadyCompletedException(
        'Chỉ có thể xác nhận tiêu thụ cho bữa ăn chưa hoàn thành.',
      );
    }
    if (this.items.isEmpty) {
      throw const MealPlanException(
        'Phải có ít nhất một nguyên liệu với lượng dùng lớn hơn 0.',
      );
    }
  }

  final String userId;
  final Meal meal;

  /// Only active items with `effectiveQuantity > 0`.
  final List<ConsumptionItem> items;

  /// Aggregates total quantity needed per `foodId` in base units for atomic pre-check.
  Map<String, double> get totalByFoodId {
    final totals = <String, double>{};
    for (final item in items) {
      totals[item.foodId] = (totals[item.foodId] ?? 0) + item.effectiveQuantity;
    }
    return totals;
  }
}

/// Builds expected [ConsumptionItem] entries normalized to inventory base units (`MOD-04-07`).
///
/// Purely read-only; never writes to stock or changes meal status.
class ConsumptionEstimator {
  const ConsumptionEstimator({
    required RecipeCatalogReader recipeReader,
    required FoodCatalogReader foodReader,
  })  : _recipeReader = recipeReader,
        _foodReader = foodReader;

  final RecipeCatalogReader _recipeReader;
  final FoodCatalogReader _foodReader;

  Future<List<ConsumptionItem>> buildExpectedItems(List<MealItem> mealItems) async {
    final result = <ConsumptionItem>[];

    for (final mealItem in mealItems) {
      if (mealItem.isRecipe) {
        final recipeId = mealItem.recipeId!;
        final recipe = await _recipeReader.getRecipe(recipeId);
        if (recipe == null) {
          throw MealPlanException('Không tìm thấy công thức ($recipeId).');
        }
        final baseServings = recipe.baseServings > 0 ? recipe.baseServings : 1.0;
        final scale = mealItem.quantity / baseServings;
        final ingredients = await _recipeReader.getRecipeIngredients(recipeId);

        for (final ing in ingredients) {
          final normalized = await _normalizeLine(
            mealItemId: mealItem.id,
            foodId: ing.foodId,
            unitId: ing.unitId,
            rawQuantity: ing.quantity * scale,
            sourceLabel: recipe.name,
          );
          result.add(normalized);
        }
      } else {
        final normalized = await _normalizeLine(
          mealItemId: mealItem.id,
          foodId: mealItem.foodId!,
          unitId: mealItem.unitId!,
          rawQuantity: mealItem.quantity,
          sourceLabel: 'Thực phẩm ăn liền',
        );
        result.add(normalized);
      }
    }

    return result;
  }

  Future<ConsumptionItem> _normalizeLine({
    required String mealItemId,
    required String foodId,
    required String unitId,
    required double rawQuantity,
    required String sourceLabel,
  }) async {
    final food = await _foodReader.getFood(foodId);
    if (food == null) {
      throw MealPlanException('Không tìm thấy thực phẩm ($foodId).');
    }
    final unit = await _foodReader.getUnit(unitId);
    final baseUnit = await _foodReader.getUnit(food.baseUnitId);
    if (unit == null || baseUnit == null) {
      throw MealPlanException(
        'Thiếu thông tin đơn vị cho thực phẩm "${food.name}".',
      );
    }
    if (!unit.isConvertibleTo(baseUnit) || baseUnit.toBaseFactor <= 0) {
      throw MealPlanException(
        'Không thể quy đổi đơn vị "${unit.symbol}" sang "${baseUnit.symbol}" cho "${food.name}".',
      );
    }

    final normalizedQty =
        rawQuantity * (unit.toBaseFactor / baseUnit.toBaseFactor);

    return ConsumptionItem(
      mealItemId: mealItemId,
      foodId: food.id,
      foodName: food.name,
      sourceLabel: sourceLabel,
      baseUnitId: baseUnit.id,
      baseUnitSymbol: baseUnit.symbol,
      expectedQuantity: normalizedQty,
      actualQuantity: normalizedQty,
    );
  }
}

