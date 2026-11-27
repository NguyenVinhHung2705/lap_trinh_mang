import 'package:supabase_flutter/supabase_flutter.dart';

import '../../pantry/data/pantry_mock_data.dart';
import '../data/meal_repository.dart';
import '../data/models/consumption_request.dart';
import '../data/models/meal.dart';

/// Single pantry batch candidate for FEFO allocation (`lo_thuc_pham`, owned by MOD-01).
class PantryBatchInfo {
  const PantryBatchInfo({
    required this.id,
    required this.foodId,
    required this.locationId,
    required this.importDate,
    required this.expiryDate,
    required this.availableQuantity,
  });

  final String id;
  final String foodId;
  final String locationId;
  final DateTime importDate;
  final DateTime expiryDate;

  /// Remaining usable quantity in base unit (>= 0).
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
  double get shortage =>
      isSufficient ? 0.0 : (requiredQuantity - totalAvailableQuantity);
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

/// Thrown when at least one ingredient lacks sufficient stock (all-or-nothing, TC-09).
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

/// Supabase implementation reading `lo_thuc_pham` (shared schema in `SPRINT_FINAL.md`).
class SupabasePantryBatchReader implements PantryBatchReader {
  SupabasePantryBatchReader({SupabaseClient? supabase})
      : _customSupabase = supabase;

  final SupabaseClient? _customSupabase;
  SupabaseClient get _db => _customSupabase ?? Supabase.instance.client;

  /// Batches without expiry date are usable and sorted last.
  static final DateTime _noExpiry = DateTime(9999, 12, 31);

  @override
  Future<List<PantryBatchInfo>> getUsableBatchesForFood({
    required String userId,
    required String foodId,
    required DateTime referenceDate,
  }) async {
    final refDateKey = Meal.formatLocalDate(referenceDate);

    if (userId.isEmpty ||
        userId.startsWith('mock_') ||
        userId.startsWith('guest_')) {
      return _getMemoryBatches(foodId, refDateKey);
    }

    try {
      final rows = await _db
          .from('lo_thuc_pham')
          .select()
          .eq('user_id', userId)
          .eq('thuc_pham_id', foodId)
          .gt('so_luong', 0);

      final batches = <PantryBatchInfo>[];
      for (final r in rows) {
        final expRaw = r['ngay_het_han'];
        final expDate =
            expRaw == null ? _noExpiry : Meal.parseLocalDate(expRaw as Object);
        if (Meal.formatLocalDate(expDate).compareTo(refDateKey) < 0) {
          continue; // expired → never deducted
        }
        final createdRaw = r['created_at'];
        batches.add(
          PantryBatchInfo(
            id: r['id'].toString(),
            foodId: foodId,
            locationId: r['vi_tri'] as String? ?? '',
            importDate: createdRaw is String
                ? DateTime.parse(createdRaw).toLocal()
                : DateTime.now(),
            expiryDate: expDate,
            availableQuantity: (r['so_luong'] as num?)?.toDouble() ?? 0,
          ),
        );
      }

      // FEFO: earliest expiry first, then oldest import (TC-11).
      batches.sort((a, b) {
        final byExpiry = a.expiryDate.compareTo(b.expiryDate);
        return byExpiry != 0 ? byExpiry : a.importDate.compareTo(b.importDate);
      });
      return batches;
    } catch (_) {
      return const [];
    }
  }

  List<PantryBatchInfo> _getMemoryBatches(String foodId, String refDateKey) {
    final memoryBatches = <PantryBatchInfo>[];
    for (final b in PantryMockData.initialBatches) {
      if (b.foodId == foodId ||
          foodId.contains(b.foodId) ||
          b.foodId.contains(foodId)) {
        final expKey = Meal.formatLocalDate(b.expiryDate);
        if (expKey.compareTo(refDateKey) < 0) continue;
        if (b.quantity <= 0) continue;
        memoryBatches.add(
          PantryBatchInfo(
            id: b.id,
            foodId: foodId,
            locationId: b.locationName,
            importDate: b.importDate,
            expiryDate: b.expiryDate,
            availableQuantity: b.quantity,
          ),
        );
      }
    }
    memoryBatches.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return memoryBatches;
  }
}

/// Atomic meal completion + FEFO stock deduction (MOD-04-08 / F8).
class StockDeductionService {
  StockDeductionService({
    required MealRepository mealRepository,
    PantryBatchReader? batchReader,
    SupabaseClient? supabase,
  })  : _mealRepository = mealRepository,
        _batchReader =
            batchReader ?? SupabasePantryBatchReader(supabase: supabase),
        _customSupabase = supabase;

  final MealRepository _mealRepository;
  final PantryBatchReader _batchReader;
  final SupabaseClient? _customSupabase;
  SupabaseClient get _db => _customSupabase ?? Supabase.instance.client;

  /// Name of the PostgreSQL function in `supabase/mod04_meal_plan.sql`.
  static const String completeMealRpc = 'complete_meal_fefo';

  /// Calculates the FEFO deduction plan for UI preview without modifying the database.
  Future<MealCompletionPreview> previewPlan({
    required String userId,
    required ConsumptionRequest request,
  }) async {
    final today = Meal.normalizeLocalDate(DateTime.now());
    final plans = <FoodDeductionPlan>[];

    final groupedItems = <String, List<ConsumptionItem>>{};
    for (final item in request.items) {
      if (item.effectiveQuantity <= 0) continue;
      groupedItems.putIfAbsent(item.foodId, () => []).add(item);
    }

    for (final entry in groupedItems.entries) {
      final foodId = entry.key;
      final items = entry.value;
      final requiredQty =
          items.fold<double>(0.0, (acc, it) => acc + it.effectiveQuantity);
      final first = items.first;

      final batches = await _batchReader.getUsableBatchesForFood(
        userId: userId,
        foodId: foodId,
        referenceDate: today,
      );

      final totalAvailable =
          batches.fold<double>(0.0, (acc, b) => acc + b.availableQuantity);

      final allocations = <BatchAllocation>[];
      var remaining = requiredQty;
      for (final batch in batches) {
        if (remaining <= 0) break;
        final take = batch.availableQuantity >= remaining
            ? remaining
            : batch.availableQuantity;
        allocations.add(BatchAllocation(batch: batch, quantityToDeduct: take));
        remaining -= take;
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

    return MealCompletionPreview(mealId: request.meal.id, plans: plans);
  }

  /// Completes a meal and deducts stock atomically (MOD-04-08).
  ///
  /// Guarantees (enforced inside PostgreSQL function `complete_meal_fefo`):
  /// 1. Idempotency (TC-10): already COMPLETED → returns without re-deducting.
  /// 2. All-or-nothing (TC-09): any shortage → `RAISE EXCEPTION` → full rollback.
  /// 3. FEFO (TC-11): earliest-expiry batches deducted first (`FOR UPDATE` row locks).
  /// 4. Audit trail: `bien_dong_kho` rows with `loai_bien_dong = 'CONSUME'`,
  ///    `so_luong_nhap = 0`, `so_luong_xuat = deducted amount`.
  Future<Meal> completeMealAtomic({
    required String userId,
    required ConsumptionRequest request,
  }) async {
    final currentMeal = await _mealRepository.getMealById(
      userId: userId,
      mealId: request.meal.id,
    );
    if (currentMeal == null) throw const MealNotFoundException();
    if (currentMeal.isCompleted) return currentMeal; // idempotent (TC-10)
    if (currentMeal.isCancelled) {
      throw const MealPlanException('Bữa ăn đã bị hủy, không thể hoàn thành.');
    }

    // Guest/offline mode: no real stock to deduct.
    if (userId.isEmpty ||
        userId.startsWith('mock_') ||
        userId.startsWith('guest_')) {
      return _mealRepository.markMealCompleted(
        userId: userId,
        mealId: currentMeal.id,
        completedAt: DateTime.now(),
      );
    }

    // Fast fail with a friendly shortage message before hitting the database.
    final preview = await previewPlan(userId: userId, request: request);
    if (!preview.isAllSufficient) {
      throw InsufficientStockException(preview.shortages);
    }

    final payload = <Map<String, Object?>>[];
    for (final plan in preview.plans) {
      final firstItem =
          request.items.firstWhere((it) => it.foodId == plan.foodId);
      payload.add({
        'food_id': plan.foodId,
        'food_name': plan.foodName,
        'meal_item_id': firstItem.mealItemId,
        'qty': plan.requiredQuantity,
      });
    }

    try {
      await _db.rpc(completeMealRpc, params: {
        'p_user_id': userId,
        'p_meal_id': MealRepository.rowMealId(userId, currentMeal.id),
        'p_items': payload,
        'p_today': Meal.formatLocalDate(DateTime.now()),
      });
    } on PostgrestException catch (e) {
      if (e.message.contains('INSUFFICIENT_STOCK')) {
        // Stock changed between preview and commit → re-read and report.
        final fresh = await previewPlan(userId: userId, request: request);
        throw InsufficientStockException(
          fresh.shortages.isNotEmpty ? fresh.shortages : preview.plans,
        );
      }
      if (e.message.contains('MEAL_CANCELLED')) {
        throw const MealPlanException('Bữa ăn đã bị hủy, không thể hoàn thành.');
      }
      if (e.message.contains('MEAL_NOT_FOUND')) {
        throw const MealNotFoundException();
      }
      if (e.code == 'PGRST202' || e.code == '42883') {
        throw const MealPlanException(
          'Chưa cài hàm complete_meal_fefo trên Supabase. '
          'Hãy chạy file supabase/mod04_meal_plan.sql trong SQL Editor.',
        );
      }
      throw MealPlanException('Lỗi hoàn thành bữa ăn: ${e.message}');
    }

    final updated = await _mealRepository.getMealById(
      userId: userId,
      mealId: currentMeal.id,
    );
    return updated ??
        currentMeal.copyWith(
          status: MealStatus.completed,
          completedAt: DateTime.now(),
        );
  }
}
