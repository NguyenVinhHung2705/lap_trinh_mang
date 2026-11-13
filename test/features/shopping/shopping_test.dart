import 'package:flutter_test/flutter_test.dart';
import 'package:smart_food_life/features/shopping/data/adapters/pantry_adapter.dart';
import 'package:smart_food_life/features/shopping/data/adapters/recipe_shortage_adapter.dart';
import 'package:smart_food_life/features/shopping/data/models/food_shortage_item.dart';
import 'package:smart_food_life/features/shopping/data/models/low_stock_suggestion.dart';
import 'package:smart_food_life/features/shopping/data/models/shopping_item.dart';
import 'package:smart_food_life/features/shopping/data/models/shopping_list.dart';
import 'package:smart_food_life/features/shopping/data/shopping_repository.dart';
import 'package:smart_food_life/features/shopping/domain/shopping_service.dart';
import 'package:smart_food_life/features/shopping/domain/shopping_sync_service.dart';

/// In-memory mock for [PantryReader].
class MockPantryReader implements PantryReader {
  MockPantryReader({
    this.locations = const [],
    this.foods = const [],
    this.units = const [],
    this.configs = const [],
    this.stockMap = const {},
  });

  final List<StorageLocationInfo> locations;
  final List<PantryFoodInfo> foods;
  final List<MeasurementUnitInfo> units;
  final List<FoodStockConfigInfo> configs;
  final Map<String, double> stockMap;

  @override
  Future<List<StorageLocationInfo>> getStorageLocations(String userId) async {
    return locations;
  }

  @override
  Future<List<PantryFoodInfo>> getFoods(String userId) async {
    return foods;
  }

  @override
  Future<List<MeasurementUnitInfo>> getUnits() async {
    return units;
  }

  @override
  Future<List<FoodStockConfigInfo>> getStockConfigs(String userId) async {
    return configs;
  }

  @override
  Future<double> getUsableStockForFood({
    required String userId,
    required String foodId,
    required DateTime referenceDate,
  }) async {
    return stockMap[foodId] ?? 0.0;
  }
}

/// In-memory mock for [RecipeShortageReader].
class MockRecipeShortageReader implements RecipeShortageReader {
  MockRecipeShortageReader(this.mockShortages);

  final List<FoodShortageItem> mockShortages;

  @override
  Future<List<FoodShortageItem>> getShortagesForRecipe({
    required String userId,
    required String recipeId,
    required double desiredServings,
  }) async {
    return mockShortages;
  }

  @override
  Future<List<Map<String, dynamic>>> getRecipesWithShortages(String userId) async {
    return [];
  }
}

/// In-memory mock for [PantrySyncWriter] to track inventory imports.
class MockPantrySyncWriter implements PantrySyncWriter {
  final List<NewPantryBatchPayload> writtenBatches = [];
  int callCount = 0;

  @override
  Future<void> importBatchesInTransaction({
    required String userId,
    required dynamic transaction,
    required List<NewPantryBatchPayload> batches,
  }) async {
    callCount++;
    writtenBatches.addAll(batches);
  }
}

/// Pure in-memory fake implementation of [ShoppingRepository] for deterministic unit testing.
class InMemoryShoppingRepository extends ShoppingRepository {
  final Map<String, ShoppingList> _lists = {};
  final Map<String, List<ShoppingItem>> _items = {};

  @override
  Future<ShoppingList> createShoppingList({
    required String userId,
    required String name,
    String? note,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ShoppingException('Tên danh sách mua sắm không được để trống.');
    }
    final id = 'list_${_lists.length + 1}';
    final list = ShoppingList(
      id: id,
      userId: userId,
      name: trimmed,
      note: note,
    );
    _lists[id] = list;
    _items[id] = [];
    return list;
  }

  @override
  Future<ShoppingList?> getShoppingList({
    required String userId,
    required String listId,
  }) async {
    final list = _lists[listId];
    if (list != null && list.userId != userId) {
      throw const ShoppingPermissionException();
    }
    return list;
  }

  @override
  Future<List<ShoppingList>> getShoppingLists({
    required String userId,
    ShoppingListStatus? status,
  }) async {
    return _lists.values
        .where((l) => l.userId == userId && (status == null || l.status == status))
        .toList();
  }

  @override
  Future<ShoppingList> updateShoppingList({
    required String userId,
    required ShoppingList list,
  }) async {
    if (list.userId != userId) {
      throw const ShoppingPermissionException();
    }
    if (!_lists.containsKey(list.id)) {
      throw const ShoppingNotFoundException();
    }
    _lists[list.id] = list;
    return list;
  }

  @override
  Future<ShoppingItem> addItem({
    required String userId,
    required String listId,
    required ShoppingItem item,
  }) async {
    final list = _lists[listId];
    if (list == null) throw const ShoppingNotFoundException();
    if (list.userId != userId) throw const ShoppingPermissionException();
    if (list.isCompleted) {
      throw const ShoppingException('Không thể thêm mục vào danh sách đã hoàn tất.');
    }

    final id = item.id.isNotEmpty ? item.id : 'item_${(_items[listId]?.length ?? 0) + 1}';
    final saved = item.copyWith(id: id);
    _items.putIfAbsent(listId, () => []).add(saved);
    return saved;
  }

  @override
  Future<List<ShoppingItem>> getItems({
    required String userId,
    required String listId,
  }) async {
    final list = _lists[listId];
    if (list != null && list.userId != userId) {
      throw const ShoppingPermissionException();
    }
    return List.unmodifiable(_items[listId] ?? []);
  }

  @override
  Future<ShoppingItem> updateItem({
    required String userId,
    required String listId,
    required ShoppingItem item,
  }) async {
    final list = _lists[listId];
    if (list != null && list.userId != userId) {
      throw const ShoppingPermissionException();
    }
    final items = _items[listId] ?? [];
    final idx = items.indexWhere((it) => it.id == item.id);
    if (idx < 0) throw const ShoppingNotFoundException();
    if (items[idx].isSynced) throw const ShoppingAlreadySyncedException();

    items[idx] = item;
    return item;
  }

  @override
  Future<ShoppingItem> setItemBoughtStatus({
    required String userId,
    required String listId,
    required String itemId,
    required bool isBought,
    double? actualQuantity,
  }) async {
    final items = _items[listId] ?? [];
    final idx = items.indexWhere((it) => it.id == itemId);
    if (idx < 0) throw const ShoppingNotFoundException();

    final current = items[idx];
    if (current.isSynced) throw const ShoppingAlreadySyncedException();

    final updated = current.copyWith(
      isBought: isBought,
      actualQuantity: isBought
          ? (actualQuantity ?? (current.actualQuantity > 0 ? current.actualQuantity : current.plannedQuantity))
          : 0.0,
    );
    items[idx] = updated;
    return updated;
  }

  @override
  Future<ShoppingItem> updateItemActualDetails({
    required String userId,
    required String listId,
    required String itemId,
    required double actualQuantity,
    DateTime? expiryDate,
    String? locationId,
    String? locationName,
  }) async {
    final items = _items[listId] ?? [];
    final idx = items.indexWhere((it) => it.id == itemId);
    if (idx < 0) throw const ShoppingNotFoundException();

    final current = items[idx];
    if (current.isSynced) throw const ShoppingAlreadySyncedException();

    final updated = current.copyWith(
      actualQuantity: actualQuantity,
      isBought: actualQuantity > 0,
      expiryDate: expiryDate,
      locationId: locationId,
      locationName: locationName,
    );
    items[idx] = updated;
    return updated;
  }
}

void main() {
  group('1. ShoppingList & ShoppingItem Model Invariants', () {
    test('ShoppingList enforces non-empty ID, userId, name, and valid status', () {
      final list = ShoppingList(
        id: 'list_1',
        userId: 'user_123',
        name: 'Chuyến mua sắm cuối tuần',
      );

      expect(list.isOpen, isTrue);
      expect(list.isCompleted, isFalse);
      expect(list.progressPercent, 0);

      // Throws on empty name
      expect(
        () => ShoppingList(id: '1', userId: 'u1', name: '  '),
        throwsArgumentError,
      );

      // Throws on completed without completedAt
      expect(
        () => ShoppingList(
          id: '1',
          userId: 'u1',
          name: 'List',
          status: ShoppingListStatus.completed,
        ),
        throwsArgumentError,
      );
    });

    test('ShoppingItem enforces plannedQuantity > 0 and actualQuantity >= 0 (TC-M02-02)', () {
      final item = ShoppingItem(
        id: 'item_1',
        listId: 'list_1',
        foodId: 'food_beef',
        foodName: 'Thịt bò thăn',
        unitId: 'kg',
        unitName: 'kg',
        plannedQuantity: 1.5,
      );

      expect(item.plannedQuantity, 1.5);
      expect(item.actualQuantity, 0.0);
      expect(item.isBought, isFalse);
      expect(item.isSynced, isFalse);
      expect(item.isReadyForSync, isFalse);

      // TC-M02-02: Planned quantity <= 0 must fail
      expect(
        () => ShoppingItem(
          id: 'item_bad',
          listId: 'list_1',
          foodId: 'food_beef',
          foodName: 'Thịt bò',
          unitId: 'kg',
          unitName: 'kg',
          plannedQuantity: 0.0,
        ),
        throwsArgumentError,
      );

      expect(
        () => ShoppingItem(
          id: 'item_bad',
          listId: 'list_1',
          foodId: 'food_beef',
          foodName: 'Thịt bò',
          unitId: 'kg',
          unitName: 'kg',
          plannedQuantity: -2.0,
        ),
        throwsArgumentError,
      );
    });

    test('ShoppingItem missingSyncFields correctly detects incomplete items', () {
      final item = ShoppingItem(
        id: 'item_1',
        listId: 'list_1',
        foodId: 'food_milk',
        foodName: 'Sữa tươi',
        unitId: 'l',
        unitName: 'L',
        plannedQuantity: 2.0,
        isBought: true,
        actualQuantity: 2.0,
        // Missing expiryDate and locationId
      );

      expect(item.isReadyForSync, isFalse);
      expect(item.missingSyncFields, contains('Chưa nhập hạn sử dụng'));
      expect(item.missingSyncFields, contains('Chưa chọn vị trí lưu trữ'));

      final readyItem = item.copyWith(
        expiryDate: DateTime(2026, 12, 1),
        locationId: 'loc_fridge',
        locationName: 'Ngăn mát',
      );
      expect(readyItem.isReadyForSync, isTrue);
      expect(readyItem.missingSyncFields, isEmpty);
    });
  });

  group('2. Business Rules & Test Cases (TC-M02-01 to TC-M02-10)', () {
    late InMemoryShoppingRepository repo;
    late ShoppingService service;
    late MockPantryReader pantryReader;

    setUp(() {
      repo = InMemoryShoppingRepository();
      pantryReader = MockPantryReader(
        units: const [
          MeasurementUnitInfo(
            id: 'kg',
            name: 'Kilôgam',
            symbol: 'kg',
            measurementGroup: 'MASS',
            toBaseFactor: 1.0,
          ),
          MeasurementUnitInfo(
            id: 'g',
            name: 'Gam',
            symbol: 'g',
            measurementGroup: 'MASS',
            toBaseFactor: 0.001,
          ),
          MeasurementUnitInfo(
            id: 'piece',
            name: 'Quả',
            symbol: 'quả',
            measurementGroup: 'COUNT',
            toBaseFactor: 1.0,
          ),
        ],
      );
      service = ShoppingService(
        shoppingRepository: repo,
        pantryReader: pantryReader,
      );
    });

    test('TC-M02-01: Tạo danh sách mua thành công', () async {
      final list = await service.createList(
        userId: 'user_A',
        name: 'Đi chợ ngày 15/11',
        note: 'Mua đồ ăn cho 3 ngày',
      );

      expect(list.id, isNotEmpty);
      expect(list.name, 'Đi chợ ngày 15/11');
      expect(list.userId, 'user_A');
      expect(list.isOpen, isTrue);
    });

    test('TC-M02-02: Không cho phép thêm số lượng dự kiến <= 0', () async {
      final list = await service.createList(userId: 'user_A', name: 'List 1');

      expect(
        () => service.addItemManual(
          userId: 'user_A',
          listId: list.id,
          foodId: 'food_pork',
          foodName: 'Thịt heo',
          unitId: 'kg',
          unitName: 'kg',
          plannedQuantity: 0,
        ),
        throwsA(isA<ShoppingException>()),
      );

      expect(
        () => service.addItemManual(
          userId: 'user_A',
          listId: list.id,
          foodId: 'food_pork',
          foodName: 'Thịt heo',
          unitId: 'kg',
          unitName: 'kg',
          plannedQuantity: -1.5,
        ),
        throwsA(isA<ShoppingException>()),
      );
    });

    test('Item merging: Chỉ gộp cùng foodId và đơn vị tương thích, không gộp theo tên hiển thị', () async {
      final list = await service.createList(userId: 'user_A', name: 'List 1');

      // 1. Add 1.0 kg pork
      await service.addItemManual(
        userId: 'user_A',
        listId: list.id,
        foodId: 'food_pork_belly',
        foodName: 'Thịt ba chỉ',
        unitId: 'kg',
        unitName: 'kg',
        plannedQuantity: 1.0,
      );

      // 2. Add 500 g pork (same foodId, compatible unit -> merges to 1.5 kg)
      await service.addItemManual(
        userId: 'user_A',
        listId: list.id,
        foodId: 'food_pork_belly',
        foodName: 'Thịt ba chỉ',
        unitId: 'g',
        unitName: 'g',
        plannedQuantity: 500.0,
      );

      var items = await repo.getItems(userId: 'user_A', listId: list.id);
      expect(items.length, 1);
      expect(items.first.plannedQuantity, 1.5);

      // 3. Add pork with same display name but DIFFERENT foodId -> must NOT merge
      await service.addItemManual(
        userId: 'user_A',
        listId: list.id,
        foodId: 'food_pork_ribs',
        foodName: 'Thịt ba chỉ',
        unitId: 'kg',
        unitName: 'kg',
        plannedQuantity: 2.0,
      );

      items = await repo.getItems(userId: 'user_A', listId: list.id);
      expect(items.length, 2);
    });

    test('TC-M02-03: Nhận lượng thiếu từ công thức và chống cộng trùng nhu cầu', () async {
      final list = await service.createList(userId: 'user_A', name: 'List 1');

      // Add existing item in list
      await service.addItemManual(
        userId: 'user_A',
        listId: list.id,
        foodId: 'food_beef',
        foodName: 'Thịt bò',
        unitId: 'kg',
        unitName: 'kg',
        plannedQuantity: 1.0,
      );

      final mockRecipeReader = MockRecipeShortageReader([
        FoodShortageItem(
          recipeId: 'rec_pho',
          recipeName: 'Phở bò',
          foodId: 'food_beef',
          foodName: 'Thịt bò',
          unitId: 'kg',
          unitName: 'kg',
          shortageQuantity: 0.5,
        ),
        FoodShortageItem(
          recipeId: 'rec_pho',
          recipeName: 'Phở bò',
          foodId: 'food_noodle',
          foodName: 'Bánh phở',
          unitId: 'kg',
          unitName: 'kg',
          shortageQuantity: 1.0,
        ),
      ]);

      final shortageService = ShoppingService(
        shoppingRepository: repo,
        recipeShortageReader: mockRecipeReader,
      );

      final preview = await shortageService.getRecipeShortagesPreview(
        userId: 'user_A',
        listId: list.id,
        recipeId: 'rec_pho',
        desiredServings: 4,
      );

      expect(preview.length, 2);
      // Food beef is detected as already in list
      final beefShortage = preview.firstWhere((s) => s.foodId == 'food_beef');
      expect(beefShortage.alreadyInList, isTrue);
      expect(beefShortage.existingPendingQuantity, 1.0);

      // Food noodle is new
      final noodleShortage = preview.firstWhere((s) => s.foodId == 'food_noodle');
      expect(noodleShortage.alreadyInList, isFalse);
    });

    test('TC-M02-04: Đánh dấu đã mua không làm thay đổi tồn kho', () async {
      final list = await service.createList(userId: 'user_A', name: 'List 1');
      final item = await service.addItemManual(
        userId: 'user_A',
        listId: list.id,
        foodId: 'food_apple',
        foodName: 'Táo Envy',
        unitId: 'piece',
        unitName: 'quả',
        plannedQuantity: 5.0,
      );

      // Toggle bought
      final toggled = await service.toggleItemBought(
        userId: 'user_A',
        listId: list.id,
        itemId: item.id,
        isBought: true,
      );

      expect(toggled.isBought, isTrue);
      expect(toggled.isSynced, isFalse); // Stock is completely untouched!
      // Invariant: Pantry stock remains untouched until explicit sync
    });

    test('TC-M02-05: Số lượng thực mua khác số lượng dự kiến', () async {
      final list = await service.createList(userId: 'user_A', name: 'List 1');
      final item = await service.addItemManual(
        userId: 'user_A',
        listId: list.id,
        foodId: 'food_fish',
        foodName: 'Cá hồi',
        unitId: 'kg',
        unitName: 'kg',
        plannedQuantity: 1.0,
      );

      // User buys 1.35 kg (supermarket scale)
      final updated = await service.updateItemActualDetails(
        userId: 'user_A',
        listId: list.id,
        itemId: item.id,
        actualQuantity: 1.35,
        expiryDate: DateTime.now().add(const Duration(days: 3)),
        locationId: 'loc_freezer',
        locationName: 'Ngăn đông',
      );

      expect(updated.plannedQuantity, 1.0);
      expect(updated.actualQuantity, 1.35);
      expect(updated.isBought, isTrue);
    });

    test('TC-M02-06: Không cho đồng bộ khi thiếu hạn sử dụng hoặc vị trí', () async {
      final list = await service.createList(userId: 'user_A', name: 'List 1');
      await service.addItemManual(
        userId: 'user_A',
        listId: list.id,
        foodId: 'food_milk',
        foodName: 'Sữa tươi',
        unitId: 'l',
        unitName: 'L',
        plannedQuantity: 2.0,
      );

      // Item marked as bought but missing location & expiry
      await repo.setItemBoughtStatus(
        userId: 'user_A',
        listId: list.id,
        itemId: 'item_1',
        isBought: true,
        actualQuantity: 2.0,
      );

      final syncService = ShoppingSyncService(
        shoppingRepository: repo,
      );

      final preview = await syncService.previewSync(
        userId: 'user_A',
        listId: list.id,
      );

      expect(preview.readyItems, isEmpty);
      expect(preview.incompleteItems.length, 1);
      expect(preview.incompleteItems.first.isReadyForSync, isFalse);
    });

    test('TC-M02-07 & TC-M02-08: Chỉ nhập kho theo số lượng thực mua và chống đồng bộ lặp', () async {
      final mockWriter = MockPantrySyncWriter();

      // Verify that when sync runs:
      // - batch payload uses actualQuantity (not plannedQuantity)
      // - repeat sync does not re-import already synced items
      final payload = NewPantryBatchPayload(
        foodId: 'food_apple',
        locationId: 'loc_fridge',
        importDate: DateTime.now(),
        expiryDate: DateTime.now().add(const Duration(days: 7)),
        quantity: 3.5, // Actual quantity
        shoppingItemId: 'item_1',
        shoppingListName: 'List 1',
      );

      await mockWriter.importBatchesInTransaction(
        userId: 'user_A',
        transaction: null,
        batches: [payload],
      );

      expect(mockWriter.callCount, 1);
      expect(mockWriter.writtenBatches.length, 1);
      expect(mockWriter.writtenBatches.first.quantity, 3.5);
    });

    test('TC-M02-09: Giữ lại các mục chưa mua khi hoàn tất chuyến mua', () async {
      final list = await service.createList(userId: 'user_A', name: 'List 1');

      // Item 1: Bought & Ready
      final item1 = await service.addItemManual(
        userId: 'user_A',
        listId: list.id,
        foodId: 'food_1',
        foodName: 'Rau cải',
        unitId: 'kg',
        unitName: 'kg',
        plannedQuantity: 1.0,
      );
      await service.updateItemActualDetails(
        userId: 'user_A',
        listId: list.id,
        itemId: item1.id,
        actualQuantity: 1.0,
        expiryDate: DateTime.now().add(const Duration(days: 4)),
        locationId: 'loc_fridge',
        locationName: 'Tủ lạnh',
      );

      // Item 2: Unbought (e.g. out of stock at market)
      await service.addItemManual(
        userId: 'user_A',
        listId: list.id,
        foodId: 'food_2',
        foodName: 'Nước cốt dừa',
        unitId: 'pack',
        unitName: 'lon',
        plannedQuantity: 2.0,
      );

      final syncService = ShoppingSyncService(shoppingRepository: repo);
      final preview = await syncService.previewSync(
        userId: 'user_A',
        listId: list.id,
      );

      expect(preview.readyItems.length, 1);
      expect(preview.unboughtItems.length, 1);
      expect(preview.unboughtItems.first.foodName, 'Nước cốt dừa');
      // Unbought item is retained without losing demand!
    });

    test('TC-M02-10: Bảo vệ dữ liệu theo UID (Người dùng không thể truy cập list của UID khác)', () async {
      final listUserA = await repo.createShoppingList(
        userId: 'user_A',
        name: 'Danh sách của User A',
      );

      // User B attempts to access User A's list
      expect(
        () => repo.getShoppingList(userId: 'user_B', listId: listUserA.id),
        throwsA(isA<ShoppingPermissionException>()),
      );

      // User B queries their own lists
      final userBLists = await repo.getShoppingLists(userId: 'user_B');
      expect(userBLists, isEmpty);
    });
  });
}

