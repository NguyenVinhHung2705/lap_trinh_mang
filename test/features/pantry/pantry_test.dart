import 'package:flutter_test/flutter_test.dart';
import 'package:smart_food_life/features/pantry/data/models/food_item.dart';
import 'package:smart_food_life/features/pantry/data/models/food_batch.dart';
import 'package:smart_food_life/features/pantry/data/models/stock_movement.dart';
import 'package:smart_food_life/features/pantry/data/pantry_repository.dart';

void main() {
  group('MOD-01 Pantry & Inventory Unit Tests', () {
    late PantryRepository repository;

    setUp(() {
      repository = PantryRepository();
    });

    test('TC-P01: Model ExpiryStatus should correctly evaluate days remaining', () {
      final now = DateTime.now();
      
      // Case 1: Đã hết hạn (ngày hôm qua)
      final expiredFood = FoodItem(
        id: 'f1',
        name: 'Sữa chua',
        categoryName: 'Đồ uống',
        baseUnit: 'hũ',
        closestExpiryDate: now.subtract(const Duration(days: 1)),
      );
      expect(expiredFood.expiryStatus, ExpiryStatus.expired);

      // Case 2: Sắp hết hạn (còn 2 ngày)
      final warningFood = FoodItem(
        id: 'f2',
        name: 'Thịt bò',
        categoryName: 'Thịt cá',
        baseUnit: 'g',
        closestExpiryDate: now.add(const Duration(days: 2)),
      );
      expect(warningFood.expiryStatus, ExpiryStatus.warning);

      // Case 3: Còn hạn thoải mái (còn 10 ngày)
      final goodFood = FoodItem(
        id: 'f3',
        name: 'Trứng gà',
        categoryName: 'Trứng',
        baseUnit: 'quả',
        closestExpiryDate: now.add(const Duration(days: 10)),
      );
      expect(goodFood.expiryStatus, ExpiryStatus.good);
    });

    test('TC-P02: FoodBatch should correctly calculate remaining days and status', () {
      final now = DateTime.now();
      final batch = FoodBatch(
        id: 'b1',
        foodId: 'f1',
        foodName: 'Cá hồi',
        locationName: 'Ngăn đông',
        importDate: now.subtract(const Duration(days: 2)),
        expiryDate: now.add(const Duration(days: 3)),
        quantity: 500.0,
        unit: 'g',
      );

      expect(batch.daysRemaining, 3);
      expect(batch.status, ExpiryStatus.warning);
    });

    test('TC-P03: Adding new batch should update total stock and log IN movement', () async {
      const userId = 'mock_test_user';
      final exp = DateTime.now().add(const Duration(days: 5));

      await repository.addFoodBatch(
        userId: userId,
        foodName: 'Rau Muống',
        categoryName: 'Rau củ',
        baseUnit: 'bó',
        locationName: 'Ngăn mát',
        quantity: 3.0,
        expiryDate: exp,
      );

      final foods = await repository.watchFoodItems(userId).first;
      final addedFood = foods.firstWhere((f) => f.name == 'Rau Muống');
      expect(addedFood.totalStock, 3.0);
      expect(addedFood.baseUnit, 'bó');

      final movements = await repository.watchStockMovements(userId).first;
      expect(movements.first.type, StockMovementType.inStock);
      expect(movements.first.inQuantity, 3.0);
      expect(movements.first.outQuantity, 0.0);
    });

    test('TC-P04: Discarding batch should reduce total stock and log DISCARD movement', () async {
      const userId = 'mock_test_user';

      // Hủy lô batch_104 (Sữa chua không đường, sl = 3)
      await repository.discardBatch(
        userId: userId,
        batchId: 'batch_104',
        reason: 'Sữa chua quá hạn',
      );

      final movements = await repository.watchStockMovements(userId).first;
      expect(movements.first.type, StockMovementType.discard);
      expect(movements.first.outQuantity, 3.0);
      expect(movements.first.note, 'Sữa chua quá hạn');
    });
  });
}
