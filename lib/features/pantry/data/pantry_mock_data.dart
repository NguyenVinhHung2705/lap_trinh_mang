import '../models/food_item.dart';
import '../models/food_batch.dart';
import '../models/stock_movement.dart';

/// Dữ liệu mẫu (In-Memory Mock) phục vụ chạy test giao diện & fallback khi offline
class PantryMockData {
  PantryMockData._();

  static final List<FoodItem> initialFoods = [
    FoodItem(
      id: 'food_1',
      name: 'Sữa tươi thanh trùng',
      categoryName: 'Đồ uống',
      baseUnit: 'hộp',
      minimumStock: 2.0,
      totalStock: 1.0,
      closestExpiryDate: DateTime.now().add(const Duration(days: 1)),
    ),
    FoodItem(
      id: 'food_2',
      name: 'Thịt bò thăn Úc',
      categoryName: 'Thịt cá',
      baseUnit: 'g',
      minimumStock: 200.0,
      totalStock: 500.0,
      closestExpiryDate: DateTime.now().add(const Duration(days: 2)),
    ),
    FoodItem(
      id: 'food_3',
      name: 'Rau cải xanh Đà Lạt',
      categoryName: 'Rau củ',
      baseUnit: 'bó',
      minimumStock: 1.0,
      totalStock: 2.0,
      closestExpiryDate: DateTime.now().add(const Duration(days: 3)),
    ),
    FoodItem(
      id: 'food_4',
      name: 'Sữa chua không đường',
      categoryName: 'Đồ uống',
      baseUnit: 'hũ',
      minimumStock: 2.0,
      totalStock: 3.0,
      closestExpiryDate: DateTime.now().subtract(const Duration(days: 1)), // Đã hết hạn
    ),
    FoodItem(
      id: 'food_5',
      name: 'Trứng gà ta',
      categoryName: 'Trứng',
      baseUnit: 'quả',
      minimumStock: 4.0,
      totalStock: 10.0,
      closestExpiryDate: DateTime.now().add(const Duration(days: 12)),
    ),
    FoodItem(
      id: 'food_6',
      name: 'Cá hồi Nauy fillet',
      categoryName: 'Thịt cá',
      baseUnit: 'g',
      minimumStock: 300.0,
      totalStock: 600.0,
      closestExpiryDate: DateTime.now().add(const Duration(days: 5)),
    ),
  ];

  static final List<FoodBatch> initialBatches = [
    FoodBatch(
      id: 'batch_101',
      foodId: 'food_1',
      foodName: 'Sữa tươi thanh trùng',
      locationName: 'Ngăn mát tủ lạnh',
      importDate: DateTime.now().subtract(const Duration(days: 4)),
      expiryDate: DateTime.now().add(const Duration(days: 1)),
      quantity: 1.0,
      unit: 'hộp',
    ),
    FoodBatch(
      id: 'batch_102',
      foodId: 'food_2',
      foodName: 'Thịt bò thăn Úc',
      locationName: 'Ngăn mát tủ lạnh',
      importDate: DateTime.now().subtract(const Duration(days: 2)),
      expiryDate: DateTime.now().add(const Duration(days: 2)),
      quantity: 500.0,
      unit: 'g',
    ),
    FoodBatch(
      id: 'batch_103',
      foodId: 'food_3',
      foodName: 'Rau cải xanh Đà Lạt',
      locationName: 'Hộc rau quả',
      importDate: DateTime.now().subtract(const Duration(days: 1)),
      expiryDate: DateTime.now().add(const Duration(days: 3)),
      quantity: 2.0,
      unit: 'bó',
    ),
    FoodBatch(
      id: 'batch_104',
      foodId: 'food_4',
      foodName: 'Sữa chua không đường',
      locationName: 'Ngăn mát tủ lạnh',
      importDate: DateTime.now().subtract(const Duration(days: 15)),
      expiryDate: DateTime.now().subtract(const Duration(days: 1)),
      quantity: 3.0,
      unit: 'hũ',
    ),
    FoodBatch(
      id: 'batch_105',
      foodId: 'food_5',
      foodName: 'Trứng gà ta',
      locationName: 'Cánh cửa tủ lạnh',
      importDate: DateTime.now().subtract(const Duration(days: 2)),
      expiryDate: DateTime.now().add(const Duration(days: 12)),
      quantity: 10.0,
      unit: 'quả',
    ),
    FoodBatch(
      id: 'batch_106',
      foodId: 'food_6',
      foodName: 'Cá hồi Nauy fillet',
      locationName: 'Ngăn đông tủ lạnh',
      importDate: DateTime.now().subtract(const Duration(days: 1)),
      expiryDate: DateTime.now().add(const Duration(days: 5)),
      quantity: 600.0,
      unit: 'g',
    ),
  ];

  static final List<StockMovement> initialMovements = [
    StockMovement(
      id: 'mov_1',
      batchId: 'batch_106',
      foodName: 'Cá hồi Nauy fillet',
      type: StockMovementType.consume,
      inQuantity: 0.0,
      outQuantity: 200.0,
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      note: 'Nấu Bữa tối: Cá hồi áp chảo (MOD-04 FEFO)',
    ),
    StockMovement(
      id: 'mov_2',
      batchId: 'batch_105',
      foodName: 'Trứng gà ta',
      type: StockMovementType.inStock,
      inQuantity: 10.0,
      outQuantity: 0.0,
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      note: 'Nhập hàng từ Danh sách mua sắm (MOD-02)',
    ),
  ];
}
