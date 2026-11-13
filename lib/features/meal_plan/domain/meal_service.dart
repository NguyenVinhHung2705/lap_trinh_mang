import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/meal_repository.dart';
import '../data/models/meal.dart';
import '../data/models/meal_item.dart';

/// Read-only projection of a recipe (`cong_thuc`, owned by `MOD-03`).
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

  /// Enforces recipe access control (`MOD-04-03`).
  bool canUserAccess(String userId) {
    final normalized = visibility.trim().toUpperCase();
    return normalized == 'PUBLIC' ||
        normalized == 'SYSTEM' ||
        authorId == userId;
  }
}

/// Read-only projection of a recipe ingredient (`nguyen_lieu_cong_thuc`, owned by `MOD-03`).
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

/// Read-only projection of a food item (`thuc_pham`, owned by `MOD-01`).
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

/// Read-only projection of a measurement unit (`don_vi`, owned by `MOD-01`).
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

  /// Checks whether this unit can convert to [baseUnit] (`MOD-04-04`).
  bool isConvertibleTo(UnitInfo baseUnit) {
    if (id == baseUnit.id) return true;
    final groupA = measurementGroup.trim().toUpperCase();
    final groupB = baseUnit.measurementGroup.trim().toUpperCase();
    // Discrete count units (e.g. quả vs gói) require an exact unit match unless converted externally.
    return groupA == groupB && groupA != 'COUNT';
  }
}

/// Integration contract for reading recipes from `MOD-03`.
abstract interface class RecipeCatalogReader {
  Future<RecipeSummary?> getRecipe(String recipeId);
  Future<List<RecipeSummary>> searchAccessibleRecipes(
    String userId, {
    String query = '',
  });
  Future<List<RecipeIngredientDto>> getRecipeIngredients(String recipeId);
}

/// Integration contract for reading foods and units from `MOD-01`.
abstract interface class FoodCatalogReader {
  Future<FoodSummary?> getFood(String foodId);
  Future<List<FoodSummary>> searchFoods({String query = ''});
  Future<UnitInfo?> getUnit(String unitId);
  Future<List<UnitInfo>> getCompatibleUnits(String baseUnitId);
}

/// Default Firestore implementation of [RecipeCatalogReader] over `cong_thuc`.
class FirestoreRecipeCatalogReader implements RecipeCatalogReader {
  FirestoreRecipeCatalogReader({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<RecipeSummary?> getRecipe(String recipeId) async {
    final doc = await _firestore.collection('cong_thuc').doc(recipeId).get();
    if (!doc.exists || doc.data() == null) return null;
    return _mapRecipe(doc.id, doc.data()!);
  }

  @override
  Future<List<RecipeSummary>> searchAccessibleRecipes(
    String userId, {
    String query = '',
  }) async {
    final snapshot = await _firestore.collection('cong_thuc').limit(100).get();
    final lowerQuery = query.trim().toLowerCase();
    return snapshot.docs
        .map((doc) => _mapRecipe(doc.id, doc.data()))
        .where((recipe) => recipe.canUserAccess(userId))
        .where(
          (recipe) =>
              lowerQuery.isEmpty ||
              recipe.name.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }

  @override
  Future<List<RecipeIngredientDto>> getRecipeIngredients(String recipeId) async {
    final snapshot = await _firestore
        .collection('cong_thuc')
        .doc(recipeId)
        .collection('nguyen_lieu')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return RecipeIngredientDto(
        foodId: data['ma_thuc_pham'] as String? ?? doc.id,
        unitId: data['ma_don_vi'] as String? ?? '',
        quantity: (data['so_luong'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  static RecipeSummary _mapRecipe(String id, Map<String, dynamic> data) {
    return RecipeSummary(
      id: id,
      authorId: data['ma_tac_gia'] as String? ?? '',
      name: data['ten_mon'] as String? ?? 'Công thức',
      baseServings: (data['khau_phan'] as num?)?.toDouble() ?? 1,
      visibility: data['pham_vi_hien_thi'] as String? ?? 'PRIVATE',
      cookingMinutes: (data['thoi_gian_nau'] as num?)?.toInt() ?? 0,
      imageUrl: data['hinh_anh'] as String?,
    );
  }
}

/// Default Firestore implementation of [FoodCatalogReader] over `thuc_pham` & `don_vi`.
class FirestoreFoodCatalogReader implements FoodCatalogReader {
  FirestoreFoodCatalogReader({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<FoodSummary?> getFood(String foodId) async {
    final doc = await _firestore.collection('thuc_pham').doc(foodId).get();
    if (!doc.exists || doc.data() == null) return null;
    return _mapFood(doc.id, doc.data()!);
  }

  @override
  Future<List<FoodSummary>> searchFoods({String query = ''}) async {
    final snapshot = await _firestore.collection('thuc_pham').limit(100).get();
    final lowerQuery = query.trim().toLowerCase();
    return snapshot.docs
        .map((doc) => _mapFood(doc.id, doc.data()))
        .where(
          (food) =>
              lowerQuery.isEmpty ||
              food.name.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }

  @override
  Future<UnitInfo?> getUnit(String unitId) async {
    final doc = await _firestore.collection('don_vi').doc(unitId).get();
    if (!doc.exists || doc.data() == null) return null;
    return _mapUnit(doc.id, doc.data()!);
  }

  @override
  Future<List<UnitInfo>> getCompatibleUnits(String baseUnitId) async {
    final baseUnit = await getUnit(baseUnitId);
    if (baseUnit == null) return const <UnitInfo>[];

    final snapshot = await _firestore.collection('don_vi').get();
    return snapshot.docs
        .map((doc) => _mapUnit(doc.id, doc.data()))
        .where((unit) => unit.isConvertibleTo(baseUnit))
        .toList();
  }

  static FoodSummary _mapFood(String id, Map<String, dynamic> data) {
    return FoodSummary(
      id: id,
      name: data['ten_thuc_pham'] as String? ?? 'Thực phẩm',
      baseUnitId: data['ma_don_vi_co_so'] as String? ?? '',
      imageUrl: data['hinh_anh'] as String?,
    );
  }

  static UnitInfo _mapUnit(String id, Map<String, dynamic> data) {
    return UnitInfo(
      id: id,
      name: data['ten_don_vi'] as String? ?? '',
      symbol: data['ky_hieu'] as String? ?? id,
      measurementGroup: data['nhom_do_luong'] as String? ?? 'COUNT',
      toBaseFactor: (data['he_so_quy_doi'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// Domain service for planning operations (`MOD-04-03`, `MOD-04-04`, and `MOD-04-05`).
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

  /// Adds a recipe dish to a `PLANNED` meal (`MOD-04-03`). Never deducts stock.
  Future<MealItem> addRecipeDish({
    required String userId,
    required String mealId,
    required String recipeId,
    required double servings,
  }) async {
    _requirePositive(servings, 'Số khẩu phần phải lớn hơn 0.');
    await _requirePlannedMeal(userId, mealId);

    final recipe = await _recipeReader.getRecipe(recipeId);
    if (recipe == null) {
      throw const MealPlanException('Không tìm thấy công thức nấu ăn.');
    }
    if (!recipe.canUserAccess(userId)) {
      throw const MealPlanException('Bạn không có quyền sử dụng công thức này.');
    }

    final item = MealItem.recipe(
      id: 'new',
      mealId: mealId,
      recipeId: recipeId,
      servings: servings,
    );
    return _mealRepository.addMealItem(userId: userId, item: item);
  }

  /// Adds a standalone ready-to-eat food to a `PLANNED` meal (`MOD-04-04`). Never deducts stock.
  Future<MealItem> addStandaloneFood({
    required String userId,
    required String mealId,
    required String foodId,
    required String unitId,
    required double quantity,
  }) async {
    _requirePositive(quantity, 'Số lượng sử dụng phải lớn hơn 0.');
    await _requirePlannedMeal(userId, mealId);

    final food = await _foodReader.getFood(foodId);
    if (food == null) {
      throw const MealPlanException('Không tìm thấy thực phẩm.');
    }
    final unit = await _foodReader.getUnit(unitId);
    final baseUnit = await _foodReader.getUnit(food.baseUnitId);
    if (unit == null || baseUnit == null) {
      throw const MealPlanException('Đơn vị tính không hợp lệ.');
    }
    if (!unit.isConvertibleTo(baseUnit)) {
      throw MealPlanException(
        'Đơn vị "${unit.symbol}" không quy đổi được về đơn vị tồn kho "${baseUnit.symbol}".',
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

  /// Updates quantity/servings of an item in a `PLANNED` meal (`MOD-04-05`).
  Future<void> updateItemQuantity({
    required String userId,
    required String mealId,
    required String itemId,
    required double quantity,
  }) async {
    _requirePositive(quantity, 'Số lượng hoặc khẩu phần phải lớn hơn 0.');
    await _mealRepository.updateMealItemQuantity(
      userId: userId,
      mealId: mealId,
      itemId: itemId,
      quantity: quantity,
    );
  }

  /// Removes an item from a `PLANNED` meal (`MOD-04-05`). Does not affect stock.
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

  /// Moves a `PLANNED` meal to a new date and slot (`MOD-04-05`).
  ///
  /// Invokes [onReminderRescheduled] if the moved meal has an active reminder.
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

  /// Cancels a `PLANNED` meal (`MOD-04-05`). Never modifies `COMPLETED` meals or stock.
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
    final meal = await _mealRepository.getMealById(userId: userId, mealId: mealId);
    if (meal == null) {
      throw const MealNotFoundException();
    }
    if (meal.isCompleted) {
      throw const MealAlreadyCompletedException();
    }
    if (meal.isCancelled) {
      throw const MealPlanException('Bữa ăn đã bị hủy.');
    }
    return meal;
  }

  static void _requirePositive(double value, String message) {
    if (value <= 0 || value.isNaN || value.isInfinite) {
      throw MealPlanException(message);
    }
  }
}

