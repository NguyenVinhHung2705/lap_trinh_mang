import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/meal_repository.dart';
import '../data/models/consumption_request.dart';
import '../data/models/meal.dart';

/// Single pantry batch candidate for FEFO allocation (`lo_thuc_pham`, owned by `MOD-01`).
class PantryBatchInfo {
  const PantryBatchInfo({
    required this.id,
    required this.foodId,
    required this.locationId,
    required this.importDate,
    required this.expiryDate,
    required this.availableQuantity,
  });

  /// Batch ID (`ma_lo`).
  final String id;

  /// Food ID (`ma_thuc_pham`).
  final String foodId;

  /// Location ID (`ma_vi_tri`).
  final String locationId;

  /// Import date (`ngay_nhap`).
  final DateTime importDate;

  /// Expiration date (`han_su_dung`).
  final DateTime expiryDate;

  /// Remaining usable quantity in base unit (`so_luong_ton` >= 0).
  final double availableQuantity;

  bool isUsable(DateTime referenceDate) {
    final refMidnight = Meal.normalizeLocalDate(referenceDate);
    final expMidnight = Meal.normalizeLocalDate(expiryDate);
    return !expMidnight.isBefore(refMidnight) && availableQuantity > 0;
  }
}

/// Represents how much quantity is taken from a specific batch under FEFO.
class BatchAllocation {
  const BatchAllocation({
    required this.batch,
    required this.quantityToDeduct,
  });

  final PantryBatchInfo batch;
  final double quantityToDeduct;
}

/// FEFO calculation result for a single food item in [ConsumptionRequest].
class FoodDeductionPlan {
  const FoodDeductionPlan({
    required this.foodId,
    required this.foodName,
    required this.baseUnitSymbol,
    required this.requiredQuantity,
    required this.totalAvailableQuantity,
    required this.allocations,
  });

  final String foodId;
  final String foodName;
  final String baseUnitSymbol;
  final double requiredQuantity;
  final double totalAvailableQuantity;
  final List<BatchAllocation> allocations;

  bool get isSufficient => totalAvailableQuantity >= requiredQuantity;
  double get shortage => isSufficient ? 0.0 : (requiredQuantity - totalAvailableQuantity);
}

/// Complete FEFO preview before atomic execution.
class MealCompletionPreview {
  const MealCompletionPreview({
    required this.mealId,
    required this.plans,
  });

  final String mealId;
  final List<FoodDeductionPlan> plans;

  bool get isAllSufficient => plans.every((p) => p.isSufficient);

  List<FoodDeductionPlan> get shortages =>
      plans.where((p) => !p.isSufficient).toList();
}

/// Thrown when at least one ingredient lacks sufficient stock for all-or-nothing completion (TC-09).
class InsufficientStockException extends MealPlanException {
  InsufficientStockException(this.shortages)
      : super(
          'Không đủ tồn kho khả dụng để hoàn thành bữa ăn: '
          '${shortages.map((s) => "${s.foodName} (thiếu ${s.shortage.toStringAsFixed(2)} ${s.baseUnitSymbol})").join(", ")}. '
          'Hệ thống hủy toàn bộ giao dịch, không trừ bất kỳ nguyên liệu nào.',
        );

  final List<FoodDeductionPlan> shortages;
}

/// Contract for accessing pantry batches (`lo_thuc_pham`, MOD-01).
abstract interface class PantryBatchReader {
  Future<List<PantryBatchInfo>> getUsableBatchesForFood({
    required String userId,
    required String foodId,
    required DateTime referenceDate,
  });
}

/// Default Firestore implementation reading `/users/{uid}/lo_thuc_pham`.
class FirestorePantryBatchReader implements PantryBatchReader {
  FirestorePantryBatchReader({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<PantryBatchInfo>> getUsableBatchesForFood({
    required String userId,
    required String foodId,
    required DateTime referenceDate,
  }) async {
    final refDateKey = Meal.formatLocalDate(referenceDate);
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('lo_thuc_pham')
        .where('ma_thuc_pham', isEqualTo: foodId)
        .get();

    final batches = <PantryBatchInfo>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final expRaw = data['han_su_dung'];
      if (expRaw == null) continue;

      final expDate = Meal.parseLocalDate(expRaw);
      final expKey = Meal.formatLocalDate(expDate);
      if (expKey.compareTo(refDateKey) < 0) continue; // Expired

      // Compatible with both direct `so_luong_ton` or computed balance
      final qty = (data['so_luong_ton'] as num?)?.toDouble() ??
          ((data['so_luong_nhap'] as num?)?.toDouble() ?? 0.0) -
              ((data['so_luong_xuat'] as num?)?.toDouble() ?? 0.0);

      if (qty <= 0) continue;

      batches.add(
        PantryBatchInfo(
          id: doc.id,
          foodId: foodId,
          locationId: data['ma_vi_tri'] as String? ?? '',
          importDate: Meal.parseLocalDate(data['ngay_nhap'] ?? DateTime.now()),
          expiryDate: expDate,
          availableQuantity: qty,
        ),
      );
    }

    // FEFO: Sort by expiry date ASC (earliest expiry first, TC-11)
    batches.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return batches;
  }
}

/// Domain service implementing atomic meal completion and FEFO stock deduction (`MOD-04-08` / F8).
class StockDeductionService {
  StockDeductionService({
    required MealRepository mealRepository,
    PantryBatchReader? batchReader,
    FirebaseFirestore? firestore,
  })  : _mealRepository = mealRepository,
        _batchReader = batchReader ?? FirestorePantryBatchReader(firestore: firestore),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final MealRepository _mealRepository;
  final PantryBatchReader _batchReader;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _userRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('meals');
  }

  /// Calculates the FEFO deduction plan for UI preview without modifying the database.
  Future<MealCompletionPreview> previewPlan({
    required String userId,
    required ConsumptionRequest request,
  }) async {
    final today = Meal.normalizeLocalDate(DateTime.now());
    final plans = <FoodDeductionPlan>[];

    // Group items by foodId
    final groupedItems = <String, List<ConsumptionItem>>{};
    for (final item in request.items) {
      groupedItems.putIfAbsent(item.foodId, () => []).add(item);
    }

    for (final entry in groupedItems.entries) {
      final foodId = entry.key;
      final items = entry.value;
      final requiredQty = items.fold<double>(0.0, (acc, it) => acc + it.effectiveQuantity);
      final first = items.first;

      final batches = await _batchReader.getUsableBatchesForFood(
        userId: userId,
        foodId: foodId,
        referenceDate: today,
      );

      final totalAvailable =
          batches.fold<double>(0.0, (acc, b) => acc + b.availableQuantity);

      // Allocate FEFO
      final allocations = <BatchAllocation>[];
      var remainingToAllocate = requiredQty;

      for (final batch in batches) {
        if (remainingToAllocate <= 0) break;
        final take = batch.availableQuantity >= remainingToAllocate
            ? remainingToAllocate
            : batch.availableQuantity;
        allocations.add(BatchAllocation(batch: batch, quantityToDeduct: take));
        remainingToAllocate -= take;
      }

      plans.add(
        FoodDeductionPlan(
          foodId: foodId,
          foodName: first.foodName,
          baseUnitSymbol: first.baseUnitSymbol,
          requiredQuantity: requiredQty,
          totalAvailableQuantity: totalAvailable,
          allocations: allocations,
        ),
      );
    }

    return MealCompletionPreview(
      mealId: request.meal.id,
      plans: plans,
    );
  }

  /// Executes atomic meal completion and stock deduction in a single Firestore transaction (`MOD-04-08`).
  ///
  /// Guarantees:
  /// 1. Idempotency (TC-10): If meal already COMPLETED, safely returns without re-deducting.
  /// 2. All-or-nothing (TC-09): If ANY ingredient is insufficient, transaction aborts completely.
  /// 3. FEFO allocation (TC-11): Deducts from earliest-expiry batches first.
  /// 4. Stock movement audit trail (`bien_dong_kho` with `CONSUME` type, matching `schema.sql` on branch `mod4`).
  Future<Meal> completeMealAtomic({
    required String userId,
    required ConsumptionRequest request,
  }) async {
    final mealDocRef = _userRef(userId).doc(request.meal.id);
    final movementsRef =
        _firestore.collection('users').doc(userId).collection('bien_dong_kho');
    final batchesCollection =
        _firestore.collection('users').doc(userId).collection('lo_thuc_pham');

    return _firestore.runTransaction<Meal>((txn) async {
      // 1. Read meal status inside transaction (Idempotency guard - TC-10)
      final mealSnap = await txn.get(mealDocRef);
      if (!mealSnap.exists || mealSnap.data() == null) {
        throw const MealNotFoundException();
      }

      final currentMeal = Meal.fromMap(
        _normalizeMap(mealSnap.data()!),
        id: mealSnap.id,
      );

      if (currentMeal.isCompleted) {
        // Already completed on another device, idempotent return
        return currentMeal;
      }
      if (currentMeal.isCancelled) {
        throw const MealPlanException('Bữa ăn đã bị hủy, không thể hoàn thành.');
      }

      // 2. Read all needed batches inside transaction
      final preview = await previewPlan(userId: userId, request: request);

      // 3. Pre-condition check: All-or-nothing (TC-09)
      if (!preview.isAllSufficient) {
        throw InsufficientStockException(preview.shortages);
      }

      final now = DateTime.now();

      // 4. Execute writes in the atomic transaction
      for (final plan in preview.plans) {
        for (final alloc in plan.allocations) {
          final batchRef = batchesCollection.doc(alloc.batch.id);

          // Update remaining stock on batch
          final newBalance = alloc.batch.availableQuantity - alloc.quantityToDeduct;
          txn.update(batchRef, {
            'so_luong_ton': newBalance,
          });

          // Write stock movement log (`bien_dong_kho`) matching `schema.sql` on `mod4`:
          // loai_bien_dong = 'CONSUME', so_luong_nhap = 0, so_luong_xuat = alloc.quantityToDeduct
          final movementDoc = movementsRef.doc();
          txn.set(movementDoc, {
            'ma_lo': alloc.batch.id,
            'ma_chi_tiet_mua': null,
            'ma_mon_an': request.items.firstWhere((it) => it.foodId == plan.foodId).mealItemId,
            'loai_bien_dong': 'CONSUME',
            'so_luong_nhap': 0.0,
            'so_luong_xuat': alloc.quantityToDeduct,
            'thoi_diem': now.toIso8601String(),
            'ghi_chu': 'Tiêu thụ cho bữa ăn ${currentMeal.slot.labelVi} (${currentMeal.id})',
          });
        }
      }

      // 5. Mark meal as COMPLETED
      final completedMeal = currentMeal.copyWith(
        status: MealStatus.completed,
        completedAt: now,
      );

      txn.update(mealDocRef, {
        'trang_thai': MealStatus.completed.value,
        'hoan_thanh_luc': now.toIso8601String(),
      });

      return completedMeal;
    });
  }

  Map<String, Object?> _normalizeMap(Map<String, dynamic> raw) {
    return raw.map((key, value) {
      if (value is Timestamp) {
        return MapEntry(key, value.toDate());
      }
      return MapEntry(key, value);
    });
  }
}
