import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/food_item.dart';
import 'models/food_batch.dart';
import 'models/stock_movement.dart';
import 'pantry_mock_data.dart';

/// Repository quản lý kho thực phẩm (MOD-01: Quản lý Kho - Nguyễn Văn Định)
/// Triển khai đầy đủ 8 nhóm nghiệp vụ MOD-01-01..MOD-01-08 trên Supabase (PostgreSQL) & Mock Local.
/// Khớp 100% với hợp đồng dữ liệu FEFO của MOD-04 (Hồ Nguyên Khởi) và MOD-02 (Nguyễn Vĩnh Hưng).
class PantryRepository {
  PantryRepository({SupabaseClient? supabaseClient})
      : _customClient = supabaseClient;

  final SupabaseClient? _customClient;
  SupabaseClient get _client => _customClient ?? Supabase.instance.client;

  // Bộ nhớ đệm cục bộ (Fallback/Offline/Mock Testing)
  static final List<FoodItem> _memoryFoods = List.from(
    PantryMockData.initialFoods,
  );
  static final List<FoodBatch> _memoryBatches = List.from(
    PantryMockData.initialBatches,
  );
  static final List<StockMovement> _memoryMovements = List.from(
    PantryMockData.initialMovements,
  );

  static final List<Map<String, String>> _initialDefaultLocations = [
    {
      'id': 'loc_1',
      'ten_vi_tri': 'Ngăn mát tủ lạnh',
      'mo_ta': 'Nhiệt độ 2°C - 5°C',
    },
    {
      'id': 'loc_2',
      'ten_vi_tri': 'Ngăn đông tủ lạnh',
      'mo_ta': 'Nhiệt độ dưới -18°C',
    },
    {
      'id': 'loc_3',
      'ten_vi_tri': 'Hộc rau quả',
      'mo_ta': 'Độ ẩm cao, giữ tươi rau củ',
    },
    {
      'id': 'loc_4',
      'ten_vi_tri': 'Cánh cửa tủ lạnh',
      'mo_ta': 'Trứng, sữa, đồ uống mở nắp',
    },
    {
      'id': 'loc_5',
      'ten_vi_tri': 'Tủ gia vị khô',
      'mo_ta': 'Nơi khô ráo, thoáng mát',
    },
    {'id': 'loc_6', 'ten_vi_tri': 'Kệ bếp', 'mo_ta': 'Nhiệt độ phòng'},
  ];

  static final List<Map<String, String>> _memoryLocations =
      _initialDefaultLocations.map((e) => Map<String, String>.from(e)).toList();

  /// Danh mục mã vạch mẫu chuẩn EAN-13 phục vụ tra cứu nhanh (MOD-01-02)
  static const List<Map<String, String>> sampleBarcodeCatalog = [
    {
      'code': '8934567890123',
      'name': 'Sữa tươi thanh trùng',
      'category': 'Đồ uống',
      'unit': 'hộp',
    },
    {
      'code': '8935001234567',
      'name': 'Thịt bò thăn Úc',
      'category': 'Thịt cá',
      'unit': 'g',
    },
    {
      'code': '8936009876543',
      'name': 'Rau cải xanh Đà Lạt',
      'category': 'Rau củ',
      'unit': 'bó',
    },
    {
      'code': '8937001122334',
      'name': 'Trứng gà ta',
      'category': 'Trứng',
      'unit': 'quả',
    },
    {
      'code': '8938005544332',
      'name': 'Sữa chua không đường',
      'category': 'Đồ uống',
      'unit': 'hũ',
    },
    {
      'code': '8939006677889',
      'name': 'Nước mắm cá cơm Phú Quốc',
      'category': 'Gia vị',
      'unit': 'chai',
    },
  ];

  /// Khôi phục trạng thái bộ nhớ mẫu để các Unit Test chạy độc lập 100%
  static void resetMockState() {
    _memoryFoods
      ..clear()
      ..addAll(PantryMockData.initialFoods);
    _memoryBatches
      ..clear()
      ..addAll(PantryMockData.initialBatches);
    _memoryMovements
      ..clear()
      ..addAll(PantryMockData.initialMovements);
    _memoryLocations
      ..clear()
      ..addAll(
        _initialDefaultLocations.map((e) => Map<String, String>.from(e)),
      );
  }

  bool _isMockUser(String userId) =>
      userId.isEmpty ||
      userId.startsWith('mock_') ||
      userId.startsWith('guest_');

  static String _cleanUnit(String? rawUnit) {
    final trimmed = (rawUnit ?? '').trim();
    if (trimmed.isEmpty) return 'phần';
    switch (trimmed.toLowerCase()) {
      case 'unit_g':
        return 'g';
      case 'unit_kg':
        return 'kg';
      case 'unit_ml':
        return 'ml';
      case 'unit_l':
        return 'l';
      case 'unit_qua':
        return 'quả';
      case 'unit_goi':
        return 'gói';
      case 'unit_hop':
        return 'hộp';
      case 'unit_chail':
      case 'unit_chai':
        return 'chai';
      default:
        return trimmed;
    }
  }

  /// Tính lại tổng tồn và hạn gần nhất cho 1 thực phẩm trong bộ nhớ đệm từ danh sách lô
  void _recomputeMemoryFoodAggregate(String foodId) {
    final idx = _memoryFoods.indexWhere((f) => f.id == foodId);
    if (idx < 0) return;

    final activeBatches = _memoryBatches
        .where((b) => b.foodId == foodId && b.quantity > 0)
        .toList();

    double total = 0.0;
    DateTime? closest;
    for (final b in activeBatches) {
      total += b.quantity;
      if (closest == null || b.expiryDate.isBefore(closest)) {
        closest = b.expiryDate;
      }
    }

    final current = _memoryFoods[idx];
    _memoryFoods[idx] = FoodItem(
      id: current.id,
      name: current.name,
      categoryName: current.categoryName,
      baseUnit: current.baseUnit,
      barcode: current.barcode,
      imageUrl: current.imageUrl,
      minimumStock: current.minimumStock,
      totalStock: total,
      closestExpiryDate: closest,
    );
  }

  // =========================================================================
  // 1. QUẢN LÝ THỰC PHẨM & TRA CỨU MÃ VẠCH (MOD-01-01, MOD-01-02, MOD-01-06)
  // =========================================================================

  /// Tra cứu thông tin sản phẩm theo mã vạch / QR (MOD-01-02 / FR-02)
  /// Chỉ trả về thông tin gợi ý để điền vào biểu mẫu, KHÔNG tự động tạo lô kho.
  Future<Map<String, String>?> lookupFoodByBarcode(
    String userId,
    String barcode,
  ) async {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) return null;

    // 1. Kiểm tra danh mục mẫu nội bộ
    for (final item in sampleBarcodeCatalog) {
      if (item['code'] == cleanCode) {
        return Map<String, String>.from(item);
      }
    }

    // 2. Kiểm tra trong bộ nhớ thực phẩm đã có mã vạch
    for (final food in _memoryFoods) {
      if (food.barcode == cleanCode) {
        return {
          'code': cleanCode,
          'name': food.name,
          'category': food.categoryName,
          'unit': food.baseUnit,
        };
      }
    }

    if (_isMockUser(userId)) return null;

    // 3. Tra cứu trên bảng thuc_pham_global của Supabase
    try {
      final row = await _client
          .from('thuc_pham_global')
          .select()
          .eq('ma_vach', cleanCode)
          .maybeSingle();

      if (row != null) {
        return {
          'code': cleanCode,
          'name': (row['ten'] as String?)?.trim() ?? '',
          'category': (row['ten_danh_muc'] as String?)?.trim() ?? 'Khác',
          'unit': _cleanUnit(row['don_vi_co_so']?.toString()),
        };
      }
    } catch (_) {}

    return null;
  }

  /// Stream danh sách thực phẩm trong kho (MOD-01)
  Stream<List<FoodItem>> watchFoodItems(String userId) {
    if (_isMockUser(userId)) {
      final visible = _memoryFoods.where((f) => f.totalStock > 0).toList();
      visible.sort((a, b) {
        final expA = a.closestExpiryDate;
        final expB = b.closestExpiryDate;
        if (expA == null && expB == null) return a.name.compareTo(b.name);
        if (expA == null) return 1;
        if (expB == null) return -1;
        return expA.compareTo(expB);
      });
      return Stream.value(List.unmodifiable(visible));
    }

    return _client
        .from('lo_thuc_pham')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .asyncMap((rows) async {
          final Map<String, List<Map<String, dynamic>>> grouped = {};
          for (final row in rows) {
            final foodId = row['thuc_pham_id']?.toString() ?? '';
            final qty = (row['so_luong'] as num?)?.toDouble() ?? 0.0;
            if (foodId.isEmpty || qty <= 0) continue;
            grouped.putIfAbsent(foodId, () => []).add(row);
          }

          if (grouped.isEmpty) return <FoodItem>[];

          final activeFoodIds = grouped.keys.toList();

          final Map<String, Map<String, dynamic>> globalById = {};
          try {
            final globalRows = await _client
                .from('thuc_pham_global')
                .select()
                .inFilter('id', activeFoodIds);
            for (final r in globalRows) {
              final id = r['id']?.toString();
              if (id != null) globalById[id] = r;
            }
          } catch (_) {}

          final Map<String, double> minStockByFoodId = {};
          try {
            final minRows = await _client
                .from('food_minimum_stock')
                .select()
                .eq('user_id', userId);
            for (final r in minRows) {
              final id = r['thuc_pham_id']?.toString();
              final minVal = (r['ton_kho_toi_thieu'] as num?)?.toDouble();
              if (id != null && minVal != null) {
                minStockByFoodId[id] = minVal;
              }
            }
          } catch (_) {}

          final items = grouped.entries.map((entry) {
            final foodId = entry.key;
            final batches = entry.value;
            final firstBatch = batches.first;
            final globalMeta = globalById[foodId];

            double totalStock = 0.0;
            DateTime? closestExpiry;

            for (final b in batches) {
              final qty = (b['so_luong'] as num?)?.toDouble() ?? 0.0;
              if (qty <= 0) continue;
              totalStock += qty;
              final expStr = b['ngay_het_han']?.toString();
              if (expStr != null && expStr.isNotEmpty) {
                final exp = DateTime.tryParse(expStr)?.toLocal();
                if (exp != null &&
                    (closestExpiry == null || exp.isBefore(closestExpiry))) {
                  closestExpiry = exp;
                }
              }
            }

            final batchUnit = (firstBatch['don_vi'] as String?)?.trim() ?? '';
            final resolvedUnit = batchUnit.isNotEmpty
                ? _cleanUnit(batchUnit)
                : _cleanUnit(globalMeta?['don_vi_co_so']?.toString());

            final rawCategory =
                (globalMeta?['ten_danh_muc'] as String?)?.trim() ?? '';
            final resolvedMinStock = minStockByFoodId[foodId] ??
                (globalMeta?['ton_kho_toi_thieu'] as num?)?.toDouble() ??
                1.0;

            return FoodItem(
              id: foodId,
              name:
                  (firstBatch['ten_thuc_pham'] as String?)?.trim().isNotEmpty ==
                          true
                      ? (firstBatch['ten_thuc_pham'] as String).trim()
                      : (globalMeta?['ten'] as String? ?? 'Thực phẩm'),
              categoryName: rawCategory.isNotEmpty ? rawCategory : 'Khác',
              baseUnit: resolvedUnit,
              barcode: globalMeta?['ma_vach'] as String?,
              imageUrl: globalMeta?['hinh_anh'] as String?,
              minimumStock: resolvedMinStock,
              totalStock: totalStock,
              closestExpiryDate: closestExpiry,
            );
          }).toList();

          items.sort((a, b) {
            final expA = a.closestExpiryDate;
            final expB = b.closestExpiryDate;
            if (expA == null && expB == null) return a.name.compareTo(b.name);
            if (expA == null) return 1;
            if (expB == null) return -1;
            return expA.compareTo(expB);
          });

          return items;
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
      final row = await _client
          .from('thuc_pham_global')
          .select()
          .eq('id', foodId)
          .maybeSingle();

      if (row == null) return null;

      final batches = await _client
          .from('lo_thuc_pham')
          .select()
          .eq('user_id', userId)
          .eq('thuc_pham_id', foodId);

      double? customMinStock;
      try {
        final minRow = await _client
            .from('food_minimum_stock')
            .select()
            .eq('user_id', userId)
            .eq('thuc_pham_id', foodId)
            .maybeSingle();
        customMinStock = (minRow?['ton_kho_toi_thieu'] as num?)?.toDouble();
      } catch (_) {}

      double totalStock = 0.0;
      DateTime? closestExpiry;
      String? batchUnit;
      for (final b in batches) {
        final qty = (b['so_luong'] as num?)?.toDouble() ?? 0.0;
        if (qty <= 0) continue;
        totalStock += qty;
        final u = (b['don_vi'] as String?)?.trim();
        if (batchUnit == null && u != null && u.isNotEmpty) {
          batchUnit = u;
        }
        final expStr = b['ngay_het_han'] as String?;
        if (expStr != null) {
          final exp = DateTime.tryParse(expStr)?.toLocal();
          if (exp != null &&
              (closestExpiry == null || exp.isBefore(closestExpiry))) {
            closestExpiry = exp;
          }
        }
      }

      final rawCategory = (row['ten_danh_muc'] as String?)?.trim() ?? '';

      return FoodItem(
        id: row['id'] as String,
        name: row['ten'] as String? ?? '',
        categoryName: rawCategory.isNotEmpty ? rawCategory : 'Khác',
        baseUnit: batchUnit != null
            ? _cleanUnit(batchUnit)
            : _cleanUnit(row['don_vi_co_so']?.toString()),
        barcode: row['ma_vach'] as String?,
        imageUrl: row['hinh_anh'] as String?,
        minimumStock: customMinStock ??
            (row['ton_kho_toi_thieu'] as num?)?.toDouble() ??
            1.0,
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
      final list = _memoryBatches
          .where((b) => b.foodId == foodId && b.quantity > 0)
          .toList();
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
      final list = _memoryBatches.where((b) => b.quantity > 0).toList();
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
  // 3. NHẬP LÔ MỚI (MOD-01-01 / TC-03 / TC-04)
  // =========================================================================

  /// Thêm một lô thực phẩm vào kho (Tách riêng lô theo hạn dùng - TC-04)
  Future<void> addFoodBatch({
    required String userId,
    required String foodName,
    required String categoryName,
    required String baseUnit,
    required String locationName,
    required double quantity,
    required DateTime expiryDate,
    String? barcode,
    String? note,
  }) async {
    final trimmedName = foodName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Tên thực phẩm không được để trống.');
    }
    if (quantity.isNaN || quantity.isInfinite || quantity <= 0) {
      throw ArgumentError('Số lượng nhập kho phải lớn hơn 0.');
    }
    final trimmedLoc =
        locationName.trim().isEmpty ? 'Ngăn mát tủ lạnh' : locationName.trim();
    final trimmedUnit = baseUnit.trim().isEmpty ? 'phần' : baseUnit.trim();
    final trimmedBarcode =
        (barcode != null && barcode.trim().isNotEmpty) ? barcode.trim() : null;

    if (_isMockUser(userId)) {
      _addMemoryBatch(
        foodName: trimmedName,
        categoryName: categoryName,
        baseUnit: trimmedUnit,
        locationName: trimmedLoc,
        quantity: quantity,
        expiryDate: expiryDate,
        barcode: trimmedBarcode,
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
      final updateMap = <String, dynamic>{
        'ten_danh_muc': categoryName,
        'don_vi_co_so': trimmedUnit,
      };
      if (trimmedBarcode != null) {
        updateMap['ma_vach'] = trimmedBarcode;
      }
      await _client.from('thuc_pham_global').update(updateMap).eq('id', foodId);
    } else {
      foodId = 'food_${DateTime.now().millisecondsSinceEpoch}';
      await _client.from('thuc_pham_global').insert({
        'id': foodId,
        'ten': trimmedName,
        'ten_danh_muc': categoryName,
        'don_vi_co_so': trimmedUnit,
        if (trimmedBarcode != null) 'ma_vach': trimmedBarcode,
      });
    }

    // 2. Tạo lô thực phẩm riêng biệt trong lo_thuc_pham (Không gộp lô khác HSD - TC-04)
    final batchInsertResult = await _client
        .from('lo_thuc_pham')
        .insert({
          'user_id': userId,
          'thuc_pham_id': foodId,
          'ten_thuc_pham': trimmedName,
          'so_luong': quantity,
          'don_vi': trimmedUnit,
          'ngay_het_han': expiryDate.toIso8601String().substring(0, 10),
          'vi_tri': trimmedLoc,
          'ghi_chu': note ?? '',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();

    final batchId = batchInsertResult['id'] as String;

    // 3. Ghi sổ cái biến động kho (loai = IMPORT, 1 chiều dương - TC-13)
    await _client.from('bien_dong_kho').insert({
      'user_id': userId,
      'thuc_pham_id': foodId,
      'ten_thuc_pham': trimmedName,
      'loai_bien_dong': 'IMPORT',
      'so_luong_nhap': quantity,
      'so_luong_xuat': 0.0,
      'ghi_chu': note ?? 'Nhập mới vào $trimmedLoc (lô $batchId)',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // =========================================================================
  // 4. CHUYỂN VỊ TRÍ, ĐIỀU CHỈNH TỒN & HỦY LÔ (MOD-01-05 / TC-13..TC-16)
  // =========================================================================

  /// Chuyển lô sang vị trí lưu trữ khác (MOD-01-05 / TC-15)
  /// Ràng buộc: Chỉ đổi cột vị trí lưu trữ, giữ nguyên tồn kho, KHÔNG tạo dòng nhập/xuất.
  Future<void> moveBatchLocation({
    required String userId,
    required String batchId,
    required String newLocationName,
  }) async {
    final targetLoc = newLocationName.trim();
    if (targetLoc.isEmpty) {
      throw ArgumentError('Vị trí lưu trữ đích không được để trống.');
    }

    if (_isMockUser(userId)) {
      final idx = _memoryBatches.indexWhere((b) => b.id == batchId);
      if (idx < 0) {
        throw StateError('Không tìm thấy lô thực phẩm cần chuyển.');
      }
      final old = _memoryBatches[idx];
      if (old.locationName == targetLoc) return;
      _memoryBatches[idx] = FoodBatch(
        id: old.id,
        foodId: old.foodId,
        foodName: old.foodName,
        locationName: targetLoc,
        importDate: old.importDate,
        expiryDate: old.expiryDate,
        quantity: old.quantity,
        unit: old.unit,
      );
      return;
    }

    await _client
        .from('lo_thuc_pham')
        .update({'vi_tri': targetLoc})
        .eq('id', batchId)
        .eq('user_id', userId);
  }

  /// Điều chỉnh số lượng tồn thực tế của lô khi kiểm kê (MOD-01-05 / TC-13, TC-14, TC-16)
  /// Ràng buộc: Cấm tồn âm (< 0), bắt buộc có lý do, ghi biến động mới ADJUST chỉ một chiều dương.
  Future<void> adjustBatchQuantity({
    required String userId,
    required String batchId,
    required double newQuantity,
    required String reason,
  }) async {
    if (newQuantity.isNaN || newQuantity.isInfinite || newQuantity < 0) {
      throw StateError('Số lượng tồn kho không được âm.');
    }
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw ArgumentError('Vui lòng nhập lý do điều chỉnh tồn kho.');
    }

    if (_isMockUser(userId)) {
      final idx = _memoryBatches.indexWhere((b) => b.id == batchId);
      if (idx < 0) {
        throw StateError('Không tìm thấy lô thực phẩm cần điều chỉnh.');
      }
      final batch = _memoryBatches[idx];
      final delta = newQuantity - batch.quantity;
      if (delta.abs() < 1e-9) {
        throw ArgumentError(
          'Số lượng mới trùng với số lượng hiện tại.',
        );
      }

      final inQty = delta > 0 ? delta : 0.0;
      final outQty = delta < 0 ? -delta : 0.0;

      if (newQuantity == 0) {
        _memoryBatches.removeAt(idx);
      } else {
        _memoryBatches[idx] = FoodBatch(
          id: batch.id,
          foodId: batch.foodId,
          foodName: batch.foodName,
          locationName: batch.locationName,
          importDate: batch.importDate,
          expiryDate: batch.expiryDate,
          quantity: newQuantity,
          unit: batch.unit,
        );
      }
      _recomputeMemoryFoodAggregate(batch.foodId);

      _memoryMovements.insert(
        0,
        StockMovement(
          id: 'mov_${DateTime.now().millisecondsSinceEpoch}',
          batchId: batchId,
          foodName: batch.foodName,
          type: StockMovementType.adjust,
          inQuantity: inQty,
          outQuantity: outQty,
          timestamp: DateTime.now(),
          note: trimmedReason,
        ),
      );
      return;
    }

    final batchRow = await _client
        .from('lo_thuc_pham')
        .select()
        .eq('id', batchId)
        .eq('user_id', userId)
        .maybeSingle();

    if (batchRow == null) {
      throw StateError('Không tìm thấy lô thực phẩm thuộc quyền sở hữu.');
    }

    final oldQty = (batchRow['so_luong'] as num?)?.toDouble() ?? 0.0;
    final delta = newQuantity - oldQty;
    if (delta.abs() < 1e-9) {
      throw ArgumentError('Số lượng mới trùng với số lượng hiện tại.');
    }

    final inQty = delta > 0 ? delta : 0.0;
    final outQty = delta < 0 ? -delta : 0.0;
    final foodId = batchRow['thuc_pham_id']?.toString() ?? '';
    final foodName = batchRow['ten_thuc_pham']?.toString() ?? '';

    await _client
        .from('lo_thuc_pham')
        .update({'so_luong': newQuantity})
        .eq('id', batchId)
        .eq('user_id', userId);

    await _client.from('bien_dong_kho').insert({
      'user_id': userId,
      'thuc_pham_id': foodId,
      'ten_thuc_pham': foodName,
      'loai_bien_dong': 'ADJUST',
      'so_luong_nhap': inQty,
      'so_luong_xuat': outQty,
      'ghi_chu': trimmedReason,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Hủy một lô thực phẩm hết hạn/hư hỏng (DISCARD / EXPIRED - bien_dong_kho)
  Future<void> discardBatch({
    required String userId,
    required String batchId,
    required String reason,
    bool isExpired = false,
  }) async {
    final trimmedReason = reason.trim().isEmpty
        ? (isExpired ? 'Tiêu hủy lô quá hạn sử dụng' : 'Loại bỏ lô khỏi kho')
        : reason.trim();

    if (_isMockUser(userId)) {
      final batchIndex = _memoryBatches.indexWhere((b) => b.id == batchId);
      if (batchIndex < 0) return;
      final batch = _memoryBatches[batchIndex];
      _memoryBatches.removeAt(batchIndex);
      _recomputeMemoryFoodAggregate(batch.foodId);

      _memoryMovements.insert(
        0,
        StockMovement(
          id: 'mov_${DateTime.now().millisecondsSinceEpoch}',
          batchId: batchId,
          foodName: batch.foodName,
          type:
              isExpired ? StockMovementType.expired : StockMovementType.discard,
          inQuantity: 0.0,
          outQuantity: batch.quantity,
          timestamp: DateTime.now(),
          note: trimmedReason,
        ),
      );
      return;
    }

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
    if (qty <= 0) return;

    await _client
        .from('lo_thuc_pham')
        .update({'so_luong': 0.0})
        .eq('id', batchId)
        .eq('user_id', userId);

    await _client.from('bien_dong_kho').insert({
      'user_id': userId,
      'thuc_pham_id': foodId,
      'ten_thuc_pham': foodName,
      'loai_bien_dong': isExpired ? 'EXPIRED' : 'DISCARD',
      'so_luong_nhap': 0.0,
      'so_luong_xuat': qty,
      'ghi_chu': trimmedReason,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // =========================================================================
  // 5. SỔ CÁI BIẾN ĐỘNG KHO (bien_dong_kho - TC-16)
  // =========================================================================

  /// Stream lịch sử biến động kho (chỉ đọc và ghi thêm dòng mới, bất biến theo TC-16)
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
  // 6. QUẢN LÝ VỊ TRÍ LƯU TRỮ (MOD-01-04 / FR-04)
  // =========================================================================

  Future<List<Map<String, dynamic>>> getStorageLocations(String userId) async {
    if (_isMockUser(userId)) {
      return _memoryLocations.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    try {
      var rows =
          await _client.from('vi_tri_luu_tru').select().eq('user_id', userId);

      // Tự động khởi tạo bộ vị trí chuẩn lần đầu cho tài khoản mới
      if (rows.isEmpty) {
        try {
          await _client.from('vi_tri_luu_tru').insert(
                _initialDefaultLocations
                    .map(
                      (loc) => {
                        'user_id': userId,
                        'ten': loc['ten_vi_tri'],
                        'mo_ta': loc['mo_ta'],
                      },
                    )
                    .toList(),
              );
          rows = await _client
              .from('vi_tri_luu_tru')
              .select()
              .eq('user_id', userId);
        } catch (_) {
          return _initialDefaultLocations
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }

      return rows
          .map<Map<String, dynamic>>(
            (row) => {
              'id': row['id'].toString(),
              'ten_vi_tri': row['ten'] as String? ?? '',
              'mo_ta': row['mo_ta'] as String? ?? '',
            },
          )
          .toList();
    } catch (_) {
      return _initialDefaultLocations
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }

  /// Đếm số lô đang còn tồn (> 0) nằm tại vị trí [locationName]
  Future<int> countActiveBatchesInLocation(
    String userId,
    String locationName,
  ) async {
    final target = locationName.trim().toLowerCase();
    if (_isMockUser(userId)) {
      return _memoryBatches
          .where(
            (b) =>
                b.quantity > 0 && b.locationName.trim().toLowerCase() == target,
          )
          .length;
    }

    final rows = await _client
        .from('lo_thuc_pham')
        .select('id, vi_tri, so_luong')
        .eq('user_id', userId)
        .gt('so_luong', 0);

    return rows
        .where(
          (r) => (r['vi_tri'] as String? ?? '').trim().toLowerCase() == target,
        )
        .length;
  }

  Future<void> addStorageLocation(
    String userId,
    String name,
    String? description,
  ) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Tên vị trí lưu trữ không được để trống.');
    }

    final current = await getStorageLocations(userId);
    final exists = current.any(
      (loc) =>
          (loc['ten_vi_tri'] as String? ?? '').trim().toLowerCase() ==
          trimmedName.toLowerCase(),
    );
    if (exists) {
      throw StateError('Vị trí "$trimmedName" đã tồn tại trong kho.');
    }

    if (_isMockUser(userId)) {
      _memoryLocations.add({
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

  /// Cập nhật tên/mô tả vị trí lưu trữ và đồng bộ tên vị trí trên các lô đang tham chiếu
  Future<void> updateStorageLocation({
    required String userId,
    required String locationId,
    required String oldName,
    required String newName,
    String? description,
  }) async {
    final trimmedNew = newName.trim();
    if (trimmedNew.isEmpty) {
      throw ArgumentError('Tên vị trí lưu trữ không được để trống.');
    }

    final current = await getStorageLocations(userId);
    final duplicate = current.any(
      (loc) =>
          loc['id'].toString() != locationId &&
          (loc['ten_vi_tri'] as String? ?? '').trim().toLowerCase() ==
              trimmedNew.toLowerCase(),
    );
    if (duplicate) {
      throw StateError('Tên vị trí "$trimmedNew" bị trùng với vị trí khác.');
    }

    if (_isMockUser(userId)) {
      final idx = _memoryLocations.indexWhere((l) => l['id'] == locationId);
      if (idx >= 0) {
        _memoryLocations[idx] = {
          'id': locationId,
          'ten_vi_tri': trimmedNew,
          'mo_ta': description?.trim() ?? '',
        };
      }
      if (oldName.trim() != trimmedNew) {
        for (var i = 0; i < _memoryBatches.length; i++) {
          final b = _memoryBatches[i];
          if (b.locationName.trim() == oldName.trim()) {
            _memoryBatches[i] = FoodBatch(
              id: b.id,
              foodId: b.foodId,
              foodName: b.foodName,
              locationName: trimmedNew,
              importDate: b.importDate,
              expiryDate: b.expiryDate,
              quantity: b.quantity,
              unit: b.unit,
            );
          }
        }
      }
      return;
    }

    await _client
        .from('vi_tri_luu_tru')
        .update({'ten': trimmedNew, 'mo_ta': description?.trim() ?? ''})
        .eq('id', locationId)
        .eq('user_id', userId);

    if (oldName.trim() != trimmedNew) {
      await _client
          .from('lo_thuc_pham')
          .update({'vi_tri': trimmedNew})
          .eq('user_id', userId)
          .eq('vi_tri', oldName.trim());
    }
  }

  /// Xóa vị trí lưu trữ (FR-04: Chặn xóa nếu vị trí vẫn đang chứa lô thực phẩm còn tồn)
  Future<void> deleteStorageLocation({
    required String userId,
    required String locationId,
    required String locationName,
  }) async {
    final activeCount = await countActiveBatchesInLocation(
      userId,
      locationName,
    );
    if (activeCount > 0) {
      throw StateError(
        'Vị trí "$locationName" đang chứa $activeCount lô thực phẩm. '
        'Vui lòng chuyển các lô sang vị trí khác trước khi xóa!',
      );
    }

    if (_isMockUser(userId)) {
      _memoryLocations.removeWhere((l) => l['id'] == locationId);
      return;
    }

    await _client
        .from('vi_tri_luu_tru')
        .delete()
        .eq('id', locationId)
        .eq('user_id', userId);
  }

  // =========================================================================
  // 7. CẤU HÌNH THỰC PHẨM & TỒN TỐI THIỂU (food_minimum_stock)
  // =========================================================================

  Future<void> updateFoodMinimumStock(
    String userId,
    String foodId,
    double minimumStock,
  ) async {
    if (minimumStock.isNaN || minimumStock.isInfinite || minimumStock < 0) {
      throw ArgumentError('Ngưỡng tồn tối thiểu không được âm.');
    }
    final idx = _memoryFoods.indexWhere((f) => f.id == foodId);
    if (idx >= 0) {
      _memoryFoods[idx] = _memoryFoods[idx].copyWith(
        minimumStock: minimumStock,
      );
    }
    if (_isMockUser(userId)) return;
    try {
      await _client.from('food_minimum_stock').upsert({
        'user_id': userId,
        'thuc_pham_id': foodId,
        'ton_kho_toi_thieu': minimumStock,
      }, onConflict: 'user_id,thuc_pham_id');
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
    String? barcode,
    String? note,
  }) {
    final existingIndex = _memoryFoods.indexWhere(
      (f) => f.name.toLowerCase() == foodName.trim().toLowerCase(),
    );

    String foodId;
    if (existingIndex >= 0) {
      final existing = _memoryFoods[existingIndex];
      foodId = existing.id;
      _memoryFoods[existingIndex] = existing.copyWith(
        categoryName: categoryName,
        baseUnit: baseUnit,
        barcode: barcode ?? existing.barcode,
      );
    } else {
      foodId = 'food_${DateTime.now().millisecondsSinceEpoch}';
      _memoryFoods.add(
        FoodItem(
          id: foodId,
          name: foodName.trim(),
          categoryName: categoryName,
          baseUnit: baseUnit,
          barcode: barcode,
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
    _recomputeMemoryFoodAggregate(foodId);

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
