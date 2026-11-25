import 'package:supabase_flutter/supabase_flutter.dart';

/// Projection of food metadata owned by MOD-01 (`thuc_pham`).
class PantryFoodInfo {
  const PantryFoodInfo({
    required this.id,
    required this.name,
    required this.baseUnitId,
    this.categoryId,
    this.categoryName,
    this.barcode,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String baseUnitId;
  final String? categoryId;
  final String? categoryName;
  final String? barcode;
  final String? imageUrl;
}

/// Projection of user storage location owned by MOD-01 (`vi_tri_luu_tru`).
class StorageLocationInfo {
  const StorageLocationInfo({
    required this.id,
    required this.name,
    this.description,
  });

  final String id;
  final String name;
  final String? description;
}

/// Projection of measurement unit owned by MOD-01 (`don_vi`).
class MeasurementUnitInfo {
  const MeasurementUnitInfo({
    required this.id,
    required this.name,
    required this.symbol,
    required this.measurementGroup,
    this.toBaseFactor = 1.0,
  });

  final String id;
  final String name;
  final String symbol;
  final String measurementGroup;
  final double toBaseFactor;

  /// Checks whether this unit can be converted to [other].
  bool isCompatibleWith(MeasurementUnitInfo other) {
    if (id == other.id) return true;
    final g1 = measurementGroup.trim().toUpperCase();
    final g2 = other.measurementGroup.trim().toUpperCase();
    return g1 == g2 && g1 != 'COUNT';
  }

  /// Converts [quantity] in this unit to [targetUnit].
  double convertTo(double quantity, MeasurementUnitInfo targetUnit) {
    if (!isCompatibleWith(targetUnit)) {
      throw ArgumentError(
        'Đơn vị $name ($symbol) không tương thích với ${targetUnit.name} (${targetUnit.symbol})',
      );
    }
    if (id == targetUnit.id) return quantity;
    final baseAmount = quantity * toBaseFactor;
    return baseAmount / targetUnit.toBaseFactor;
  }
}

/// Projection of low-stock configuration owned by MOD-01 (`food_minimum_stock`).
class FoodStockConfigInfo {
  const FoodStockConfigInfo({
    required this.foodId,
    required this.threshold,
    required this.suggestedBuyQuantity,
    this.autoAdd = false,
  });

  final String foodId;
  final double threshold;
  final double suggestedBuyQuantity;
  final bool autoAdd;
}

/// Batch creation request payload for pantry synchronization (`lo_thuc_pham`).
class NewPantryBatchPayload {
  const NewPantryBatchPayload({
    required this.foodId,
    required this.locationId,
    required this.importDate,
    required this.expiryDate,
    required this.quantity,
    required this.shoppingItemId,
    required this.shoppingListName,
  });

  final String foodId;
  final String locationId;
  final DateTime importDate;
  final DateTime expiryDate;
  final double quantity;
  final String shoppingItemId;
  final String shoppingListName;
}

/// Abstract contract for reading inventory state from MOD-01.
abstract interface class PantryReader {
  /// Fetches all active storage locations configured by the user.
  Future<List<StorageLocationInfo>> getStorageLocations(String userId);

  /// Searches or retrieves foods in the catalog.
  Future<List<PantryFoodInfo>> getFoods(String userId);

  /// Retrieves all measurement units.
  Future<List<MeasurementUnitInfo>> getUnits();

  /// Retrieves user's low stock alert configurations.
  Future<List<FoodStockConfigInfo>> getStockConfigs(String userId);

  /// Calculates total usable stock for a food item from `bien_dong_kho` (excluding expired batches).
  ///
  /// Invariant: Tồn = SUM(so_luong_nhap) - SUM(so_luong_xuat).
  Future<double> getUsableStockForFood({
    required String userId,
    required String foodId,
    required DateTime referenceDate,
  });
}

/// Abstract contract for pantry synchronization (`MOD-01-07`).
abstract interface class PantrySyncWriter {
  /// Writes newly purchased lots and records 'IN' movements in `bien_dong_kho`.
  Future<void> importBatches({
    required String userId,
    required List<NewPantryBatchPayload> batches,
  });
}

/// Default Supabase implementation connecting to MOD-01 collections.
class SupabasePantryAdapter implements PantryReader, PantrySyncWriter {
  SupabasePantryAdapter({SupabaseClient? supabase})
      : _customSupabase = supabase;

  final SupabaseClient? _customSupabase;
  SupabaseClient get _supabase =>
      _customSupabase ?? Supabase.instance.client;

  @override
  Future<List<StorageLocationInfo>> getStorageLocations(String userId) async {
    const defaultLocations = [
      StorageLocationInfo(id: 'loc_1', name: 'Ngăn mát tủ lạnh', description: 'Nhiệt độ 2°C - 5°C'),
      StorageLocationInfo(id: 'loc_2', name: 'Ngăn đông đá', description: 'Nhiệt độ dưới -18°C'),
      StorageLocationInfo(id: 'loc_3', name: 'Tủ gia vị khô', description: 'Nơi thoáng mát'),
      StorageLocationInfo(id: 'loc_4', name: 'Hộc rau quả', description: 'Độ ẩm cao'),
    ];

    if (userId.isEmpty || userId.startsWith('mock_') || userId.startsWith('guest_')) {
      return defaultLocations;
    }

    try {
      final rows = await _supabase
          .from('vi_tri_luu_tru')
          .select()
          .eq('user_id', userId);

      if ((rows as List).isEmpty) {
        return defaultLocations;
      }

      return rows.map((row) {
        final data = row as Map<String, dynamic>;
        return StorageLocationInfo(
          id: data['id'] as String? ?? '',
          name: data['ten'] as String? ?? 'Vị trí mặc định',
          description: data['mo_ta'] as String?,
        );
      }).toList();
    } catch (_) {
      return defaultLocations;
    }
  }

  @override
  Future<List<PantryFoodInfo>> getFoods(String userId) async {
    // Query global food catalog
    final rows = await _supabase
        .from('thuc_pham_global')
        .select();

    if ((rows as List).isNotEmpty) {
      return rows.map((row) {
        final data = row as Map<String, dynamic>;
        return PantryFoodInfo(
          id: data['id'] as String? ?? '',
          name: data['ten'] as String? ?? 'Thực phẩm',
          baseUnitId: data['don_vi_co_so']?.toString() ?? '1',
          categoryName: data['ten_danh_muc'] as String?,
          barcode: data['ma_vach'] as String?,
          imageUrl: data['hinh_anh'] as String?,
        );
      }).toList();
    }

    return [];
  }

  @override
  Future<List<MeasurementUnitInfo>> getUnits() async {
    final rows = await _supabase
        .from('don_vi')
        .select();

    if ((rows as List).isNotEmpty) {
      return rows.map((row) {
        final data = row as Map<String, dynamic>;
        return MeasurementUnitInfo(
          id: data['id'] as String? ?? '',
          name: data['ten'] as String? ?? data['id'] as String? ?? '',
          symbol: data['ky_hieu'] as String? ?? '',
          measurementGroup: data['nhom_do_luong'] as String? ?? 'MASS',
          toBaseFactor: (data['he_so_quy_doi'] as num?)?.toDouble() ?? 1.0,
        );
      }).toList();
    }

    // Default canonical fallback units
    return const [
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
        id: 'l',
        name: 'Lít',
        symbol: 'L',
        measurementGroup: 'VOLUME',
        toBaseFactor: 1.0,
      ),
      MeasurementUnitInfo(
        id: 'ml',
        name: 'Mililít',
        symbol: 'ml',
        measurementGroup: 'VOLUME',
        toBaseFactor: 0.001,
      ),
      MeasurementUnitInfo(
        id: 'piece',
        name: 'Cái / Quả',
        symbol: 'cái',
        measurementGroup: 'COUNT',
        toBaseFactor: 1.0,
      ),
      MeasurementUnitInfo(
        id: 'pack',
        name: 'Gói / Hộp',
        symbol: 'hộp',
        measurementGroup: 'COUNT',
        toBaseFactor: 1.0,
      ),
    ];
  }

  @override
  Future<List<FoodStockConfigInfo>> getStockConfigs(String userId) async {
    final rows = await _supabase
        .from('food_minimum_stock')
        .select()
        .eq('user_id', userId);

    return (rows as List).map((row) {
      final data = row as Map<String, dynamic>;
      return FoodStockConfigInfo(
        foodId: data['thuc_pham_id']?.toString() ?? '',
        threshold: (data['ton_kho_toi_thieu'] as num?)?.toDouble() ?? 0.0,
        suggestedBuyQuantity:
            (data['so_luong_mua_de_xuat'] as num?)?.toDouble() ?? 1.0,
        autoAdd: data['tu_dong_them_mua_sam'] as bool? ?? false,
      );
    }).toList();
  }

  @override
  Future<double> getUsableStockForFood({
    required String userId,
    required String foodId,
    required DateTime referenceDate,
  }) async {
    final refMidnight = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final refKey =
        '${refMidnight.year.toString().padLeft(4, '0')}-${refMidnight.month.toString().padLeft(2, '0')}-${refMidnight.day.toString().padLeft(2, '0')}';

    // 1. Get all batches for foodId with expiry >= refKey
    final batchRows = await _supabase
        .from('lo_thuc_pham')
        .select()
        .eq('user_id', userId)
        .eq('thuc_pham_id', foodId)
        .gte('ngay_het_han', refKey);

    final usableBatchIds = <String>{};
    for (final row in (batchRows as List)) {
      final data = row as Map<String, dynamic>;
      final batchId = data['id']?.toString();
      if (batchId != null) {
        usableBatchIds.add(batchId);
      }
    }

    if (usableBatchIds.isEmpty) return 0.0;

    // 2. Query ledger movements for usable batches:
    // Tồn = SUM(so_luong_nhap) - SUM(so_luong_xuat)
    final movementRows = await _supabase
        .from('bien_dong_kho')
        .select()
        .eq('user_id', userId)
        .eq('thuc_pham_id', foodId);

    var totalBalance = 0.0;
    for (final row in (movementRows as List)) {
      final data = row as Map<String, dynamic>;
      final batchId = data['ma_lo']?.toString();
      if (batchId != null && usableBatchIds.contains(batchId)) {
        final inQty = (data['so_luong_nhap'] as num?)?.toDouble() ?? 0.0;
        final outQty = (data['so_luong_xuat'] as num?)?.toDouble() ?? 0.0;
        totalBalance += (inQty - outQty);
      }
    }

    return totalBalance > 0.0 ? totalBalance : 0.0;
  }

  @override
  Future<void> importBatches({
    required String userId,
    required List<NewPantryBatchPayload> batches,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();

    for (final b in batches) {
      // 1. Create lot row (`lo_thuc_pham`)
      final batchResult = await _supabase
          .from('lo_thuc_pham')
          .insert({
            'user_id': userId,
            'thuc_pham_id': b.foodId,
            'ten_thuc_pham': b.shoppingListName,
            'vi_tri': b.locationId,
            'ngay_het_han': b.expiryDate.toIso8601String().substring(0, 10),
            'so_luong': b.quantity,
            'don_vi': '',
            'ghi_chu': 'Nhập kho từ danh sách mua sắm: ${b.shoppingListName}',
            'created_at': now,
          })
          .select('id')
          .single();

      final newBatchId = batchResult['id'] as String;

      // 2. Record ledger movement ('IN')
      await _supabase.from('bien_dong_kho').insert({
        'user_id': userId,
        'thuc_pham_id': b.foodId,
        'ten_thuc_pham': b.shoppingListName,
        'ma_lo': newBatchId,
        'ma_chi_tiet_mua': b.shoppingItemId,
        'loai_bien_dong': 'IN',
        'so_luong_nhap': b.quantity,
        'so_luong_xuat': 0.0,
        'ghi_chu': 'Nhập kho từ danh sách mua sắm: ${b.shoppingListName}',
        'created_at': now,
      });
    }
  }
}
