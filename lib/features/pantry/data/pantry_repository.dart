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
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Bộ nhớ đệm cục bộ (Fallback/Offline/Mock Testing)
  final List<FoodItem> _memoryFoods = List.from(PantryMockData.initialFoods);
  final List<FoodBatch> _memoryBatches = List.from(PantryMockData.initialBatches);
  final List<StockMovement> _memoryMovements = List.from(PantryMockData.initialMovements);

  CollectionReference<Map<String, dynamic>> _userPantryRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('thuc_pham');
  }

  CollectionReference<Map<String, dynamic>> _userBatchesRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('lo_thuc_pham');
  }

  CollectionReference<Map<String, dynamic>> _userMovementsRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('bien_dong_kho');
  }

  bool _isMockUser(String userId) => userId.isEmpty || userId.startsWith('mock_');

  // =========================================================================
  // 1. QUẢN LÝ THỰC PHẨM (thuc_pham)
  // =========================================================================

  /// Stream danh sách thực phẩm trong kho
  Stream<List<FoodItem>> watchFoodItems(String userId) {
    if (_isMockUser(userId)) {
      return Stream.value(List.unmodifiable(_memoryFoods));
    }

    return _userPantryRef(userId).snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) return _memoryFoods;
      return snapshot.docs
          .map((doc) => FoodItem.fromMap(doc.id, doc.data()))
          .toList();
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

    final doc = await _userPantryRef(userId).doc(foodId).get();
    if (!doc.exists || doc.data() == null) return null;
    return FoodItem.fromMap(doc.id, doc.data()!);
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
    });
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
    });
  }

  // =========================================================================
  // 3. THÊM LÔ MỚI & ĐỒNG BỘ MUA SẮM (IN - bien_dong_kho)
  // =========================================================================

  /// Thêm một lô thực phẩm vào kho (Giao dịch nguyên tử: Tạo/cập nhật Food, tạo Batch, ghi Movement)
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
    if (_isMockUser(userId)) {
      _addMemoryBatch(
        foodName: foodName,
        categoryName: categoryName,
        baseUnit: baseUnit,
        locationName: locationName,
        quantity: quantity,
        expiryDate: expiryDate,
        note: note,
      );
      return;
    }

    // Thực thi Firestore Transaction nguyên tử
    await _firestore.runTransaction((txn) async {
      final foodsRef = _userPantryRef(userId);
      final batchesRef = _userBatchesRef(userId);
      final movementsRef = _userMovementsRef(userId);

      // 1. Kiểm tra FoodItem đã tồn tại chưa
      final existingFoodsQuery = await foodsRef
          .where('ten_thuc_pham', isEqualTo: foodName.trim())
          .limit(1)
          .get();

      DocumentReference<Map<String, dynamic>> foodDocRef;
      String foodId;
      double newTotalStock = quantity;

      if (existingFoodsQuery.docs.isNotEmpty) {
        foodDocRef = existingFoodsQuery.docs.first.reference;
        foodId = foodDocRef.id;
        final currentStock = (existingFoodsQuery.docs.first.data()['so_luong_ton'] as num?)?.toDouble() ?? 0.0;
        newTotalStock = currentStock + quantity;

        txn.update(foodDocRef, {
          'so_luong_ton': newTotalStock,
          'don_vi_co_so': baseUnit,
        });
      } else {
        foodDocRef = foodsRef.doc();
        foodId = foodDocRef.id;
        txn.set(foodDocRef, {
          'ten_thuc_pham': foodName.trim(),
          'ten_danh_muc': categoryName,
          'don_vi_co_so': baseUnit,
          'nguong_sap_het': 1.0,
          'so_luong_ton': newTotalStock,
        });
      }

      // 2. Tạo lô thực phẩm mới (lo_thuc_pham)
      // Lưu đúng schema.sql & khớp với reader của StockDeductionService (MOD-04)
      final batchDocRef = batchesRef.doc();
      final now = DateTime.now();
      txn.set(batchDocRef, {
        'ma_thuc_pham': foodId,
        'ten_thuc_pham': foodName.trim(),
        'ten_vi_tri': locationName,
        'ngay_nhap': now.toIso8601String().substring(0, 10),
        'han_su_dung': expiryDate.toIso8601String().substring(0, 10),
        'so_luong': quantity,
        'so_luong_ton': quantity, // Cho phép MOD-04 trừ trực tiếp
        'don_vi': baseUnit,
      });

      // 3. Ghi lịch sử biến động kho (bien_dong_kho)
      final movementDocRef = movementsRef.doc();
      txn.set(movementDocRef, {
        'ma_lo': batchDocRef.id,
        'ma_chi_tiet_mua': null,
        'ma_mon_an': null,
        'loai_bien_dong': 'IN',
        'so_luong_nhap': quantity,
        'so_luong_xuat': 0.0,
        'thoi_diem': now.toIso8601String(),
        'ghi_chu': note ?? 'Nhập mới vào $locationName',
      });
    });
  }

  // =========================================================================
  // 4. HỦY / TIÊU HỦY LÔ HẾT HẠN (DISCARD - bien_dong_kho)
  // =========================================================================

  /// Hủy lô hàng hỏng/hết date khỏi kho
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
      final foodName = data['ten_thuc_pham'] as String? ?? '';
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
    });
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
