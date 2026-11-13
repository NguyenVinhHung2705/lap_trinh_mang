import '../data/adapters/pantry_adapter.dart';
import '../data/adapters/recipe_shortage_adapter.dart';
import '../data/models/food_shortage_item.dart';
import '../data/models/low_stock_suggestion.dart';
import '../data/models/shopping_item.dart';
import '../data/models/shopping_list.dart';
import '../data/shopping_repository.dart';

/// Domain service orchestrating shopping list workflows (`MOD-02-01` to `MOD-02-07`).
class ShoppingService {
  ShoppingService({
    required ShoppingRepository shoppingRepository,
    PantryReader? pantryReader,
    RecipeShortageReader? recipeShortageReader,
  })  : _repository = shoppingRepository,
        _pantryReader = pantryReader ?? FirestorePantryAdapter(),
        _recipeShortageReader =
            recipeShortageReader ?? FirestoreRecipeShortageAdapter();

  final ShoppingRepository _repository;
  final PantryReader _pantryReader;
  final RecipeShortageReader _recipeShortageReader;

  // ---------------------------------------------------------------------------
  // MOD-02-01: TẠO VÀ SỬA DANH SÁCH MUA (FR-09)
  // ---------------------------------------------------------------------------

  /// Creates a new shopping list.
  Future<ShoppingList> createList({
    required String userId,
    required String name,
    String? note,
  }) {
    return _repository.createShoppingList(
      userId: userId,
      name: name,
      note: note,
    );
  }

  /// Renames an existing shopping list.
  Future<ShoppingList> renameList({
    required String userId,
    required String listId,
    required String newName,
  }) async {
    final list = await _repository.getShoppingList(userId: userId, listId: listId);
    if (list == null) throw const ShoppingNotFoundException();

    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw const ShoppingException('Tên danh sách mua sắm không được để trống.');
    }

    final updated = list.copyWith(name: trimmed);
    return _repository.updateShoppingList(userId: userId, list: updated);
  }

  /// Deletes a shopping list if allowed.
  Future<void> deleteList({
    required String userId,
    required String listId,
  }) {
    return _repository.deleteShoppingList(userId: userId, listId: listId);
  }

  // ---------------------------------------------------------------------------
  // MOD-02-02: THÊM THỦ CÔNG MỤC CẦN MUA (FR-10)
  // ---------------------------------------------------------------------------

  /// Adds a food item to [listId] with merge rules:
  /// - Only merges if same `foodId` AND compatible measurement unit.
  /// - Never merges based solely on food display name.
  /// - Synced items are never modified or reused as pending items.
  Future<ShoppingItem> addItemManual({
    required String userId,
    required String listId,
    required String foodId,
    required String foodName,
    required String unitId,
    required String unitName,
    required double plannedQuantity,
    String? categoryId,
    String? categoryName,
    String? note,
  }) async {
    if (plannedQuantity <= 0) {
      throw const ShoppingException('Số lượng cần mua phải lớn hơn 0.');
    }

    // 1. Fetch existing items in the list
    final existingItems = await _repository.getItems(
      userId: userId,
      listId: listId,
    );

    // 2. Find eligible pending item with same foodId
    final existingPendingIndex = existingItems.indexWhere(
      (item) => item.foodId == foodId && !item.isSynced,
    );

    if (existingPendingIndex >= 0) {
      final existing = existingItems[existingPendingIndex];

      // Check unit compatibility (FR-10: Kiểm tra đơn vị tương thích)
      if (existing.unitId == unitId) {
        // Same unit: merge directly
        final merged = existing.copyWith(
          plannedQuantity: existing.plannedQuantity + plannedQuantity,
          note: note != null && note.isNotEmpty ? note : existing.note,
        );
        return _repository.updateItem(
          userId: userId,
          listId: listId,
          item: merged,
        );
      }

      // Check conversion via pantry units
      final units = await _pantryReader.getUnits();
      final currentUnit = units.firstWhere(
        (u) => u.id == unitId,
        orElse: () => MeasurementUnitInfo(
          id: unitId,
          name: unitName,
          symbol: unitName,
          measurementGroup: 'UNKNOWN',
        ),
      );
      final existingUnit = units.firstWhere(
        (u) => u.id == existing.unitId,
        orElse: () => MeasurementUnitInfo(
          id: existing.unitId,
          name: existing.unitName,
          symbol: existing.unitName,
          measurementGroup: 'UNKNOWN',
        ),
      );

      if (currentUnit.isCompatibleWith(existingUnit)) {
        final convertedQty = currentUnit.convertTo(plannedQuantity, existingUnit);
        final merged = existing.copyWith(
          plannedQuantity: existing.plannedQuantity + convertedQty,
          note: note != null && note.isNotEmpty ? note : existing.note,
        );
        return _repository.updateItem(
          userId: userId,
          listId: listId,
          item: merged,
        );
      }
      // Incompatible unit: do not merge, add as new distinct line item
    }

    // 3. Otherwise add new item
    final newItem = ShoppingItem(
      id: '',
      listId: listId,
      foodId: foodId,
      foodName: foodName,
      unitId: unitId,
      unitName: unitName,
      categoryId: categoryId,
      categoryName: categoryName,
      plannedQuantity: plannedQuantity,
      actualQuantity: 0.0,
      isBought: false,
      isSynced: false,
      note: note,
    );

    return _repository.addItem(
      userId: userId,
      listId: listId,
      item: newItem,
    );
  }

  // ---------------------------------------------------------------------------
  // MOD-02-03: NHẬN LƯỢNG THIẾU TỪ CÔNG THỨC (FR-11)
  // ---------------------------------------------------------------------------

  /// Previews shortages from a recipe and cross-checks with active items in [listId]
  /// to prevent duplicate demand addition (TC-M02-03).
  Future<List<FoodShortageItem>> getRecipeShortagesPreview({
    required String userId,
    required String listId,
    required String recipeId,
    required double desiredServings,
  }) async {
    final shortages = await _recipeShortageReader.getShortagesForRecipe(
      userId: userId,
      recipeId: recipeId,
      desiredServings: desiredServings,
    );

    final existingItems = await _repository.getItems(
      userId: userId,
      listId: listId,
    );

    // Cross-check with existing pending items
    return shortages.map((s) {
      final existing = existingItems.where(
        (item) => item.foodId == s.foodId && !item.isSynced,
      );
      if (existing.isNotEmpty) {
        final totalExisting =
            existing.fold<double>(0.0, (acc, it) => acc + it.plannedQuantity);
        return s.copyWith(
          alreadyInList: true,
          existingPendingQuantity: totalExisting,
        );
      }
      return s;
    }).toList();
  }

  /// Adds user-approved shortages to [listId].
  Future<int> importApprovedShortages({
    required String userId,
    required String listId,
    required List<FoodShortageItem> approvedShortages,
  }) async {
    var addedCount = 0;
    for (final shortage in approvedShortages) {
      if (!shortage.isSelected || shortage.approvedQuantity <= 0) continue;

      await addItemManual(
        userId: userId,
        listId: listId,
        foodId: shortage.foodId,
        foodName: shortage.foodName,
        unitId: shortage.unitId,
        unitName: shortage.unitName,
        plannedQuantity: shortage.approvedQuantity,
        note: 'Thiếu từ công thức: ${shortage.recipeName}',
      );
      addedCount++;
    }
    return addedCount;
  }

  // ---------------------------------------------------------------------------
  // MOD-02-04: NHẬN GỢI Ý THỰC PHẨM SẮP HẾT (FR-12)
  // ---------------------------------------------------------------------------

  /// Calculates low-stock suggestions:
  /// - Reads configs from `cau_hinh_thuc_pham`
  /// - Usable stock = SUM(nhap) - SUM(xuat) from `bien_dong_kho` (excluding expired lots)
  /// - Low stock: usable stock <= threshold
  /// - Checks existing items in [listId] to avoid duplicate warnings
  Future<List<LowStockSuggestion>> getLowStockSuggestions({
    required String userId,
    required String listId,
  }) async {
    final configs = await _pantryReader.getStockConfigs(userId);
    if (configs.isEmpty) return [];

    final foods = await _pantryReader.getFoods(userId);
    final units = await _pantryReader.getUnits();
    final existingItems = await _repository.getItems(
      userId: userId,
      listId: listId,
    );

    final today = DateTime.now();
    final suggestions = <LowStockSuggestion>[];

    for (final cfg in configs) {
      final usableStock = await _pantryReader.getUsableStockForFood(
        userId: userId,
        foodId: cfg.foodId,
        referenceDate: today,
      );

      if (usableStock <= cfg.threshold) {
        final food = foods.firstWhere(
          (f) => f.id == cfg.foodId,
          orElse: () => PantryFoodInfo(
            id: cfg.foodId,
            name: 'Thực phẩm (${cfg.foodId})',
            baseUnitId: '1',
          ),
        );

        final unit = units.firstWhere(
          (u) => u.id == food.baseUnitId,
          orElse: () => const MeasurementUnitInfo(
            id: 'unit',
            name: 'đơn vị',
            symbol: 'đv',
            measurementGroup: 'COUNT',
          ),
        );

        final existing = existingItems.where(
          (it) => it.foodId == cfg.foodId && !it.isSynced,
        );

        final alreadyIn = existing.isNotEmpty;
        final existingQty = alreadyIn
            ? existing.fold<double>(0.0, (acc, it) => acc + it.plannedQuantity)
            : 0.0;

        suggestions.add(
          LowStockSuggestion(
            foodId: cfg.foodId,
            foodName: food.name,
            unitId: unit.id,
            unitName: unit.symbol.isNotEmpty ? unit.symbol : unit.name,
            currentUsableStock: usableStock,
            threshold: cfg.threshold,
            suggestedQuantity: cfg.suggestedBuyQuantity > 0
                ? cfg.suggestedBuyQuantity
                : (cfg.threshold > 0 ? cfg.threshold : 1.0),
            autoAddEnabled: cfg.autoAdd,
            isSelected: true,
            alreadyInList: alreadyIn,
            existingPendingQuantity: existingQty,
          ),
        );
      }
    }

    return suggestions;
  }

  /// Adds user-approved low-stock suggestions to [listId].
  Future<int> importApprovedSuggestions({
    required String userId,
    required String listId,
    required List<LowStockSuggestion> approvedSuggestions,
  }) async {
    var count = 0;
    for (final item in approvedSuggestions) {
      if (!item.isSelected || item.approvedQuantity <= 0) continue;

      await addItemManual(
        userId: userId,
        listId: listId,
        foodId: item.foodId,
        foodName: item.foodName,
        unitId: item.unitId,
        unitName: item.unitName,
        plannedQuantity: item.approvedQuantity,
        note: 'Gợi ý bổ sung do tồn kho thấp (tồn ${item.currentUsableStock} <= ${item.threshold})',
      );
      count++;
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // MOD-02-05: CHẾ ĐỘ ĐI MUA VÀ ĐÁNH DẤU ĐÃ MUA (FR-13)
  // ---------------------------------------------------------------------------

  /// Toggles bought checkbox for an item.
  ///
  /// Invariant: Toggling bought status NEVER updates pantry stock (TC-M02-04).
  Future<ShoppingItem> toggleItemBought({
    required String userId,
    required String listId,
    required String itemId,
    required bool isBought,
  }) {
    return _repository.setItemBoughtStatus(
      userId: userId,
      listId: listId,
      itemId: itemId,
      isBought: isBought,
    );
  }

  // ---------------------------------------------------------------------------
  // MOD-02-06 & MOD-02-07: SỐ LƯỢNG THỰC MUA, HẠN DÙNG VÀ VỊ TRÍ (FR-14, FR-15)
  // ---------------------------------------------------------------------------

  /// Updates actual purchased quantity, expiry date, and storage location.
  Future<ShoppingItem> updateItemActualDetails({
    required String userId,
    required String listId,
    required String itemId,
    required double actualQuantity,
    required DateTime expiryDate,
    required String locationId,
    required String locationName,
  }) {
    if (actualQuantity <= 0) {
      throw const ShoppingException('Số lượng thực mua phải lớn hơn 0.');
    }
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final expMidnight = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    );

    if (expMidnight.isBefore(todayMidnight)) {
      throw const ShoppingException('Hạn sử dụng không thể trước ngày hiện tại.');
    }

    if (locationId.trim().isEmpty) {
      throw const ShoppingException('Vị trí lưu trữ không được để trống.');
    }

    return _repository.updateItemActualDetails(
      userId: userId,
      listId: listId,
      itemId: itemId,
      actualQuantity: actualQuantity,
      expiryDate: expiryDate,
      locationId: locationId,
      locationName: locationName,
    );
  }
}

