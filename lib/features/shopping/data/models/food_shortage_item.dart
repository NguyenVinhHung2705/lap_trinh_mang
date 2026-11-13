/// Represents an ingredient shortage calculated from a recipe (`MOD-02-03` / FR-11).
///
/// Transferred from MOD-03 (Công thức nấu ăn) after comparing needed ingredients
/// against usable pantry stock in MOD-01.
class FoodShortageItem {
  FoodShortageItem({
    required this.recipeId,
    required this.recipeName,
    required this.foodId,
    required this.foodName,
    required this.unitId,
    required this.unitName,
    required this.shortageQuantity,
    double? approvedQuantity,
    this.isSelected = true,
    this.alreadyInList = false,
    this.existingPendingQuantity = 0.0,
  }) : approvedQuantity = approvedQuantity ?? shortageQuantity {
    if (foodId.trim().isEmpty) {
      throw ArgumentError.value(foodId, 'foodId', 'Food ID must not be empty');
    }
    if (shortageQuantity <= 0 || shortageQuantity.isNaN || shortageQuantity.isInfinite) {
      throw ArgumentError.value(
        shortageQuantity,
        'shortageQuantity',
        'Shortage quantity must be strictly > 0',
      );
    }
    if (this.approvedQuantity <= 0 || this.approvedQuantity.isNaN) {
      throw ArgumentError.value(
        this.approvedQuantity,
        'approvedQuantity',
        'Approved quantity must be strictly > 0',
      );
    }
  }

  /// ID of the recipe requesting this ingredient (`ma_cong_thuc`).
  final String recipeId;

  /// Display name of the recipe (`ten_mon`).
  final String recipeName;

  /// Food ID (`ma_thuc_pham`).
  final String foodId;

  /// Food display name (`ten_thuc_pham`).
  final String foodName;

  /// Unit ID (`ma_don_vi`).
  final String unitId;

  /// Unit symbol / name (`ten_don_vi`).
  final String unitName;

  /// Calculated missing quantity = max(0, required - usable_stock).
  final double shortageQuantity;

  /// Quantity confirmed by user before adding to shopping list.
  final double approvedQuantity;

  /// Whether user selected this item in the review dialog/screen.
  final bool isSelected;

  /// Flag indicating this food is already present in the active shopping list.
  /// Used to alert user and prevent duplicate demand addition (TC-M02-03).
  final bool alreadyInList;

  /// Current pending quantity already in shopping list if [alreadyInList] is true.
  final double existingPendingQuantity;

  FoodShortageItem copyWith({
    String? recipeId,
    String? recipeName,
    String? foodId,
    String? foodName,
    String? unitId,
    String? unitName,
    double? shortageQuantity,
    double? approvedQuantity,
    bool? isSelected,
    bool? alreadyInList,
    double? existingPendingQuantity,
  }) {
    return FoodShortageItem(
      recipeId: recipeId ?? this.recipeId,
      recipeName: recipeName ?? this.recipeName,
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      unitId: unitId ?? this.unitId,
      unitName: unitName ?? this.unitName,
      shortageQuantity: shortageQuantity ?? this.shortageQuantity,
      approvedQuantity: approvedQuantity ?? this.approvedQuantity,
      isSelected: isSelected ?? this.isSelected,
      alreadyInList: alreadyInList ?? this.alreadyInList,
      existingPendingQuantity:
          existingPendingQuantity ?? this.existingPendingQuantity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FoodShortageItem &&
        other.recipeId == recipeId &&
        other.foodId == foodId &&
        other.unitId == unitId &&
        other.shortageQuantity == shortageQuantity &&
        other.approvedQuantity == approvedQuantity &&
        other.isSelected == isSelected;
  }

  @override
  int get hashCode => Object.hash(
        recipeId,
        foodId,
        unitId,
        shortageQuantity,
        approvedQuantity,
        isSelected,
      );

  @override
  String toString() {
    return 'FoodShortageItem(recipe: $recipeName, food: $foodName, '
        'shortage: $shortageQuantity $unitName, approved: $approvedQuantity)';
  }
}

