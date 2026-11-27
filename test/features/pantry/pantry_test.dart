import 'package:flutter_test/flutter_test.dart';
import 'package:smart_food_life/features/pantry/data/models/food_item.dart';
import 'package:smart_food_life/features/pantry/data/models/food_batch.dart';
import 'package:smart_food_life/features/pantry/data/models/stock_movement.dart';
import 'package:smart_food_life/features/pantry/data/pantry_repository.dart';

void main() {
  group('MOD-01 Pantry & Inventory Complete Business Suite', () {
    late PantryRepository repository;
    const userId = 'mock_test_user';

    setUp(() {
      PantryRepository.resetMockState();
      repository = PantryRepository();
    });

    test('TC-P01: Model ExpiryStatus evaluates days remaining accurately', () {
      final now = DateTime.now();

      final expiredFood = FoodItem(
        id: 'f1',
        name: 'Sữa chua',
        categoryName: 'Đồ uống',
        baseUnit: 'hũ',
        closestExpiryDate: now.subtract(const Duration(days: 1)),
      );
      expect(expiredFood.expiryStatus, ExpiryStatus.expired);

      final warningFood = FoodItem(
        id: 'f2',
        name: 'Thịt bò',
        categoryName: 'Thịt cá',
        baseUnit: 'g',
        closestExpiryDate: now.add(const Duration(days: 2)),
      );
      expect(warningFood.expiryStatus, ExpiryStatus.warning);

      final goodFood = FoodItem(
        id: 'f3',
        name: 'Trứng gà',
        categoryName: 'Trứng',
        baseUnit: 'quả',
        closestExpiryDate: now.add(const Duration(days: 10)),
      );
      expect(goodFood.expiryStatus, ExpiryStatus.good);
    });

    test(
      'TC-03: Rejects importing batch with quantity <= 0 or empty name',
      () async {
        final exp = DateTime.now().add(const Duration(days: 5));

        expect(
          () => repository.addFoodBatch(
            userId: userId,
            foodName: 'Cà rốt',
            categoryName: 'Rau củ',
            baseUnit: 'kg',
            locationName: 'Ngăn mát tủ lạnh',
            quantity: 0.0,
            expiryDate: exp,
          ),
          throwsArgumentError,
        );

        expect(
          () => repository.addFoodBatch(
            userId: userId,
            foodName: '   ',
            categoryName: 'Rau củ',
            baseUnit: 'kg',
            locationName: 'Ngăn mát tủ lạnh',
            quantity: 2.0,
            expiryDate: exp,
          ),
          throwsArgumentError,
        );
      },
    );

    test(
        'TC-04: Two batches of same food with different expiry stay separate and sum accurately',
        () async {
      final expSoon = DateTime.now().add(const Duration(days: 2));
      final expLater = DateTime.now().add(const Duration(days: 9));

      await repository.addFoodBatch(
        userId: userId,
        foodName: 'Rau Muống',
        categoryName: 'Rau củ',
        baseUnit: 'bó',
        locationName: 'Hộc rau quả',
        quantity: 2.0,
        expiryDate: expLater,
      );

      await repository.addFoodBatch(
        userId: userId,
        foodName: 'Rau Muống',
        categoryName: 'Rau củ',
        baseUnit: 'bó',
        locationName: 'Ngăn mát tủ lạnh',
        quantity: 3.0,
        expiryDate: expSoon,
      );

      final foods = await repository.watchFoodItems(userId).first;
      final addedFood = foods.firstWhere((f) => f.name == 'Rau Muống');
      expect(addedFood.totalStock, 5.0);

      // Các lô tách riêng và sắp xếp theo FEFO (expSoon đứng đầu)
      final batches =
          await repository.watchBatchesForFood(userId, addedFood.id).first;
      expect(batches.length, 2);
      expect(batches.first.quantity, 3.0);
      expect(batches.last.quantity, 2.0);
    });

    test(
        'TC-14: Adjusting batch quantity updates stock, logs ADJUST, and blocks negative stock',
        () async {
      // Điều chỉnh giảm lô batch_105 (Trứng gà ta: 10 -> 7 quả)
      await repository.adjustBatchQuantity(
        userId: userId,
        batchId: 'batch_105',
        newQuantity: 7.0,
        reason: 'Kiểm kê thực tế bị vỡ 3 quả',
      );

      final foods = await repository.watchFoodItems(userId).first;
      final egg = foods.firstWhere((f) => f.id == 'food_5');
      expect(egg.totalStock, 7.0);

      final movements = await repository.watchStockMovements(userId).first;
      expect(movements.first.type, StockMovementType.adjust);
      expect(movements.first.inQuantity, 0.0);
      expect(movements.first.outQuantity, 3.0);

      // Chặn tồn âm (< 0)
      expect(
        () => repository.adjustBatchQuantity(
          userId: userId,
          batchId: 'batch_105',
          newQuantity: -2.0,
          reason: 'Sai số âm',
        ),
        throwsStateError,
      );
    });

    test(
        'TC-15: Moving batch location changes only location without altering stock or ledger',
        () async {
      final beforeMovements =
          await repository.watchStockMovements(userId).first;
      final beforeCount = beforeMovements.length;

      await repository.moveBatchLocation(
        userId: userId,
        batchId: 'batch_102', // Thịt bò thăn Úc (500g)
        newLocationName: 'Ngăn đông tủ lạnh',
      );

      final batches =
          await repository.watchBatchesForFood(userId, 'food_2').first;
      expect(batches.single.locationName, 'Ngăn đông tủ lạnh');
      expect(batches.single.quantity, 500.0);

      final afterMovements = await repository.watchStockMovements(userId).first;
      expect(afterMovements.length, beforeCount);
    });

    test(
        'FR-04: Deleting occupied storage location is blocked; empty location deletes cleanly',
        () async {
      // Ngăn mát tủ lạnh đang chứa các lô thực phẩm -> chặn xóa
      expect(
        () => repository.deleteStorageLocation(
          userId: userId,
          locationId: 'loc_1',
          locationName: 'Ngăn mát tủ lạnh',
        ),
        throwsStateError,
      );

      // Kệ bếp hiện trống -> cho phép xóa
      await repository.deleteStorageLocation(
        userId: userId,
        locationId: 'loc_6',
        locationName: 'Kệ bếp',
      );

      final locations = await repository.getStorageLocations(userId);
      expect(locations.any((l) => l['ten_vi_tri'] == 'Kệ bếp'), isFalse);
    });

    test(
      'FR-02 & TC-P05: Barcode lookup and Supabase PostgreSQL row mapping',
      () async {
        final found = await repository.lookupFoodByBarcode(
          userId,
          '8934567890123',
        );
        expect(found, isNotNull);
        expect(found!['name'], 'Sữa tươi thanh trùng');

        final batch = FoodBatch.fromMap('uuid-batch-1', {
          'id': 'uuid-batch-1',
          'thuc_pham_id': 'food_thit_bo',
          'ten_thuc_pham': 'Thịt bò tươi',
          'vi_tri': 'Ngăn đông đá',
          'created_at': '2026-11-25T10:00:00Z',
          'ngay_het_han': '2026-12-05',
          'so_luong': 350,
          'don_vi': 'g',
        });

        expect(batch.foodId, 'food_thit_bo');
        expect(batch.locationName, 'Ngăn đông đá');
        expect(batch.quantity, 350.0);

        final importMov = StockMovement.fromMap('uuid-mov-1', {
          'thuc_pham_id': 'food_thit_bo',
          'ten_thuc_pham': 'Thịt bò tươi',
          'loai_bien_dong': 'IMPORT',
          'so_luong_nhap': 500,
          'so_luong_xuat': 0,
          'created_at': '2026-11-25T10:00:00Z',
        });
        expect(importMov.type, StockMovementType.inStock);
        expect(importMov.type.code, 'IMPORT');
      },
    );
  });
}
