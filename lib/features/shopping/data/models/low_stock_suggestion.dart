/// Represents a food suggestion generated from low stock analysis (`MOD-02-04` / FR-12).
///
/// Invariants:
/// - Pantry stock must be derived from `bien_dong_kho` ledger:
///   `Tồn = SUM(so_luong_nhap) - SUM(so_luong_xuat)`.
/// - Expired batches (`han_su_dung < today`) are strictly excluded from usable stock.
/// - Requires explicit user confirmation before adding to shopping list unless
///   `autoAddEnabled` is set and handled with duplicate protection.
class LowStockSuggestion {
  LowStockSuggestion({
    required this.foodId,
    required this.foodName,
    required this.unitId,
    required this.unitName,
    required this.currentUsableStock,
    required this.threshold,
    required this.suggestedQuantity,
    double? approvedQuantity,
    this.autoAddEnabled = false,
    this.isSelected = true,
    this.alreadyInList = false,
    this.existingPendingQuantity = 0.0,
  }) : approvedQuantity = approvedQuantity ?? suggestedQuantity {
    if (foodId.trim().isEmpty) {
      throw ArgumentError.value(foodId, 'foodId', 'Food ID must not be empty');
    }
    if (suggestedQuantity <= 0 || suggestedQuantity.isNaN) {
      throw ArgumentError.value(
        suggestedQuantity,
        'suggestedQuantity',
        'Suggested quantity must be strictly > 0',
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

  /// Food ID (`ma_thuc_pham`).
  final String foodId;

  /// Food display name (`ten_thuc_pham`).
  final String foodName;

  /// Unit ID (`ma_don_vi`).
  final String unitId;

  /// Unit display symbol / name (`ten_don_vi`).
  final String unitName;

  /// Current usable stock in pantry calculated from ledger `bien_dong_kho` (excluding expired lots).
  final double currentUsableStock;

  /// Low-stock threshold configured in `cau_hinh_thuc_pham.nguong_sap_het`.
  final double threshold;

  /// Proposed purchase amount configured in `cau_hinh_thuc_pham.so_luong_mua_de_xuat`.
  final double suggestedQuantity;

  /// Quantity confirmed by user to add to the shopping list.
  final double approvedQuantity;

  /// Config flag `cau_hinh_thuc_pham.tu_dong_them_mua_sam`.
  final bool autoAddEnabled;

  /// Whether this item is selected by user in the suggestions UI.
  final bool isSelected;

  /// Whether this item already has a pending entry in the target shopping list.
  final bool alreadyInList;

  /// Existing planned quantity in shopping list if [alreadyInList] is true.
  final double existingPendingQuantity;

  LowStockSuggestion copyWith({
    String? foodId,
    String? foodName,
    String? unitId,
    String? unitName,
    double? currentUsableStock,
    double? threshold,
    double? suggestedQuantity,
    double? approvedQuantity,
    bool? autoAddEnabled,
    bool? isSelected,
    bool? alreadyInList,
    double? existingPendingQuantity,
  }) {
    return LowStockSuggestion(
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      unitId: unitId ?? this.unitId,
      unitName: unitName ?? this.unitName,
      currentUsableStock: currentUsableStock ?? this.currentUsableStock,
      threshold: threshold ?? this.threshold,
      suggestedQuantity: suggestedQuantity ?? this.suggestedQuantity,
      approvedQuantity: approvedQuantity ?? this.approvedQuantity,
      autoAddEnabled: autoAddEnabled ?? this.autoAddEnabled,
      isSelected: isSelected ?? this.isSelected,
      alreadyInList: alreadyInList ?? this.alreadyInList,
      existingPendingQuantity:
          existingPendingQuantity ?? this.existingPendingQuantity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LowStockSuggestion &&
        other.foodId == foodId &&
        other.unitId == unitId &&
        other.currentUsableStock == currentUsableStock &&
        other.threshold == threshold &&
        other.suggestedQuantity == suggestedQuantity &&
        other.approvedQuantity == approvedQuantity &&
        other.isSelected == isSelected;
  }

  @override
  int get hashCode => Object.hash(
        foodId,
        unitId,
        currentUsableStock,
        threshold,
        suggestedQuantity,
        approvedQuantity,
        isSelected,
      );

  @override
  String toString() {
    return 'LowStockSuggestion(food: $foodName, stock: $currentUsableStock/$threshold $unitName, '
        'suggested: $suggestedQuantity $unitName, approved: $approvedQuantity)';
  }
}

