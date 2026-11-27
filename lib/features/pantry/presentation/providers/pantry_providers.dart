import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/food_item.dart';
import '../../data/models/food_batch.dart';
import '../../data/models/stock_movement.dart';
import '../../data/pantry_repository.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Provider khởi tạo Repository
final pantryRepositoryProvider = Provider<PantryRepository>((ref) {
  return PantryRepository();
});

/// UID người dùng (Firebase Auth UID hoặc mock user cho chế độ Local)
final pantryUserIdProvider = Provider<String>((ref) {
  return ref.watch(currentUserIdProvider);
});

/// Danh sách nhóm thực phẩm mặc định của hệ thống
const List<String> kDefaultFoodCategories = [
  'Rau củ',
  'Thịt cá',
  'Đồ uống',
  'Gia vị',
  'Trứng',
  'Trái cây',
  'Đồ khô',
  'Khác',
];

/// Danh sách loại thực phẩm mới do người dùng tự tạo thêm
final customFoodCategoriesProvider = StateProvider<List<String>>(
  (ref) => <String>[],
);

/// Tổng hợp toàn bộ loại thực phẩm (Mặc định + Tự thêm + Đang có trong kho)
final allFoodCategoriesProvider = Provider.autoDispose<List<String>>((ref) {
  final custom = ref.watch(customFoodCategoriesProvider);
  final foods = ref.watch(pantryFoodsStreamProvider).value ?? [];
  return <String>{
    ...kDefaultFoodCategories,
    ...custom.map((c) => c.trim()).where((c) => c.isNotEmpty),
    ...foods.map((f) => f.categoryName.trim()).where((c) => c.isNotEmpty),
  }.toList();
});

/// Filter danh mục thực phẩm
final selectedCategoryFilterProvider = StateProvider<String>((ref) => 'Tất cả');

/// Filter trạng thái hạn sử dụng & tồn kho:
/// 'Tất cả' | 'Ưu tiên dùng' | 'Sắp hết hạn' | 'Đã hết hạn' | 'Sắp hết tồn'
final selectedExpiryFilterProvider = StateProvider<String>((ref) => 'Tất cả');

/// Từ khóa tìm kiếm thực phẩm
final pantrySearchQueryProvider = StateProvider<String>((ref) => '');

/// Danh sách vị trí lưu trữ cá nhân của người dùng (MOD-01-04)
final storageLocationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(pantryRepositoryProvider);
  final userId = ref.watch(pantryUserIdProvider);
  return repo.getStorageLocations(userId);
});

/// Stream danh sách tất cả thực phẩm trong kho
final pantryFoodsStreamProvider = StreamProvider.autoDispose<List<FoodItem>>((
  ref,
) {
  final repo = ref.watch(pantryRepositoryProvider);
  final userId = ref.watch(pantryUserIdProvider);
  return repo.watchFoodItems(userId);
});

/// Danh sách thực phẩm đã qua bộ lọc (Search, Category, Expiry & LowStock)
final filteredFoodsProvider = Provider.autoDispose<List<FoodItem>>((ref) {
  final foodsAsync = ref.watch(pantryFoodsStreamProvider);
  final foods = foodsAsync.value ?? [];
  final query = ref.watch(pantrySearchQueryProvider).trim().toLowerCase();
  final category = ref.watch(selectedCategoryFilterProvider);
  final statusFilter = ref.watch(selectedExpiryFilterProvider);

  return foods.where((food) {
    // 1. Lọc theo từ khóa tên hoặc mã vạch
    if (query.isNotEmpty) {
      final matchName = food.name.toLowerCase().contains(query);
      final matchCode = (food.barcode ?? '').toLowerCase().contains(query);
      if (!matchName && !matchCode) return false;
    }
    // 2. Lọc theo danh mục
    if (category != 'Tất cả' && food.categoryName != category) {
      return false;
    }
    // 3. Lọc theo trạng thái HSD & cảnh báo sắp hết tồn (MOD-01-06)
    switch (statusFilter) {
      case 'Ưu tiên dùng':
        if (food.expiryStatus != ExpiryStatus.warning &&
            food.expiryStatus != ExpiryStatus.expired) {
          return false;
        }
        break;
      case 'Sắp hết hạn':
        if (food.expiryStatus != ExpiryStatus.warning) return false;
        break;
      case 'Đã hết hạn':
        if (food.expiryStatus != ExpiryStatus.expired) return false;
        break;
      case 'Sắp hết tồn':
        if (!food.isLowStock) return false;
        break;
      default:
        break;
    }
    return true;
  }).toList();
});

/// Stream danh sách lô sắp hết hạn / đã hết hạn để hiển thị banner ưu tiên
final expiringBatchesStreamProvider =
    StreamProvider.autoDispose<List<FoodBatch>>((ref) {
  final repo = ref.watch(pantryRepositoryProvider);
  final userId = ref.watch(pantryUserIdProvider);
  return repo.watchExpiringBatches(userId);
});

/// Stream lịch sử biến động kho
final stockMovementsStreamProvider =
    StreamProvider.autoDispose<List<StockMovement>>((ref) {
  final repo = ref.watch(pantryRepositoryProvider);
  final userId = ref.watch(pantryUserIdProvider);
  return repo.watchStockMovements(userId);
});
