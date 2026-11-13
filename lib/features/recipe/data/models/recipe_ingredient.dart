/// Represents an ingredient line item in a recipe (`nguyen_lieu_cong_thuc`).
///
/// Multiplied dynamically according to target servings using the MOD-03 formula:
/// `scaledQuantity = (baseQuantity * targetServings) / baseServings`.
class RecipeIngredient {
  RecipeIngredient({
    required this.id,
    required this.recipeId,
    required this.foodId,
    required this.foodName,
    required this.unitId,
    required this.unitSymbol,
    required this.baseQuantity,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Ingredient id must not be empty');
    }
    if (recipeId.trim().isEmpty) {
      throw ArgumentError.value(recipeId, 'recipeId', 'Recipe id must not be empty');
    }
    if (foodId.trim().isEmpty) {
      throw ArgumentError.value(foodId, 'foodId', 'Food id must not be empty');
    }
    if (unitId.trim().isEmpty) {
      throw ArgumentError.value(unitId, 'unitId', 'Unit id must not be empty');
    }
    if (baseQuantity <= 0 || baseQuantity.isNaN || baseQuantity.isInfinite) {
      throw ArgumentError.value(
        baseQuantity,
        'so_luong',
        'Base quantity must be a finite number > 0',
      );
    }
  }

  /// Ingredient entry ID (or foodId as unique key per recipe).
  final String id;

  /// Parent recipe ID (`ma_cong_thuc`).
  final String recipeId;

  /// Referenced food catalog ID (`ma_thuc_pham`).
  final String foodId;

  /// Display food name (`ten_thuc_pham`).
  final String foodName;

  /// Referenced unit catalog ID (`ma_don_vi`).
  final String unitId;

  /// Display unit symbol/name, e.g. "g", "kg", "ml", "quả" (`ky_hieu`).
  final String unitSymbol;

  /// Ingredient quantity required for the recipe's base servings (`so_luong`, > 0).
  final double baseQuantity;

  /// Calculates scaled quantity for [targetServings] based on [baseServings].
  ///
  /// Standard MOD-03 scaling formula: `so_luong * targetServings / khau_phan`.
  double calculateScaledQuantity({
    required double targetServings,
    required double baseServings,
  }) {
    if (baseServings <= 0) return baseQuantity;
    if (targetServings <= 0) return 0;
    return (baseQuantity * targetServings) / baseServings;
  }

  /// Serializes to a Firestore map compatible with `nguyen_lieu_cong_thuc`.
  Map<String, Object?> toMap() {
    return {
      'ma_cong_thuc': recipeId,
      'ma_thuc_pham': foodId,
      'ten_thuc_pham': foodName,
      'ma_don_vi': unitId,
      'ky_hieu_don_vi': unitSymbol,
      'so_luong': baseQuantity,
    };
  }

  /// Deserializes a map into [RecipeIngredient].
  factory RecipeIngredient.fromMap(Map<String, Object?> map, {required String id}) {
    final rawRecipeId = map['ma_cong_thuc'] as String? ?? '';
    final rawFoodId = map['ma_thuc_pham'] as String? ?? id;
    final rawFoodName = map['ten_thuc_pham'] as String? ?? 'Nguyên liệu';
    final rawUnitId = map['ma_don_vi'] as String? ?? '';
    final rawUnitSymbol = map['ky_hieu_don_vi'] as String? ?? map['ten_don_vi'] as String? ?? rawUnitId;
    final rawQuantity = (map['so_luong'] as num?)?.toDouble();

    if (rawQuantity == null || rawQuantity <= 0) {
      throw FormatException('Invalid or missing so_luong in RecipeIngredient for id=$id');
    }

    return RecipeIngredient(
      id: id,
      recipeId: rawRecipeId,
      foodId: rawFoodId,
      foodName: rawFoodName,
      unitId: rawUnitId,
      unitSymbol: rawUnitSymbol,
      baseQuantity: rawQuantity,
    );
  }

  RecipeIngredient copyWith({
    String? id,
    String? recipeId,
    String? foodId,
    String? foodName,
    String? unitId,
    String? unitSymbol,
    double? baseQuantity,
  }) {
    return RecipeIngredient(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      unitId: unitId ?? this.unitId,
      unitSymbol: unitSymbol ?? this.unitSymbol,
      baseQuantity: baseQuantity ?? this.baseQuantity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecipeIngredient &&
        other.id == id &&
        other.recipeId == recipeId &&
        other.foodId == foodId &&
        other.foodName == foodName &&
        other.unitId == unitId &&
        other.unitSymbol == unitSymbol &&
        other.baseQuantity == baseQuantity;
  }

  @override
  int get hashCode => Object.hash(
        id,
        recipeId,
        foodId,
        foodName,
        unitId,
        unitSymbol,
        baseQuantity,
      );

  @override
  String toString() {
    return 'RecipeIngredient(id: $id, foodName: $foodName, baseQuantity: $baseQuantity $unitSymbol)';
  }
}
