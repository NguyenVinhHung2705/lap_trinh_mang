import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/food_item.dart';
import 'models/food_batch.dart';
import 'models/stock_movement.dart';
import 'pantry_mock_data.dart';

/// Repository quản lý kho thực phẩm (MOD-01: Quản lý Kho - Nguyễn Văn Định)
/// Triển khai đầy đủ Cloud Firestore user-scoped: `/users/{uid}/...`
/// Khớp 100% với hợp đồng dữ liệu FEFO của MOD-04 (Hồ Nguyên Khởi) và MOD-02 (Nguyễn Vĩnh Hưng)
class PantryRepository {
  PantryRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  // Bộ nhớ đệm cục bộ (Fallback/Offline/Mock Testing)
  static final List<FoodItem> _memoryFoods = List.from(PantryMockData.initialFoods);
  static final List<FoodBatch> _memoryBatches = List.from(PantryMockData.initialBatches);
  static final List<StockMovement> _memoryMovements = List.from(PantryMockData.initialMovements);

  CollectionReference<Map<String, dynamic>> _userPantryRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('thuc_pham');
  }

  CollectionReference<Map<String, dynamic>> _userBatchesRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('lo_thuc_pham');
  }

  CollectionReference<Map<String, dynamic>> _userMovementsRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('bien_dong_kho');
  }

  CollectionReference<Map<String, dynamic>> _userLocationsRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('vi_tri_luu_tru');
  }

  bool _isMockUser(String userId) =>
      userId.isEmpty || userId.startsWith('mock_') || userId.startsWith('guest_');

  // =========================================================================
  // 1. QUẢN LÝ THỰC PHẨM (thuc_pham)
  // =========================================================================

  /// Stream danh sách thực phẩm trong kho (MOD-01)
  /// Phân lập dữ liệu hoàn toàn theo userId: `/users/{uid}/thuc_pham`
  Stream<List<FoodItem>> watchFoodItems(String userId) {
    if (_isMockUser(userId)) {
      return Stream.value(List.unmodifiable(_memoryFoods));
    }

    return _userPantryRef(userId).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => FoodItem.fromMap(doc.id, doc.data()))
          .toList();
    }).handleError((_) => const <FoodItem>[]);
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
      final doc = await _userPantryRef(userId).doc(foodId).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return FoodItem.fromMap(doc.id, doc.data()!);
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

    return _userBatchesRef(userId)
        .where('ma_thuc_pham', isEqualTo: foodId)
        .snapshots()
        .map((snapshot) {
      final batches = snapshot.docs
          .map((doc) => FoodBatch.fromMap(doc.id, doc.data()))
          .where((b) => b.quantity > 0)
          .toList();
      batches.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      return batches;
    }).handleError((_) => const <FoodBatch>[]);
  }

  /// Stream danh sách toàn bộ các lô đang có trong kho sắp xếp theo FEFO
  Stream<List<FoodBatch>> watchExpiringBatches(String userId) {
    if (_isMockUser(userId)) {
      final list = List<FoodBatch>.from(_memoryBatches);
      list.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      return Stream.value(list);
    }

    return _userBatchesRef(userId).snapshots().map((snapshot) {
      final batches = snapshot.docs
          .map((doc) => FoodBatch.fromMap(doc.id, doc.data()))
          .where((b) => b.quantity > 0)
          .toList();
      batches.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      return batches;
    }).handleError((_) => const <FoodBatch>[]);
  }

  // =========================================================================
  // 3. THÊM LÔ MỚI & ĐỒNG BỘ MUA SẮM (IN - bien_dong_kho)
  // =========================================================================

  /// Thêm một lô thực phẩm vào kho (Thực hiện Firestore WriteBatch nguyên tử)
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

    // 1. Tìm thuc_pham hiện có ngoài transaction để tránh giới hạn Query trong transaction
    final querySnap = await _userPantryRef(userId)
        .where('ten_thuc_pham', isEqualTo: trimmedName)
        .limit(1)
        .get();

    final batch = _firestore.batch();
    String foodId;

    if (querySnap.docs.isNotEmpty) {
      final foodDoc = querySnap.docs.first;
      foodId = foodDoc.id;
      final currentStock = (foodDoc.data()['so_luong_ton'] as num?)?.toDouble() ?? 0.0;
      final newStock = currentStock + quantity;

      // Cập nhật ngày hết hạn gần nhất nếu lô mới có hạn sớm hơn
      DateTime? closestExp;
      final expStr = foodDoc.data()['han_su_dung_gan_nhat'] as String?;
      if (expStr != null) {
        closestExp = DateTime.tryParse(expStr);
      }
      if (closestExp == null || expiryDate.isBefore(closestExp)) {
        closestExp = expiryDate;
      }

      batch.update(foodDoc.reference, {
        'so_luong_ton': newStock,
        'han_su_dung_gan_nhat': closestExp.toIso8601String(),
        'ten_danh_muc': categoryName,
        'don_vi_co_so': baseUnit,
      });
    } else {
      final newFoodRef = _userPantryRef(userId).doc();
      foodId = newFoodRef.id;
      batch.set(newFoodRef, {
        'ten_thuc_pham': trimmedName,
        'ten_danh_muc': categoryName,
        'loai_thuc_pham': categoryName,
        'don_vi_co_so': baseUnit,
        'don_vi_chuan': baseUnit,
        'so_luong_ton': quantity,
        'nguong_sap_het': 1.0,
        'muc_ton_toi_thieu': 1.0,
        'han_su_dung_gan_nhat': expiryDate.toIso8601String(),
        'ngay_tao': DateTime.now().toIso8601String(),
      });
    }

    // 2. Tạo `lo_thuc_pham` mới
    final batchRef = _userBatchesRef(userId).doc();
    batch.set(batchRef, {
      'ma_thuc_pham': foodId,
      'ten_thuc_pham': trimmedName,
      'ten_vi_tri': locationName,
      'ngay_nhap': DateTime.now().toIso8601String(),
      'han_su_dung': expiryDate.toIso8601String(),
      'so_luong': quantity,
      'so_luong_ton': quantity,
      'don_vi': baseUnit,
      if (note != null && note.isNotEmpty) 'ghi_chu': note,
    });

    // 3. Ghi `bien_dong_kho` (loai = IN)
    final movementRef = _userMovementsRef(userId).doc();
    batch.set(movementRef, {
      'ma_lo': batchRef.id,
      'loai_bien_dong': 'IN',
      'so_luong_nhap': quantity,
      'so_luong_xuat': 0.0,
      'thoi_diem': DateTime.now().toIso8601String(),
      'ghi_chu': note ?? 'Nhập mới vào $locationName',
    });

    await batch.commit();
  }

  // =========================================================================
  // 4. HỦY LÔ / BỎ THỰC PHẨM (DISCARD - bien_dong_kho)
  // =========================================================================

  /// Hủy một lô thực phẩm hết hạn/hư hỏng (Giao dịch nguyên tử)
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

    await _firestore.runTransaction((txn) async {
      final batchRef = _userBatchesRef(userId).doc(batchId);
      final batchDoc = await txn.get(batchRef);
      if (!batchDoc.exists) return;

      final data = batchDoc.data()!;
      final foodId = data['ma_thuc_pham'] as String? ?? '';
      final qty = (data['so_luong_ton'] as num?)?.toDouble() ??
          (data['so_luong'] as num?)?.toDouble() ??
          0.0;

      // 1. Giảm tồn kho FoodItem
      if (foodId.isNotEmpty) {
        final foodRef = _userPantryRef(userId).doc(foodId);
        final foodDoc = await txn.get(foodRef);
        if (foodDoc.exists) {
          final cur = (foodDoc.data()?['so_luong_ton'] as num?)?.toDouble() ?? 0.0;
          txn.update(foodRef, {
            'so_luong_ton': (cur - qty).clamp(0.0, 999999.0),
          });
        }
      }

      // 2. Cập nhật lô về 0 hoặc xóa
      txn.update(batchRef, {'so_luong_ton': 0.0, 'so_luong': 0.0});

      // 3. Ghi biến động DISCARD
      final movRef = _userMovementsRef(userId).doc();
      txn.set(movRef, {
        'ma_lo': batchId,
        'loai_bien_dong': 'DISCARD',
        'so_luong_nhap': 0.0,
        'so_luong_xuat': qty,
        'thoi_diem': DateTime.now().toIso8601String(),
        'ghi_chu': reason,
      });
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

    return _userMovementsRef(userId)
        .orderBy('thoi_diem', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => StockMovement.fromMap(doc.id, doc.data()))
          .toList();
    }).handleError((_) => const <StockMovement>[]);
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
      final snap = await _userLocationsRef(userId).get();
      if (snap.docs.isEmpty) return List.from(_defaultLocations);
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
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
    await _userLocationsRef(userId).add({
      'ten_vi_tri': trimmedName,
      'mo_ta': description?.trim(),
      'ngay_tao': DateTime.now().toIso8601String(),
    });
  }

  // =========================================================================
  // 7. CẤU HÌNH THỰC PHẨM & TỒN TỐI THIỂU (cau_hinh_thuc_pham)
  // =========================================================================

  Future<void> updateFoodMinimumStock(String userId, String foodId, double minimumStock) async {
    final idx = _memoryFoods.indexWhere((f) => f.id == foodId);
    if (idx >= 0) {
      _memoryFoods[idx] = _memoryFoods[idx].copyWith(minimumStock: minimumStock);
    }
    if (_isMockUser(userId)) return;
    try {
      await _userPantryRef(userId).doc(foodId).update({
        'nguong_sap_het': minimumStock,
        'muc_ton_toi_thieu': minimumStock,
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
