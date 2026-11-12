/// Discriminator for the single allowed source of a [MealItem].
enum MealItemSourceType {
  recipe,
  standaloneFood,
}

/// Represents a planned dish or standalone ready-to-eat food in a meal (`mon_an_ke_hoach`).
///
/// Enforces the schema XOR invariant: exactly one of [recipeId] or [foodId] must be set,
/// and [quantity] must be strictly positive.
class MealItem {
  MealItem({
    required this.id,
    required this.mealId,
    this.recipeId,
    this.foodId,
    this.unitId,
    required this.quantity,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'MealItem id must not be empty');
    }
    if (mealId.trim().isEmpty) {
      throw ArgumentError.value(mealId, 'mealId', 'Meal id must not be empty');
    }
    final hasRecipe = recipeId != null && recipeId!.trim().isNotEmpty;
    final hasFood = foodId != null && foodId!.trim().isNotEmpty;
    // Mirrors SQL: CHECK ((ma_cong_thuc IS NOT NULL) + (ma_thuc_pham IS NOT NULL) = 1)
    if (hasRecipe == hasFood) {
      throw ArgumentError(
        'MealItem must specify exactly one of recipeId or foodId (XOR)',
      );
    }
    if (hasFood && (unitId == null || unitId!.trim().isEmpty)) {
      throw ArgumentError(
        'Standalone food MealItem requires a non-empty unitId',
      );
    }
    if (hasRecipe && unitId != null) {
      throw ArgumentError(
        'Recipe MealItem uses servings in quantity and must have unitId == null',
      );
    }
    if (quantity <= 0 || quantity.isNaN || quantity.isInfinite) {
      throw ArgumentError.value(
        quantity,
        'so_luong',
        'Quantity/servings must be a finite number > 0',
      );
    }
  }

  /// Convenience constructor for a dish linked to a recipe (`MOD-04-03`).
  factory MealItem.recipe({
    required String id,
    required String mealId,
    required String recipeId,
    required double servings,
  }) {
    return MealItem(
      id: id,
      mealId: mealId,
      recipeId: recipeId,
      foodId: null,
      unitId: null,
      quantity: servings,
    );
  }

  /// Convenience constructor for a standalone ready-to-eat food (`MOD-04-04`).
  factory MealItem.standaloneFood({
    required String id,
    required String mealId,
    required String foodId,
    required String unitId,
    required double quantity,
  }) {
    return MealItem(
      id: id,
      mealId: mealId,
      recipeId: null,
      foodId: foodId,
      unitId: unitId,
      quantity: quantity,
    );
  }

  /// Firestore document ID (`ma_mon_an`).
  final String id;

  /// Parent meal ID (`ma_bua_an`).
  final String mealId;

  /// Referenced recipe ID (`ma_cong_thuc`), mutually exclusive with [foodId].
  final String? recipeId;

  /// Referenced standalone food ID (`ma_thuc_pham`), mutually exclusive with [recipeId].
  final String? foodId;

  /// Unit ID for [foodId] (`ma_don_vi`); null for recipe items.
  final String? unitId;

  /// Servings (for recipe) or quantity in [unitId] (for standalone food) (`so_luong`, > 0).
  final double quantity;

  MealItemSourceType get sourceType =>
      recipeId != null ? MealItemSourceType.recipe : MealItemSourceType.standaloneFood;

  bool get isRecipe => sourceType == MealItemSourceType.recipe;
  bool get isStandaloneFood => sourceType == MealItemSourceType.standaloneFood;

  /// Serializes to a Firestore-compatible map using the project's canonical field names.
  Map<String, Object?> toMap() {
    return {
      'ma_bua_an': mealId,
      'ma_cong_thuc': recipeId,
      'ma_thuc_pham': foodId,
      'ma_don_vi': unitId,
      'so_luong': quantity,
    };
  }

  /// Deserializes a map into [MealItem].
  factory MealItem.fromMap(Map<String, Object?> map, {required String id}) {
    final rawMealId = map['ma_bua_an'] as String?;
    final rawQuantity = map['so_luong'] as num?;

    if (rawMealId == null || rawQuantity == null) {
      throw FormatException('Missing required fields in MealItem map for id=$id');
    }

    return MealItem(
      id: id,
      mealId: rawMealId,
      recipeId: map['ma_cong_thuc'] as String?,
      foodId: map['ma_thuc_pham'] as String?,
      unitId: map['ma_don_vi'] as String?,
      quantity: rawQuantity.toDouble(),
    );
  }

  /// Creates a copy with updated quantity/servings. Source XOR fields are kept consistent.
  MealItem copyWith({
    String? id,
    String? mealId,
    double? quantity,
    String? unitId,
  }) {
    return MealItem(
      id: id ?? this.id,
      mealId: mealId ?? this.mealId,
      recipeId: recipeId,
      foodId: foodId,
      unitId: isStandaloneFood ? (unitId ?? this.unitId) : null,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MealItem &&
        other.id == id &&
        other.mealId == mealId &&
        other.recipeId == recipeId &&
        other.foodId == foodId &&
        other.unitId == unitId &&
        other.quantity == quantity;
  }

  @override
  int get hashCode => Object.hash(id, mealId, recipeId, foodId, unitId, quantity);

  @override
  String toString() {
    if (isRecipe) {
      return 'MealItem.recipe(id: $id, mealId: $mealId, recipeId: $recipeId, servings: $quantity)';
    }
    return 'MealItem.standaloneFood(id: $id, mealId: $mealId, foodId: $foodId, unitId: $unitId, quantity: $quantity)';
  }
}

