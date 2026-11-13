import 'package:cloud_firestore/cloud_firestore.dart';

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

/// Projection of low-stock configuration owned by MOD-01 (`cau_hinh_thuc_pham`).
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

/// Abstract contract for atomic pantry synchronization (`MOD-01-07`).
abstract interface class PantrySyncWriter {
  /// Writes newly purchased lots and records 'IN' movements in `bien_dong_kho`.
  Future<void> importBatchesInTransaction({
    required String userId,
    required Transaction transaction,
    required List<NewPantryBatchPayload> batches,
  });
}

/// Default Firestore implementation connecting to MOD-01 collections.
class FirestorePantryAdapter implements PantryReader, PantrySyncWriter {
  FirestorePantryAdapter({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<StorageLocationInfo>> getStorageLocations(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('vi_tri_luu_tru')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return StorageLocationInfo(
        id: doc.id,
        name: data['ten_vi_tri'] as String? ?? 'Vị trí mặc định',
        description: data['mo_ta'] as String?,
      );
    }).toList();
  }

  @override
  Future<List<PantryFoodInfo>> getFoods(String userId) async {
    // Check both user-scoped food collection and shared food collection
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('thuc_pham')
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return PantryFoodInfo(
          id: doc.id,
          name: data['ten_thuc_pham'] as String? ?? 'Thực phẩm',
          baseUnitId: data['ma_don_vi_co_so']?.toString() ?? '1',
          categoryId: data['ma_danh_muc']?.toString(),
          categoryName: data['ten_danh_muc'] as String?,
          barcode: data['ma_vach'] as String?,
          imageUrl: data['hinh_anh'] as String?,
        );
      }).toList();
    }

    // Fallback: check shared root collection
    final rootSnap = await _firestore.collection('thuc_pham').get();
    return rootSnap.docs.map((doc) {
      final data = doc.data();
      return PantryFoodInfo(
        id: doc.id,
        name: data['ten_thuc_pham'] as String? ?? 'Thực phẩm',
        baseUnitId: data['ma_don_vi_co_so']?.toString() ?? '1',
        categoryId: data['ma_danh_muc']?.toString(),
        categoryName: data['ten_danh_muc'] as String?,
        barcode: data['ma_vach'] as String?,
        imageUrl: data['hinh_anh'] as String?,
      );
    }).toList();
  }

  @override
  Future<List<MeasurementUnitInfo>> getUnits() async {
    final snapshot = await _firestore.collection('don_vi').get();
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return MeasurementUnitInfo(
          id: doc.id,
          name: data['ten_don_vi'] as String? ?? doc.id,
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
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('cau_hinh_thuc_pham')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return FoodStockConfigInfo(
        foodId: data['ma_thuc_pham']?.toString() ?? doc.id,
        threshold: (data['nguong_sap_het'] as num?)?.toDouble() ?? 0.0,
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

    // 1. Get all batches for foodId
    final batchesSnap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('lo_thuc_pham')
        .where('ma_thuc_pham', isEqualTo: foodId)
        .get();

    final usableBatchIds = <String>{};
    for (final doc in batchesSnap.docs) {
      final data = doc.data();
      final expRaw = data['han_su_dung']?.toString() ?? '';
      if (expRaw.compareTo(refKey) >= 0) {
        usableBatchIds.add(doc.id);
      }
    }

    if (usableBatchIds.isEmpty) return 0.0;

    // 2. Query ledger movements for usable batches:
    // Tồn = SUM(so_luong_nhap) - SUM(so_luong_xuat)
    final movementsSnap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('bien_dong_kho')
        .get();

    var totalBalance = 0.0;
    for (final doc in movementsSnap.docs) {
      final data = doc.data();
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
  Future<void> importBatchesInTransaction({
    required String userId,
    required Transaction transaction,
    required List<NewPantryBatchPayload> batches,
  }) async {
    final batchesColl =
        _firestore.collection('users').doc(userId).collection('lo_thuc_pham');
    final movementsColl =
        _firestore.collection('users').doc(userId).collection('bien_dong_kho');

    final now = DateTime.now();

    for (final b in batches) {
      // 1. Create lot document (`lo_thuc_pham`)
      final newBatchRef = batchesColl.doc();
      transaction.set(newBatchRef, {
        'ma_thuc_pham': b.foodId,
        'ma_vi_tri': b.locationId,
        'ngay_nhap': b.importDate.toIso8601String(),
        'han_su_dung': b.expiryDate.toIso8601String(),
        'so_luong_ton': b.quantity,
      });

      // 2. Record ledger movement ('IN')
      final movementRef = movementsColl.doc();
      transaction.set(movementRef, {
        'ma_lo': newBatchRef.id,
        'ma_chi_tiet_mua': b.shoppingItemId,
        'ma_mon_an': null,
        'loai_bien_dong': 'IN',
        'so_luong_nhap': b.quantity,
        'so_luong_xuat': 0.0,
        'thoi_diem': now.toIso8601String(),
        'ghi_chu': 'Nhập kho từ danh sách mua sắm: ${b.shoppingListName}',
      });
    }
  }
}

