import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/food_item.dart';
import 'models/food_batch.dart';
import 'models/stock_movement.dart';
import 'pantry_mock_data.dart';

/// Repository quản lý kho thực phẩm (MOD-01: Quản lý Kho - Nguyễn Văn Định)
/// Triển khai đầy đủ Supabase (PostgreSQL) user-scoped.
/// Khớp 100% với hợp đồng dữ liệu FEFO của MOD-04 (Hồ Nguyên Khởi) và MOD-02 (Nguyễn Vĩnh Hưng)
class PantryRepository {
  PantryRepository({SupabaseClient? supabaseClient})
      : _customClient = supabaseClient;

  final SupabaseClient? _customClient;
  SupabaseClient get _client => _customClient ?? Supabase.instance.client;

  // Bộ nhớ đệm cục bộ (Fallback/Offline/Mock Testing)
  static final List<FoodItem> _memoryFoods = List.from(PantryMockData.initialFoods);
  static final List<FoodBatch> _memoryBatches = List.from(PantryMockData.initialBatches);
  static final List<StockMovement> _memoryMovements = List.from(PantryMockData.initialMovements);

  bool _isMockUser(String userId) =>
      userId.isEmpty || userId.startsWith('mock_') || userId.startsWith('guest_');

  // =========================================================================
  // 1. QUẢN LÝ THỰC PHẨM (thuc_pham_global)
  // =========================================================================

  /// Stream danh sách thực phẩm trong kho (MOD-01)
  /// Dữ liệu phân lập hoàn toàn theo userId thông qua bảng lo_thuc_pham
  Stream<List<FoodItem>> watchFoodItems(String userId) {
    if (_isMockUser(userId)) {
      return Stream.value(List.unmodifiable(_memoryFoods));
    }

    // Build a stream of distinct food items from lo_thuc_pham batches
    return _client
        .from('lo_thuc_pham')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) {
          // Group batches by thuc_pham_id to build FoodItem aggregates
          final Map<String, List<Map<String, dynamic>>> grouped = {};
          for (final row in rows) {
            final foodId = row['thuc_pham_id'] as String? ?? '';
            if (foodId.isEmpty) continue;
            grouped.putIfAbsent(foodId, () => []).add(row);
          }

          return grouped.entries.map((entry) {
            final foodId = entry.key;
            final batches = entry.value;
            final firstBatch = batches.first;
            double totalStock = 0.0;
            DateTime? closestExpiry;

            for (final b in batches) {
              final qty = (b['so_luong'] as num?)?.toDouble() ?? 0.0;
              if (qty <= 0) continue;
              totalStock += qty;
              final expStr = b['ngay_het_han'] as String?;
              if (expStr != null) {
                final exp = DateTime.tryParse(expStr);
                if (exp != null && (closestExpiry == null || exp.isBefore(closestExpiry))) {
                  closestExpiry = exp;
                }
              }
            }

            return FoodItem(
              id: foodId,
              name: firstBatch['ten_thuc_pham'] as String? ?? '',
              categoryName: '',
              baseUnit: firstBatch['don_vi'] as String? ?? '',
              totalStock: totalStock,
              closestExpiryDate: closestExpiry,
            );
          }).toList();
        });
  }

  /// Lấy chi tiết 1 thực phẩm theo ID
  Future<FoodItem?> getFoodItem(String userId, String foodId) async {
    if (_isMockUser(userId)) {
      return _memoryFoods.cast<FoodItem?>().firstWhere(
            (f) => f?.id == foodId,
            orElse: () => null,
          );
    }

    try {
      // Fetch from thuc_pham_global
      final row = await _client
          .from('thuc_pham_global')
          .select()
          .eq('id', foodId)
          .maybeSingle();

      if (row == null) return null;

      // Aggregate stock from lo_thuc_pham
      final batches = await _client
          .from('lo_thuc_pham')
          .select()
          .eq('user_id', userId)
          .eq('thuc_pham_id', foodId);

      double totalStock = 0.0;
      DateTime? closestExpiry;
      for (final b in batches) {
        final qty = (b['so_luong'] as num?)?.toDouble() ?? 0.0;
        if (qty <= 0) continue;
        totalStock += qty;
        final expStr = b['ngay_het_han'] as String?;
        if (expStr != null) {
          final exp = DateTime.tryParse(expStr);
          if (exp != null && (closestExpiry == null || exp.isBefore(closestExpiry))) {
            closestExpiry = exp;
          }
        }
      }

      return FoodItem(
        id: row['id'] as String,
        name: row['ten'] as String? ?? '',
        categoryName: row['ten_danh_muc'] as String? ?? '',
        baseUnit: row['don_vi_co_so'] as String? ?? '',
        totalStock: totalStock,
        closestExpiryDate: closestExpiry,
      );
    } catch (_) {
      return null;
    }
  }

  // =========================================================================
  // 2. QUẢN LÝ LÔ THỰC PHẨM (lo_thuc_pham) - CHUẨN FEFO
  // =========================================================================

  /// Stream danh sách các lô của một loại thực phẩm (FEFO: Hạn gần nhất xếp trước)
  Stream<List<FoodBatch>> watchBatchesForFood(String userId, String foodId) {
    if (_isMockUser(userId)) {
      final list = _memoryBatches.where((b) => b.foodId == foodId).toList();
      list.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      return Stream.value(list);
    }

    return _client
        .from('lo_thuc_pham')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) {
          final batches = rows
              .where((row) => row['thuc_pham_id'] == foodId)
              .map((row) => FoodBatch.fromMap(row['id'] as String, row))
              .where((b) => b.quantity > 0)
              .toList();
          batches.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
          return batches;
        });
  }

  /// Stream danh sách toàn bộ các lô đang có trong kho sắp xếp theo FEFO
  Stream<List<FoodBatch>> watchExpiringBatches(String userId) {
    if (_isMockUser(userId)) {
      final list = List<FoodBatch>.from(_memoryBatches);
      list.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      return Stream.value(list);
    }

    return _client
        .from('lo_thuc_pham')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) {
          final batches = rows
              .map((row) => FoodBatch.fromMap(row['id'] as String, row))
              .where((b) => b.quantity > 0)
              .toList();
          batches.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
          return batches;
        });
  }

  // =========================================================================
  // 3. THÊM LÔ MỚI & ĐỒNG BỘ MUA SẮM (IN - bien_dong_kho)
  // =========================================================================

  /// Thêm một lô thực phẩm vào kho (Supabase sequential writes)
  Future<void> addFoodBatch({
    required String userId,
    required String foodName,
    required String categoryName,
    required String baseUnit,
    required String locationName,
    required double quantity,
    required DateTime expiryDate,
    String? note,
  }) async {
    final trimmedName = foodName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Tên thực phẩm không được để trống.');
    }

    if (_isMockUser(userId)) {
      _addMemoryBatch(
        foodName: trimmedName,
        categoryName: categoryName,
        baseUnit: baseUnit,
        locationName: locationName,
        quantity: quantity,
        expiryDate: expiryDate,
        note: note,
      );
      return;
    }

    // 1. Tìm thuc_pham_global hiện có
    final existingRows = await _client
        .from('thuc_pham_global')
        .select()
        .eq('ten', trimmedName)
        .limit(1);

    String foodId;

    if (existingRows.isNotEmpty) {
      foodId = existingRows.first['id'] as String;
      // Cập nhật thông tin danh mục/đơn vị nếu cần
      await _client.from('thuc_pham_global').update({
        'ten_danh_muc': categoryName,
        'don_vi_co_so': baseUnit,
      }).eq('id', foodId);
    } else {
      // Tạo thực phẩm mới trong thuc_pham_global
      foodId = 'food_${DateTime.now().millisecondsSinceEpoch}';
      await _client.from('thuc_pham_global').insert({
        'id': foodId,
        'ten': trimmedName,
        'ten_danh_muc': categoryName,
        'don_vi_co_so': baseUnit,
      });
    }

    // 2. Tạo lô thực phẩm mới trong lo_thuc_pham (UUID auto-generated by DB)
    final batchInsertResult = await _client.from('lo_thuc_pham').insert({
      'user_id': userId,
      'thuc_pham_id': foodId,
      'ten_thuc_pham': trimmedName,
      'so_luong': quantity,
      'don_vi': baseUnit,
      'ngay_het_han': expiryDate.toIso8601String().substring(0, 10),
      'vi_tri': locationName,
      'ghi_chu': note ?? '',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }).select('id').single();

    final batchId = batchInsertResult['id'] as String;

    // 3. Ghi biến động kho (loai = IN)
    await _client.from('bien_dong_kho').insert({
      'user_id': userId,
      'thuc_pham_id': foodId,
      'ten_thuc_pham': trimmedName,
      'loai_bien_dong': 'IN',
      'so_luong_nhap': quantity,
      'so_luong_xuat': 0.0,
      'ghi_chu': note ?? 'Nhập mới vào $locationName',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // =========================================================================
  // 4. HỦY LÔ / BỎ THỰC PHẨM (DISCARD - bien_dong_kho)
  // =========================================================================

  /// Hủy một lô thực phẩm hết hạn/hư hỏng (Sequential read + write)
  Future<void> discardBatch({
    required String userId,
    required String batchId,
    required String reason,
  }) async {
    if (_isMockUser(userId)) {
      final batchIndex = _memoryBatches.indexWhere((b) => b.id == batchId);
      if (batchIndex < 0) return;
      final batch = _memoryBatches[batchIndex];
      final foodIndex = _memoryFoods.indexWhere((f) => f.id == batch.foodId);
      if (foodIndex >= 0) {
        final f = _memoryFoods[foodIndex];
        _memoryFoods[foodIndex] = f.copyWith(
          totalStock: (f.totalStock - batch.quantity).clamp(0.0, 999999.0),
        );
      }
      _memoryBatches.removeAt(batchIndex);
      _memoryMovements.insert(
        0,
        StockMovement(
          id: 'mov_${DateTime.now().millisecondsSinceEpoch}',
          batchId: batchId,
          foodName: batch.foodName,
          type: StockMovementType.discard,
          inQuantity: 0.0,
          outQuantity: batch.quantity,
          timestamp: DateTime.now(),
          note: reason,
        ),
      );
      return;
    }

    // 1. Đọc lô hiện tại
    final batchRow = await _client
        .from('lo_thuc_pham')
        .select()
        .eq('id', batchId)
        .eq('user_id', userId)
        .maybeSingle();

    if (batchRow == null) return;

    final foodId = batchRow['thuc_pham_id'] as String? ?? '';
    final foodName = batchRow['ten_thuc_pham'] as String? ?? '';
    final qty = (batchRow['so_luong'] as num?)?.toDouble() ?? 0.0;

    // 2. Cập nhật lô về 0
    await _client
        .from('lo_thuc_pham')
        .update({'so_luong': 0.0})
        .eq('id', batchId)
        .eq('user_id', userId);

    // 3. Ghi biến động DISCARD
    await _client.from('bien_dong_kho').insert({
      'user_id': userId,
      'thuc_pham_id': foodId,
      'ten_thuc_pham': foodName,
      'loai_bien_dong': 'DISCARD',
      'so_luong_nhap': 0.0,
      'so_luong_xuat': qty,
      'ghi_chu': reason,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // =========================================================================
  // 5. BIẾN ĐỘNG KHO (bien_dong_kho)
  // =========================================================================

  /// Stream lịch sử biến động kho
  Stream<List<StockMovement>> watchStockMovements(String userId) {
    if (_isMockUser(userId)) {
      final list = List<StockMovement>.from(_memoryMovements);
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return Stream.value(list);
    }

    return _client
        .from('bien_dong_kho')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) {
          final movements = rows
              .map((row) => StockMovement.fromMap(row['id'] as String, row))
              .toList();
          movements.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return movements;
        });
  }

  // =========================================================================
  // 6. VỊ TRÍ LƯU TRỮ (vi_tri_luu_tru)
  // =========================================================================

  static final List<Map<String, String>> _defaultLocations = [
    {'id': 'loc_1', 'ten_vi_tri': 'Ngăn mát tủ lạnh', 'mo_ta': 'Nhiệt độ 2°C - 5°C'},
    {'id': 'loc_2', 'ten_vi_tri': 'Ngăn đông đá', 'mo_ta': 'Nhiệt độ dưới -18°C'},
    {'id': 'loc_3', 'ten_vi_tri': 'Tủ gia vị khô', 'mo_ta': 'Nơi khô ráo thoáng mát'},
    {'id': 'loc_4', 'ten_vi_tri': 'Hộc rau quả', 'mo_ta': 'Bảo quản độ ẩm'},
  ];

  Future<List<Map<String, dynamic>>> getStorageLocations(String userId) async {
    if (_isMockUser(userId)) {
      return List.from(_defaultLocations);
    }
    try {
      final rows = await _client
          .from('vi_tri_luu_tru')
          .select()
          .eq('user_id', userId);

      if (rows.isEmpty) return List.from(_defaultLocations);

      return rows.map<Map<String, dynamic>>((row) => {
            'id': row['id'] as String,
            'ten_vi_tri': row['ten'] as String? ?? '',
            'mo_ta': row['mo_ta'] as String? ?? '',
          }).toList();
    } catch (_) {
      return List.from(_defaultLocations);
    }
  }

  Future<void> addStorageLocation(String userId, String name, String? description) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;
    if (_isMockUser(userId)) {
      _defaultLocations.add({
        'id': 'loc_${DateTime.now().millisecondsSinceEpoch}',
        'ten_vi_tri': trimmedName,
        'mo_ta': description?.trim() ?? '',
      });
      return;
    }
    await _client.from('vi_tri_luu_tru').insert({
      'user_id': userId,
      'ten': trimmedName,
      'mo_ta': description?.trim() ?? '',
    });
  }

  // =========================================================================
  // 7. CẤU HÌNH THỰC PHẨM & TỒN TỐI THIỂU (food_minimum_stock)
  // =========================================================================

  Future<void> updateFoodMinimumStock(String userId, String foodId, double minimumStock) async {
    final idx = _memoryFoods.indexWhere((f) => f.id == foodId);
    if (idx >= 0) {
      _memoryFoods[idx] = _memoryFoods[idx].copyWith(minimumStock: minimumStock);
    }
    if (_isMockUser(userId)) return;
    try {
      await _client.from('food_minimum_stock').upsert({
        'user_id': userId,
        'thuc_pham_id': foodId,
        'ton_kho_toi_thieu': minimumStock,
      });
    } catch (_) {
      // Ignored if offline
    }
  }

  void _addMemoryBatch({
    required String foodName,
    required String categoryName,
    required String baseUnit,
    required String locationName,
    required double quantity,
    required DateTime expiryDate,
    String? note,
  }) {
    final existingIndex = _memoryFoods.indexWhere(
      (f) => f.name.toLowerCase() == foodName.trim().toLowerCase(),
    );

    String foodId;
    if (existingIndex >= 0) {
      final existing = _memoryFoods[existingIndex];
      foodId = existing.id;
      final newTotal = existing.totalStock + quantity;
      DateTime? closestExp = existing.closestExpiryDate;
      if (closestExp == null || expiryDate.isBefore(closestExp)) {
        closestExp = expiryDate;
      }
      _memoryFoods[existingIndex] = existing.copyWith(
        totalStock: newTotal,
        closestExpiryDate: closestExp,
      );
    } else {
      foodId = 'food_${DateTime.now().millisecondsSinceEpoch}';
      _memoryFoods.add(
        FoodItem(
          id: foodId,
          name: foodName.trim(),
          categoryName: categoryName,
          baseUnit: baseUnit,
          totalStock: quantity,
          closestExpiryDate: expiryDate,
        ),
      );
    }

    final batchId = 'batch_${DateTime.now().millisecondsSinceEpoch}';
    _memoryBatches.add(
      FoodBatch(
        id: batchId,
        foodId: foodId,
        foodName: foodName.trim(),
        locationName: locationName,
        importDate: DateTime.now(),
        expiryDate: expiryDate,
        quantity: quantity,
        unit: baseUnit,
      ),
    );

    _memoryMovements.insert(
      0,
      StockMovement(
        id: 'mov_${DateTime.now().millisecondsSinceEpoch}',
        batchId: batchId,
        foodName: foodName.trim(),
        type: StockMovementType.inStock,
        inQuantity: quantity,
        outQuantity: 0.0,
        timestamp: DateTime.now(),
        note: note ?? 'Nhập mới vào $locationName',
      ),
    );
  }
}
