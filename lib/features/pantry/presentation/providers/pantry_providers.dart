import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/food_item.dart';
import '../data/models/food_batch.dart';
import '../data/models/stock_movement.dart';
import '../data/pantry_repository.dart';

/// Provider khởi tạo Repository
final pantryRepositoryProvider = Provider<PantryRepository>((ref) {
  return PantryRepository();
});

/// Filter danh mục thực phẩm
final selectedCategoryFilterProvider = StateProvider<String>((ref) => 'Tất cả');

/// Filter trạng thái hạn sử dụng (Tất cả, Sắp hết hạn, Đã hết hạn)
final selectedExpiryFilterProvider = StateProvider<String>((ref) => 'Tất cả');

/// Từ khóa tìm kiếm thực phẩm
final pantrySearchQueryProvider = StateProvider<String>((ref) => '');

/// Stream danh sách tất cả thực phẩm trong kho
final pantryFoodsStreamProvider = StreamProvider.autoDispose<List<FoodItem>>((ref) {
  final repo = ref.watch(pantryRepositoryProvider);
  return repo.watchFoodItems('mock_user_nguyen_van_dinh');
});

/// Stream danh sách thực phẩm đã qua bộ lọc (Search, Category, Expiry)
final filteredFoodsProvider = Provider.autoDispose<List<FoodItem>>((ref) {
  final foodsAsync = ref.watch(pantryFoodsStreamProvider);
  final foods = foodsAsync.value ?? [];
  final query = ref.watch(pantrySearchQueryProvider).trim().toLowerCase();
  final category = ref.watch(selectedCategoryFilterProvider);
  final expiryFilter = ref.watch(selectedExpiryFilterProvider);

  return foods.where((food) {
    // 1. Lọc theo từ khóa
    if (query.isNotEmpty && !food.name.toLowerCase().contains(query)) {
      return false;
    }
    // 2. Lọc theo danh mục
    if (category != 'Tất cả' && food.categoryName != category) {
      return false;
    }
    // 3. Lọc theo hạn dùng
    if (expiryFilter == 'Sắp hết hạn' && food.expiryStatus != ExpiryStatus.warning) {
      return false;
    }
    if (expiryFilter == 'Đã hết hạn' && food.expiryStatus != ExpiryStatus.expired) {
      return false;
    }
    return true;
  }).toList();
});

/// Stream danh sách lô sắp hết hạn / đã hết hạn để hiển thị banner ưu tiên
final expiringBatchesStreamProvider = StreamProvider.autoDispose<List<FoodBatch>>((ref) {
  final repo = ref.watch(pantryRepositoryProvider);
  return repo.watchExpiringBatches('mock_user_nguyen_van_dinh');
});

/// Stream lịch sử biến động kho
final stockMovementsStreamProvider = StreamProvider.autoDispose<List<StockMovement>>((ref) {
  final repo = ref.watch(pantryRepositoryProvider);
  return repo.watchStockMovements('mock_user_nguyen_van_dinh');
});
