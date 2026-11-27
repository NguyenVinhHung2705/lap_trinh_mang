import 'package:supabase_flutter/supabase_flutter.dart';

import '../../pantry/data/models/food_item.dart';
import '../../pantry/data/pantry_mock_data.dart';
import '../../recipe/data/recipe_mock_data.dart';
import '../data/meal_repository.dart';
import '../data/models/meal.dart';
import '../data/models/meal_item.dart';

/// Read-only projection of a recipe (`cong_thuc`, owned by MOD-03).
class RecipeSummary {
  const RecipeSummary({
    required this.id,
    required this.authorId,
    required this.name,
    required this.baseServings,
    required this.visibility,
    this.cookingMinutes = 0,
    this.imageUrl,
  });

  final String id;
  final String authorId;
  final String name;
  final double baseServings;
  final String visibility;
  final int cookingMinutes;
  final String? imageUrl;

  /// Enforces recipe access control (MOD-04-03).
  bool canUserAccess(String userId) {
    final normalized = visibility.trim().toUpperCase();
    return normalized == 'PUBLIC' ||
        normalized == 'SYSTEM' ||
        authorId == userId;
  }
}

/// Read-only projection of a recipe ingredient (`nguyen_lieu_cong_thuc`, owned by MOD-03).
class RecipeIngredientDto {
  const RecipeIngredientDto({
    required this.foodId,
    required this.unitId,
    required this.quantity,
  });

  final String foodId;
  final String unitId;

  /// Quantity required for the recipe's [RecipeSummary.baseServings].
  final double quantity;
}

/// Read-only projection of a food item (`thuc_pham`, owned by MOD-01).
class FoodSummary {
  const FoodSummary({
    required this.id,
    required this.name,
    required this.baseUnitId,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String baseUnitId;
  final String? imageUrl;
}

/// Read-only projection of a measurement unit (`don_vi`, owned by MOD-01).
class UnitInfo {
  const UnitInfo({
    required this.id,
    required this.name,
    required this.symbol,
    required this.measurementGroup,
    this.toBaseFactor = 1.0,
  });

  final String id;
  final String name;
  final String symbol;

  /// Measurement group such as `MASS`, `VOLUME`, or `COUNT`.
  final String measurementGroup;

  /// Multiplier to convert a value in this unit into the group's base unit.
  final double toBaseFactor;

  /// Checks whether this unit can convert to [baseUnit] (MOD-04-04).
  bool isConvertibleTo(UnitInfo baseUnit) {
    if (id == baseUnit.id) return true;
    final groupA = measurementGroup.trim().toUpperCase();
    final groupB = baseUnit.measurementGroup.trim().toUpperCase();
    return groupA == groupB && groupA != 'COUNT';
  }
}

/// Integration contract for reading recipes from MOD-03.
abstract interface class RecipeCatalogReader {
  Future<RecipeSummary?> getRecipe(String recipeId);
  Future<List<RecipeSummary>> searchAccessibleRecipes(
    String userId, {
    String query = '',
  });
  Future<List<RecipeIngredientDto>> getRecipeIngredients(String recipeId);
}

/// Integration contract for reading foods and units from MOD-01.
abstract interface class FoodCatalogReader {
  Future<FoodSummary?> getFood(String foodId);
  Future<List<FoodSummary>> searchFoods({String query = ''});
  Future<UnitInfo?> getUnit(String unitId);
  Future<List<UnitInfo>> getCompatibleUnits(String baseUnitId);
}

/// Supabase implementation of [RecipeCatalogReader] over `cong_thuc` table.
class SupabaseRecipeCatalogReader implements RecipeCatalogReader {
  SupabaseRecipeCatalogReader({SupabaseClient? supabase})
      : _customSupabase = supabase;

  final SupabaseClient? _customSupabase;
  SupabaseClient get _db => _customSupabase ?? Supabase.instance.client;

  @override
  Future<RecipeSummary?> getRecipe(String recipeId) async {
    try {
      final rows = await _db
          .from('cong_thuc')
          .select()
          .eq('id', recipeId)
          .limit(1);
      if (rows.isNotEmpty) {
        return _mapRecipe(rows.first);
      }
    } catch (_) {}

    // Fallback to mock data
    final mock = RecipeMockData.initialRecipes.cast<dynamic>().firstWhere(
          (r) => r.id == recipeId,
          orElse: () => null,
        );
    if (mock != null) {
      return RecipeSummary(
        id: mock.id,
        authorId: mock.authorId,
        name: mock.name,
        baseServings: (mock.baseServings as num).toDouble(),
        visibility: mock.visibility.name.toUpperCase(),
        cookingMinutes: mock.cookingMinutes,
        imageUrl: mock.imageUrl,
      );
    }
    return null;
  }

  @override
  Future<List<RecipeSummary>> searchAccessibleRecipes(
    String userId, {
    String query = '',
  }) async {
    final lowerQuery = query.trim().toLowerCase();
    try {
      final rows = await _db.from('cong_thuc').select().limit(100);
      if (rows.isNotEmpty) {
        return rows
            .map<RecipeSummary>((r) => _mapRecipe(r))
            .where((recipe) => recipe.canUserAccess(userId))
            .where((recipe) =>
                lowerQuery.isEmpty ||
                recipe.name.toLowerCase().contains(lowerQuery))
            .toList();
      }
    } catch (_) {}

    return RecipeMockData.initialRecipes
        .where((recipe) =>
            lowerQuery.isEmpty ||
            recipe.name.toLowerCase().contains(lowerQuery))
        .map<RecipeSummary>((r) => RecipeSummary(
              id: r.id,
              authorId: r.authorId,
              name: r.name,
              baseServings: r.baseServings.toDouble(),
              visibility: r.visibility.name.toUpperCase(),
              cookingMinutes: r.cookingMinutes,
              imageUrl: r.imageUrl,
            ))
        .toList();
  }

  @override
  Future<List<RecipeIngredientDto>> getRecipeIngredients(
      String recipeId) async {
    try {
      final rows = await _db
          .from('nguyen_lieu_cong_thuc')
          .select()
          .eq('cong_thuc_id', recipeId);
      if (rows.isNotEmpty) {
        return rows
            .map<RecipeIngredientDto>((r) => RecipeIngredientDto(
                  foodId: r['thuc_pham_id'] as String? ?? '',
                  unitId: r['don_vi_id'] as String? ?? '',
                  quantity: (r['so_luong_co_so'] as num?)?.toDouble() ?? 0,
                ))
            .toList();
      }
    } catch (_) {}

    final ingredients = RecipeMockData.initialIngredients[recipeId];
    if (ingredients != null) {
      return ingredients
          .map<RecipeIngredientDto>((i) => RecipeIngredientDto(
                foodId: i.foodId,
                unitId: i.unitId,
                quantity: i.baseQuantity,
              ))
          .toList();
    }
    return const [];
  }

  static RecipeSummary _mapRecipe(Map<String, dynamic> data) {
    return RecipeSummary(
      id: data['id']?.toString() ?? '',
      authorId: data['ma_tac_gia'] as String? ?? '',
      name: data['ten'] as String? ?? 'CÃ´ng thá»©c',
      baseServings: (data['khau_phan'] as num?)?.toDouble() ?? 1,
      // Shared schema: loai = 'SYSTEM' | 'USER'. USER recipes are private to author.
      visibility: (data['loai'] as String?)?.toUpperCase() == 'SYSTEM'
          ? 'SYSTEM'
          : 'PRIVATE',
      cookingMinutes: (data['thoi_gian_nau'] as num?)?.toInt() ?? 0,
      imageUrl: data['hinh_anh'] as String?,
    );
  }
}

/// Supabase implementation of [FoodCatalogReader] over `thuc_pham` & `don_vi` tables.
class SupabaseFoodCatalogReader implements FoodCatalogReader {
  SupabaseFoodCatalogReader({SupabaseClient? supabase})
      : _customSupabase = supabase;

  final SupabaseClient? _customSupabase;
  SupabaseClient get _db => _customSupabase ?? Supabase.instance.client;

  @override
  Future<FoodSummary?> getFood(String foodId) async {
    try {
      final rows = await _db
          .from('thuc_pham_global')
          .select()
          .eq('id', foodId)
          .limit(1);
      if (rows.isNotEmpty) {
        return _mapFood(rows.first);
      }
    } catch (_) {}

    // Fallback to mock data
    FoodItem? mock;
    for (final f in PantryMockData.initialFoods) {
      if (f.id == foodId) {
        mock = f;
        break;
      }
    }
    if (mock != null) {
      return FoodSummary(
        id: mock.id,
        name: mock.name,
        baseUnitId: mock.baseUnit,
      );
    }
    return null;
  }

  @override
  Future<List<FoodSummary>> searchFoods({String query = ''}) async {
    final lowerQuery = query.trim().toLowerCase();
    try {
      final rows = await _db.from('thuc_pham_global').select().limit(100);
      if (rows.isNotEmpty) {
        return rows
            .map<FoodSummary>((r) => _mapFood(r))
            .where((food) =>
                lowerQuery.isEmpty ||
                food.name.toLowerCase().contains(lowerQuery))
            .toList();
      }
    } catch (_) {}

    return PantryMockData.initialFoods
        .where((food) =>
            lowerQuery.isEmpty ||
            food.name.toLowerCase().contains(lowerQuery))
        .map<FoodSummary>((f) => FoodSummary(
              id: f.id,
              name: f.name,
              baseUnitId: f.baseUnit,
            ))
        .toList();
  }

  @override
  Future<UnitInfo?> getUnit(String unitId) async {
    try {
      final rows =
          await _db.from('don_vi').select().eq('id', unitId).limit(1);
      if (rows.isNotEmpty) return _mapUnit(rows.first);
    } catch (_) {}
    return _fallbackUnit(unitId);
  }

  /// Offline/demo fallback when `don_vi` has no row for [unitId].
  static UnitInfo? _fallbackUnit(String unitId) {
    final id = unitId.trim();
    if (id.isEmpty) return null;
    final lower = id.toLowerCase();
    const mass = {'g', 'gram', 'kg', 'mg', 'unit_g', 'unit_kg'};
    const volume = {'ml', 'l', 'lit', 'unit_ml', 'unit_l'};
    final group = mass.contains(lower)
        ? 'MASS'
        : volume.contains(lower)
            ? 'VOLUME'
            : 'COUNT';
    return UnitInfo(id: id, name: id, symbol: id, measurementGroup: group);
  }

  @override
  Future<List<UnitInfo>> getCompatibleUnits(String baseUnitId) async {
    final baseUnit = await getUnit(baseUnitId);
    if (baseUnit == null) return const <UnitInfo>[];

    try {
      final rows = await _db.from('don_vi').select();
      return rows
          .map<UnitInfo>((r) => _mapUnit(r))
          .where((unit) => unit.isConvertibleTo(baseUnit))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static FoodSummary _mapFood(Map<String, dynamic> data) {
    return FoodSummary(
      id: data['id'] as String? ?? '',
      name: data['ten'] as String? ?? 'Thá»±c pháº©m',
      baseUnitId: data['don_vi_co_so'] as String? ?? '',
      imageUrl: data['hinh_anh'] as String?,
    );
  }

  static UnitInfo _mapUnit(Map<String, dynamic> data) {
    return UnitInfo(
      id: data['id'] as String? ?? '',
      name: data['ten'] as String? ?? '',
      symbol: data['ky_hieu'] as String? ?? (data['id'] as String? ?? ''),
      measurementGroup: data['nhom_do_luong'] as String? ?? 'COUNT',
    );
  }
}

/// Domain service for planning operations (MOD-04-03, MOD-04-04, MOD-04-05).
class MealService {
  MealService({
    required MealRepository mealRepository,
    required RecipeCatalogReader recipeReader,
    required FoodCatalogReader foodReader,
  })  : _mealRepository = mealRepository,
        _recipeReader = recipeReader,
        _foodReader = foodReader;

  final MealRepository _mealRepository;
  final RecipeCatalogReader _recipeReader;
  final FoodCatalogReader _foodReader;

  /// Adds a recipe dish to a PLANNED meal (MOD-04-03). Never deducts stock.
  Future<MealItem> addRecipeDish({
    required String userId,
    required String mealId,
    required String recipeId,
    required double servings,
  }) async {
    _requirePositive(servings, 'Sá»‘ kháº©u pháº§n pháº£i lá»›n hÆ¡n 0.');
    await _requirePlannedMeal(userId, mealId);

    final recipe = await _recipeReader.getRecipe(recipeId);
    if (recipe == null) {
      throw const MealPlanException('KhÃ´ng tÃ¬m tháº¥y cÃ´ng thá»©c náº¥u Äƒn.');
    }
    if (!recipe.canUserAccess(userId)) {
      throw const MealPlanException('Báº¡n khÃ´ng cÃ³ quyá»n sá»­ dá»¥ng cÃ´ng thá»©c nÃ y.');
    }

    final item = MealItem.recipe(
      id: 'new',
      mealId: mealId,
      recipeId: recipeId,
      servings: servings,
    );
    return _mealRepository.addMealItem(userId: userId, item: item);
  }

  /// Adds a standalone ready-to-eat food to a PLANNED meal (MOD-04-04). Never deducts stock.
  Future<MealItem> addStandaloneFood({
    required String userId,
    required String mealId,
    required String foodId,
    required String unitId,
    required double quantity,
  }) async {
    _requirePositive(quantity, 'Sá»‘ lÆ°á»£ng sá»­ dá»¥ng pháº£i lá»›n hÆ¡n 0.');
    await _requirePlannedMeal(userId, mealId);

    final food = await _foodReader.getFood(foodId);
    if (food == null) {
      throw const MealPlanException('KhÃ´ng tÃ¬m tháº¥y thá»±c pháº©m.');
    }
    final unit = await _foodReader.getUnit(unitId);
    final baseUnit = await _foodReader.getUnit(food.baseUnitId);
    if (unit == null || baseUnit == null) {
      throw const MealPlanException('ÄÆ¡n vá»‹ tÃ­nh khÃ´ng há»£p lá»‡.');
    }
    if (!unit.isConvertibleTo(baseUnit)) {
      throw MealPlanException(
        'ÄÆ¡n vá»‹ "${unit.symbol}" khÃ´ng quy Ä‘á»•i Ä‘Æ°á»£c vá» Ä‘Æ¡n vá»‹ tá»“n kho "${baseUnit.symbol}".',
      );
    }

    final item = MealItem.standaloneFood(
      id: 'new',
      mealId: mealId,
      foodId: foodId,
      unitId: unitId,
      quantity: quantity,
    );
    return _mealRepository.addMealItem(userId: userId, item: item);
  }

  /// Updates quantity/servings of an item in a PLANNED meal (MOD-04-05).
  Future<void> updateItemQuantity({
    required String userId,
    required String mealId,
    required String itemId,
    required double quantity,
  }) async {
    _requirePositive(quantity, 'Sá»‘ lÆ°á»£ng hoáº·c kháº©u pháº§n pháº£i lá»›n hÆ¡n 0.');
    await _mealRepository.updateMealItemQuantity(
      userId: userId,
      mealId: mealId,
      itemId: itemId,
      quantity: quantity,
    );
  }

  /// Removes an item from a PLANNED meal (MOD-04-05). Does not affect stock.
  Future<void> removeItem({
    required String userId,
    required String mealId,
    required String itemId,
  }) async {
    await _mealRepository.removeMealItem(
      userId: userId,
      mealId: mealId,
      itemId: itemId,
    );
  }

  /// Moves a PLANNED meal to a new date and slot (MOD-04-05).
  Future<Meal> rescheduleMeal({
    required String userId,
    required String mealId,
    required DateTime newDate,
    required MealSlot newSlot,
    Future<void> Function(Meal updatedMeal)? onReminderRescheduled,
  }) async {
    final movedMeal = await _mealRepository.rescheduleMeal(
      userId: userId,
      mealId: mealId,
      newDate: newDate,
      newSlot: newSlot,
    );
    if (movedMeal.reminderAt != null && onReminderRescheduled != null) {
      await onReminderRescheduled(movedMeal);
    }
    return movedMeal;
  }

  /// Cancels a PLANNED meal (MOD-04-05). Never modifies COMPLETED meals or stock.
  Future<void> cancelMeal({
    required String userId,
    required String mealId,
    Future<void> Function(String mealId)? onCancelReminders,
  }) async {
    await _mealRepository.cancelMeal(userId: userId, mealId: mealId);
    if (onCancelReminders != null) {
      await onCancelReminders(mealId);
    }
  }

  Future<Meal> _requirePlannedMeal(String userId, String mealId) async {
    final meal =
        await _mealRepository.getMealById(userId: userId, mealId: mealId);
    if (meal == null) {
      throw const MealNotFoundException();
    }
    if (meal.isCompleted) {
      throw const MealAlreadyCompletedException();
    }
    if (meal.isCancelled) {
      throw const MealPlanException('Bá»¯a Äƒn Ä‘Ã£ bá»‹ há»§y.');
    }
    return meal;
  }

  static void _requirePositive(double value, String message) {
    if (value <= 0 || value.isNaN || value.isInfinite) {
      throw MealPlanException(message);
    }
  }
}
