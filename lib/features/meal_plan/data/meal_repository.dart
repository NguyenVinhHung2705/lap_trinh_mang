import 'package:supabase_flutter/supabase_flutter.dart';

import 'meal_mock_data.dart';
import 'models/meal.dart';
import 'models/meal_item.dart';

/// Base exception for meal planning repository operations.
class MealPlanException implements Exception {
  const MealPlanException(this.message);

  final String message;

  @override
  String toString() => 'MealPlanException: $message';
}

/// Thrown when attempting to mutate or cancel a meal that is already completed.
class MealAlreadyCompletedException extends MealPlanException {
  const MealAlreadyCompletedException([
    super.message = 'Không thể chỉnh sửa hoặc hủy bữa ăn đã hoàn thành.',
  ]);
}

/// Thrown when a requested meal or meal item does not exist.
class MealNotFoundException extends MealPlanException {
  const MealNotFoundException([
    super.message = 'Không tìm thấy bữa ăn hoặc món ăn kế hoạch.',
  ]);
}

/// Thrown when moving a meal onto a date/slot that already has an active meal.
class MealSlotConflictException extends MealPlanException {
  const MealSlotConflictException([
    super.message = 'Khung bữa ăn ở ngày đích đã tồn tại kế hoạch khác.',
  ]);
}

/// Supabase (PostgreSQL) data access layer for MOD-04.
///
/// Tables (see `SPRINT_FINAL.md` + `supabase/mod04_meal_plan.sql`):
/// - `meals`      (id, user_id, ngay_an, buoi, trang_thai, gio_nhac, hoan_thanh_luc)
/// - `meal_items` (id, meal_id, loai, tham_chieu_id, ten, so_luong, don_vi_id)
///
/// The app-level [Meal.id] stays `YYYY-MM-DD_SLOT`; the database row id is
/// `{userId}_{Meal.id}` so that the primary key is unique across users.
class MealRepository {
  MealRepository({SupabaseClient? supabase}) : _customSupabase = supabase;

  final SupabaseClient? _customSupabase;
  SupabaseClient get _db => _customSupabase ?? Supabase.instance.client;

  static const String mealsTable = 'meals';
  static const String itemsTable = 'meal_items';

  // In-memory fallback / mock store for offline & guest usage.
  static final List<Meal> _memoryMeals =
      List<Meal>.from(MealPlanMockData.initialMeals);
  static final Map<String, List<MealItem>> _memoryMealItems =
      MealPlanMockData.initialMealItems
          .map((k, v) => MapEntry(k, List<MealItem>.from(v)));

  bool _isMockUser(String userId) {
    return userId.isEmpty ||
        userId.startsWith('mock_') ||
        userId.startsWith('guest_');
  }

  // ---------------------------------------------------------------------------
  // Row <-> model mapping (public so other MOD-04 services reuse it)
  // ---------------------------------------------------------------------------

  /// Database primary key of a meal row.
  static String rowMealId(String userId, String mealId) => '${userId}_$mealId';

  /// Converts a database row id back to the app-level meal id.
  static String appMealId(String userId, String rowId) {
    final prefix = '${userId}_';
    return rowId.startsWith(prefix) ? rowId.substring(prefix.length) : rowId;
  }

  static Map<String, Object?> mealToRow(Meal meal) {
    return {
      'id': rowMealId(meal.userId, meal.id),
      'user_id': meal.userId,
      'ngay_an': Meal.formatLocalDate(meal.mealDate),
      'buoi': meal.slot.value,
      'trang_thai': meal.status.value,
      'gio_nhac': meal.reminderAt?.toUtc().toIso8601String(),
      'hoan_thanh_luc': meal.completedAt?.toUtc().toIso8601String(),
    };
  }

  static Meal mealFromRow(Map<String, dynamic> row) {
    final userId = row['user_id'] as String;
    return Meal.fromMap(
      {
        'ma_tai_khoan': userId,
        'ngay_an': row['ngay_an'],
        'khung_bua': row['buoi'],
        'trang_thai': row['trang_thai'],
        'gio_nhac': _toLocal(row['gio_nhac']),
        'hoan_thanh_luc': _toLocal(row['hoan_thanh_luc']),
      },
      id: appMealId(userId, row['id'] as String),
    );
  }

  static Map<String, Object?> itemToRow(String userId, MealItem item) {
    return {
      'id': item.id,
      'meal_id': rowMealId(userId, item.mealId),
      'loai': item.isRecipe ? 'RECIPE' : 'FOOD',
      'tham_chieu_id': item.isRecipe ? item.recipeId : item.foodId,
      // `ten` is NOT NULL in the shared schema; UI resolves display names itself.
      'ten': (item.isRecipe ? item.recipeId : item.foodId) ?? 'Món ăn',
      'so_luong': item.quantity,
      'don_vi_id': item.unitId,
    };
  }

  static MealItem itemFromRow(String userId, Map<String, dynamic> row) {
    final isRecipe = (row['loai'] as String?)?.toUpperCase() == 'RECIPE';
    final refId = row['tham_chieu_id'] as String?;
    return MealItem.fromMap(
      {
        'ma_bua_an': appMealId(userId, row['meal_id'] as String),
        'ma_cong_thuc': isRecipe ? refId : null,
        'ma_thuc_pham': isRecipe ? null : refId,
        'ma_don_vi': isRecipe ? null : row['don_vi_id'],
        'so_luong': (row['so_luong'] as num?) ?? 1,
      },
      id: row['id'] as String,
    );
  }

  static DateTime? _toLocal(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toLocal();
    if (raw is String) return DateTime.parse(raw).toLocal();
    return null;
  }

  // ---------------------------------------------------------------------------
  // READ
  // ---------------------------------------------------------------------------

  /// Queries meals for [userId] within [startDate]..[endDate] (inclusive).
  Future<List<Meal>> getMealsInRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    bool includeCancelled = false,
  }) async {
    if (_isMockUser(userId)) {
      return _filterMemoryMeals(startDate, endDate, includeCancelled);
    }

    try {
      final rows = await _db
          .from(mealsTable)
          .select()
          .eq('user_id', userId)
          .gte('ngay_an', Meal.formatLocalDate(startDate))
          .lte('ngay_an', Meal.formatLocalDate(endDate))
          .order('ngay_an');

      final meals = rows.map<Meal>(mealFromRow).toList();
      return includeCancelled
          ? meals
          : meals.where((m) => !m.isCancelled).toList();
    } catch (_) {
      return _filterMemoryMeals(startDate, endDate, includeCancelled);
    }
  }

  /// Streams meals for [userId] within [startDate]..[endDate] (Supabase Realtime).
  Stream<List<Meal>> watchMealsInRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    bool includeCancelled = false,
  }) {
    if (_isMockUser(userId)) {
      return Stream.value(
          _filterMemoryMeals(startDate, endDate, includeCancelled));
    }

    final startKey = Meal.formatLocalDate(startDate);
    final endKey = Meal.formatLocalDate(endDate);

    return _db
        .from(mealsTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) {
          final meals = rows
              .where((r) {
                final key = (r['ngay_an'] as String? ?? '');
                return key.compareTo(startKey) >= 0 &&
                    key.compareTo(endKey) <= 0;
              })
              .map<Meal>(mealFromRow)
              .toList()
            ..sort((a, b) => a.mealDate.compareTo(b.mealDate));
          return includeCancelled
              ? meals
              : meals.where((m) => !m.isCancelled).toList();
        })
        .handleError((_) => <Meal>[]);
  }

  List<Meal> _filterMemoryMeals(
      DateTime startDate, DateTime endDate, bool includeCancelled) {
    final startKey = Meal.formatLocalDate(startDate);
    final endKey = Meal.formatLocalDate(endDate);

    return _memoryMeals.where((m) {
      if (!includeCancelled && m.isCancelled) return false;
      final mealKey = Meal.formatLocalDate(m.mealDate);
      return mealKey.compareTo(startKey) >= 0 &&
          mealKey.compareTo(endKey) <= 0;
    }).toList();
  }

  Meal? _memoryMeal(String mealId) => _memoryMeals
      .cast<Meal?>()
      .firstWhere((m) => m?.id == mealId, orElse: () => null);

  Future<Meal?> _fetchMeal(String userId, String mealId) async {
    final row = await _db
        .from(mealsTable)
        .select()
        .eq('id', rowMealId(userId, mealId))
        .maybeSingle();
    return row == null ? null : mealFromRow(row);
  }

  /// Fetches a single meal by [mealId], or returns `null` if not found.
  Future<Meal?> getMealById({
    required String userId,
    required String mealId,
  }) async {
    if (_isMockUser(userId)) return _memoryMeal(mealId);

    try {
      return await _fetchMeal(userId, mealId) ?? _memoryMeal(mealId);
    } catch (_) {
      return _memoryMeal(mealId);
    }
  }

  /// Finds the meal for `(userId, date, slot)` or creates a new PLANNED one (MOD-04-02).
  Future<Meal> getOrCreateMeal({
    required String userId,
    required DateTime date,
    required MealSlot slot,
  }) async {
    final normalizedDate = Meal.normalizeLocalDate(date);
    final mealId = Meal.buildDeterministicId(normalizedDate, slot);

    if (_isMockUser(userId)) {
      return _memoryGetOrCreate(userId, mealId, normalizedDate, slot);
    }

    try {
      final existing = await _fetchMeal(userId, mealId);
      if (existing != null && !existing.isCancelled) return existing;

      final newMeal = Meal(
        id: mealId,
        userId: userId,
        mealDate: normalizedDate,
        slot: slot,
        status: MealStatus.planned,
      );
      await _db.from(mealsTable).upsert(mealToRow(newMeal));
      return newMeal;
    } catch (_) {
      return _memoryGetOrCreate(userId, mealId, normalizedDate, slot);
    }
  }

  Meal _memoryGetOrCreate(
      String userId, String mealId, DateTime normalizedDate, MealSlot slot) {
    final existingIdx = _memoryMeals.indexWhere((m) => m.id == mealId);
    if (existingIdx != -1 && !_memoryMeals[existingIdx].isCancelled) {
      return _memoryMeals[existingIdx];
    }
    final newMeal = Meal(
      id: mealId,
      userId: userId,
      mealDate: normalizedDate,
      slot: slot,
      status: MealStatus.planned,
    );
    if (existingIdx != -1) {
      _memoryMeals[existingIdx] = newMeal;
    } else {
      _memoryMeals.add(newMeal);
    }
    return newMeal;
  }

  /// Reads all items in a meal (`meal_items`).
  Future<List<MealItem>> getMealItems({
    required String userId,
    required String mealId,
  }) async {
    final memoryItems = _memoryMealItems[mealId] ?? const <MealItem>[];
    if (_isMockUser(userId)) return memoryItems;

    try {
      final rows = await _db
          .from(itemsTable)
          .select()
          .eq('meal_id', rowMealId(userId, mealId))
          .order('created_at');
      return rows.map<MealItem>((r) => itemFromRow(userId, r)).toList();
    } catch (_) {
      return memoryItems;
    }
  }

  /// Streams items belonging to [mealId] (Supabase Realtime).
  Stream<List<MealItem>> watchMealItems({
    required String userId,
    required String mealId,
  }) {
    final memoryItems = _memoryMealItems[mealId] ?? const <MealItem>[];
    if (_isMockUser(userId)) return Stream.value(memoryItems);

    return _db
        .from(itemsTable)
        .stream(primaryKey: ['id'])
        .eq('meal_id', rowMealId(userId, mealId))
        .map((rows) =>
            rows.map<MealItem>((r) => itemFromRow(userId, r)).toList())
        .handleError((_) => memoryItems);
  }

  // ---------------------------------------------------------------------------
  // WRITE — none of these touch pantry stock (business invariant).
  // ---------------------------------------------------------------------------

  /// Ensures [mealId] exists and is PLANNED; throws domain exceptions otherwise.
  Future<Meal> _requirePlannedMeal(String userId, String mealId) async {
    final meal = await _fetchMeal(userId, mealId);
    if (meal == null) throw const MealNotFoundException();
    if (meal.isCompleted) throw const MealAlreadyCompletedException();
    if (meal.isCancelled) {
      throw const MealPlanException('Bữa ăn đã bị hủy, không thể thao tác.');
    }
    return meal;
  }

  /// Adds a recipe or standalone food item to a PLANNED meal (MOD-04-03, MOD-04-04).
  Future<MealItem> addMealItem({
    required String userId,
    required MealItem item,
  }) async {
    final itemId = item.id == 'new' || item.id.isEmpty
        ? 'item_${DateTime.now().microsecondsSinceEpoch}'
        : item.id;
    final persistedItem = item.copyWith(id: itemId);

    if (_isMockUser(userId)) {
      _memoryMealItems.putIfAbsent(item.mealId, () => []).add(persistedItem);
      return persistedItem;
    }

    try {
      final existing = await _fetchMeal(userId, item.mealId);
      if (existing == null) {
        // Meal was created in memory earlier (offline) → persist it first.
        final memMeal = _memoryMeal(item.mealId);
        if (memMeal == null) throw const MealNotFoundException();
        await _db.from(mealsTable).upsert(mealToRow(memMeal));
      } else if (existing.isCompleted) {
        throw const MealAlreadyCompletedException();
      } else if (existing.isCancelled) {
        throw const MealPlanException('Bữa ăn đã bị hủy, không thể thêm món.');
      }

      await _db.from(itemsTable).insert(itemToRow(userId, persistedItem));
    } on MealPlanException {
      rethrow;
    } catch (_) {
      // Network/DB error → keep the item locally so the demo keeps working.
      _memoryMealItems.putIfAbsent(item.mealId, () => []).add(persistedItem);
    }
    return persistedItem;
  }

  /// Updates quantity/servings of an item in a PLANNED meal (MOD-04-05).
  Future<void> updateMealItemQuantity({
    required String userId,
    required String mealId,
    required String itemId,
    required double quantity,
  }) async {
    if (quantity <= 0 || quantity.isNaN || quantity.isInfinite) {
      throw ArgumentError.value(quantity, 'quantity', 'Quantity must be > 0');
    }

    final items = _memoryMealItems[mealId];
    final idx = items?.indexWhere((i) => i.id == itemId) ?? -1;
    if (idx != -1) items![idx] = items[idx].copyWith(quantity: quantity);

    if (_isMockUser(userId)) return;

    try {
      await _requirePlannedMeal(userId, mealId);
      await _db
          .from(itemsTable)
          .update({'so_luong': quantity}).eq('id', itemId);
    } on MealPlanException {
      rethrow;
    } catch (_) {
      return;
    }
  }

  /// Removes a single item from a PLANNED meal (MOD-04-05).
  Future<void> removeMealItem({
    required String userId,
    required String mealId,
    required String itemId,
  }) async {
    _memoryMealItems[mealId]?.removeWhere((i) => i.id == itemId);

    if (_isMockUser(userId)) return;

    try {
      await _requirePlannedMeal(userId, mealId);
      await _db.from(itemsTable).delete().eq('id', itemId);
    } on MealPlanException {
      rethrow;
    } catch (_) {
      return;
    }
  }

  /// Moves a PLANNED meal and its items to a new `(newDate, newSlot)` (MOD-04-05).
  Future<Meal> rescheduleMeal({
    required String userId,
    required String mealId,
    required DateTime newDate,
    required MealSlot newSlot,
  }) async {
    final normalizedDate = Meal.normalizeLocalDate(newDate);
    final targetId = Meal.buildDeterministicId(normalizedDate, newSlot);
    if (targetId == mealId) {
      final current = await getMealById(userId: userId, mealId: mealId);
      if (current == null) throw const MealNotFoundException();
      return current;
    }

    if (_isMockUser(userId)) {
      final sIdx = _memoryMeals.indexWhere((m) => m.id == mealId);
      if (sIdx == -1) throw const MealNotFoundException();
      final movedMeal = _memoryMeals[sIdx]
          .copyWith(id: targetId, mealDate: normalizedDate, slot: newSlot);
      _memoryMeals[sIdx] = movedMeal;
      final items = _memoryMealItems.remove(mealId) ?? [];
      _memoryMealItems[targetId] =
          items.map((i) => i.copyWith(mealId: targetId)).toList();
      return movedMeal;
    }

    final sourceMeal = await _requirePlannedMeal(userId, mealId);
    final targetMeal = await _fetchMeal(userId, targetId);
    if (targetMeal != null && !targetMeal.isCancelled) {
      throw const MealSlotConflictException();
    }

    final movedMeal = sourceMeal.copyWith(
        id: targetId, mealDate: normalizedDate, slot: newSlot);

    // 1. Create/overwrite target meal row.
    await _db.from(mealsTable).upsert(mealToRow(movedMeal));
    // 2. Remove old items of a cancelled target (if any), then re-point items.
    await _db
        .from(itemsTable)
        .delete()
        .eq('meal_id', rowMealId(userId, targetId));
    await _db
        .from(itemsTable)
        .update({'meal_id': rowMealId(userId, targetId)}).eq(
            'meal_id', rowMealId(userId, mealId));
    // 3. Delete source meal row.
    await _db.from(mealsTable).delete().eq('id', rowMealId(userId, mealId));

    return movedMeal;
  }

  /// Marks a PLANNED meal as CANCELLED (MOD-04-05). Does not affect stock.
  Future<void> cancelMeal({
    required String userId,
    required String mealId,
  }) async {
    final idx = _memoryMeals.indexWhere((m) => m.id == mealId);
    if (idx != -1 && _memoryMeals[idx].isPlanned) {
      _memoryMeals[idx] =
          _memoryMeals[idx].copyWith(status: MealStatus.cancelled);
    }

    if (_isMockUser(userId)) return;

    await _requirePlannedMeal(userId, mealId);
    await _db.from(mealsTable).update({
      'trang_thai': MealStatus.cancelled.value,
      'gio_nhac': null,
    }).eq('id', rowMealId(userId, mealId));
  }

  /// Marks a meal as completed (used for guest/offline mode).
  ///
  /// For real users, completion + FEFO deduction happens atomically inside the
  /// PostgreSQL function `complete_meal_fefo` (see [StockDeductionService]).
  Future<Meal> markMealCompleted({
    required String userId,
    required String mealId,
    required DateTime completedAt,
  }) async {
    final idx = _memoryMeals.indexWhere((m) => m.id == mealId);
    if (idx != -1) {
      _memoryMeals[idx] = _memoryMeals[idx].copyWith(
        status: MealStatus.completed,
        completedAt: completedAt,
      );
      if (_isMockUser(userId)) return _memoryMeals[idx];
    }

    await _db.from(mealsTable).update({
      'trang_thai': MealStatus.completed.value,
      'hoan_thanh_luc': completedAt.toUtc().toIso8601String(),
    }).eq('id', rowMealId(userId, mealId));
    final updated = await _fetchMeal(userId, mealId);
    if (updated == null) throw const MealNotFoundException();
    return updated;
  }

  /// Sets or clears `gio_nhac` on a PLANNED meal (MOD-04-06).
  Future<void> updateMealReminder({
    required String userId,
    required String mealId,
    DateTime? reminderAt,
  }) async {
    final idx = _memoryMeals.indexWhere((m) => m.id == mealId);
    if (idx != -1) {
      _memoryMeals[idx] = reminderAt == null
          ? _memoryMeals[idx].copyWith(clearReminderAt: true)
          : _memoryMeals[idx].copyWith(reminderAt: reminderAt);
    }

    if (_isMockUser(userId)) return;

    try {
      await _db.from(mealsTable).update({
        'gio_nhac': reminderAt?.toUtc().toIso8601String(),
      }).eq('id', rowMealId(userId, mealId));
    } catch (_) {
      return;
    }
  }
}
