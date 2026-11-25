import 'package:cloud_firestore/cloud_firestore.dart';

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

/// Thrown when a requested meal or meal item document does not exist.
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

/// Firestore data access layer for `bua_an` and `mon_an_ke_hoach` (`MOD-04`).
///
/// Maps to:
/// - `/users/{uid}/meals/{mealId}`
/// - `/users/{uid}/meals/{mealId}/items/{itemId}`
class MealRepository {
  MealRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  // In-memory fallback / mock store for offline & guest usage
  static final List<Meal> _memoryMeals = List<Meal>.from(MealPlanMockData.initialMeals);
  static final Map<String, List<MealItem>> _memoryMealItems =
      MealPlanMockData.initialMealItems.map((k, v) => MapEntry(k, List<MealItem>.from(v)));

  bool _isMockUser(String userId) {
    return userId.isEmpty || userId.startsWith('mock_') || userId.startsWith('guest_');
  }

  CollectionReference<Map<String, dynamic>> _mealsRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('meals');
  }

  DocumentReference<Map<String, dynamic>> _mealDoc(String userId, String mealId) {
    return _mealsRef(userId).doc(mealId);
  }

  CollectionReference<Map<String, dynamic>> _itemsRef(
    String userId,
    String mealId,
  ) {
    return _mealDoc(userId, mealId).collection('items');
  }

  /// Queries meals for [userId] within [startDate]..[endDate] (local calendar dates, inclusive).
  ///
  /// Read-only (`MOD-04-01`). Excludes cancelled meals by default.
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
      final startKey = Meal.formatLocalDate(startDate);
      final endKey = Meal.formatLocalDate(endDate);

      final snapshot = await _mealsRef(userId)
          .where('ngay_an', isGreaterThanOrEqualTo: startKey)
          .where('ngay_an', isLessThanOrEqualTo: endKey)
          .orderBy('ngay_an')
          .get();

      if (snapshot.docs.isEmpty) {
        return const [];
      }
      return _mapMealSnapshot(snapshot, includeCancelled: includeCancelled);
    } catch (_) {
      return const [];
    }
  }

  /// Streams meals for [userId] within [startDate]..[endDate] for reactive calendar updates.
  Stream<List<Meal>> watchMealsInRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    bool includeCancelled = false,
  }) {
    if (_isMockUser(userId)) {
      return Stream.value(_filterMemoryMeals(startDate, endDate, includeCancelled));
    }

    final startKey = Meal.formatLocalDate(startDate);
    final endKey = Meal.formatLocalDate(endDate);

    return _mealsRef(userId)
        .where('ngay_an', isGreaterThanOrEqualTo: startKey)
        .where('ngay_an', isLessThanOrEqualTo: endKey)
        .orderBy('ngay_an')
        .snapshots()
        .map(
          (snapshot) {
            return _mapMealSnapshot(snapshot, includeCancelled: includeCancelled);
          },
        )
        .handleError((_) => const <Meal>[]);
  }

  List<Meal> _filterMemoryMeals(DateTime startDate, DateTime endDate, bool includeCancelled) {
    final startKey = Meal.formatLocalDate(startDate);
    final endKey = Meal.formatLocalDate(endDate);

    return _memoryMeals.where((m) {
      if (!includeCancelled && m.isCancelled) return false;
      final mealKey = Meal.formatLocalDate(m.mealDate);
      return mealKey.compareTo(startKey) >= 0 && mealKey.compareTo(endKey) <= 0;
    }).toList();
  }

  /// Fetches a single meal by [mealId], or returns `null` if not found.
  Future<Meal?> getMealById({
    required String userId,
    required String mealId,
  }) async {
    final memoryMeal = _memoryMeals.cast<Meal?>().firstWhere(
          (m) => m?.id == mealId,
          orElse: () => null,
        );

    if (_isMockUser(userId)) return memoryMeal;

    try {
      final doc = await _mealDoc(userId, mealId).get();
      if (!doc.exists || doc.data() == null) return null;
      return _mealFromDoc(doc);
    } catch (_) {
      return null;
    }
  }

  /// Finds the meal for `(userId, date, slot)` or creates a new `PLANNED` one (`MOD-04-02`).
  Future<Meal> getOrCreateMeal({
    required String userId,
    required DateTime date,
    required MealSlot slot,
  }) async {
    final normalizedDate = Meal.normalizeLocalDate(date);
    final docId = Meal.buildDeterministicId(normalizedDate, slot);

    if (_isMockUser(userId)) {
      final existingIdx = _memoryMeals.indexWhere((m) => m.id == docId);
      if (existingIdx != -1) {
        final existing = _memoryMeals[existingIdx];
        if (!existing.isCancelled) return existing;
      }
      final newMeal = Meal(
        id: docId,
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

    final docRef = _mealDoc(userId, docId);

    // Helper tạo in-memory meal khi Firestore chưa có dữ liệu
    Meal _buildLocalMeal() {
      final m = Meal(
        id: docId,
        userId: userId,
        mealDate: normalizedDate,
        slot: slot,
        status: MealStatus.planned,
      );
      final idx = _memoryMeals.indexWhere((x) => x.id == docId);
      if (idx != -1) {
        _memoryMeals[idx] = m;
      } else {
        _memoryMeals.add(m);
      }
      return m;
    }

    try {
      return await _firestore.runTransaction((txn) async {
        final snap = await txn.get(docRef);
        if (snap.exists && snap.data() != null) {
          final existing = _mealFromDoc(snap);
          if (!existing.isCancelled) return existing;
        }

        final newMeal = Meal(
          id: docId,
          userId: userId,
          mealDate: normalizedDate,
          slot: slot,
          status: MealStatus.planned,
        );
        txn.set(docRef, newMeal.toMap());
        return newMeal;
      });
    } on FirebaseException catch (e) {
      // Firestore chưa được cấu hình Rules hoặc đang offline
      // → fallback sang in-memory để demo vẫn chạy được
      if (e.code == 'not-found' ||
          e.code == 'permission-denied' ||
          e.code == 'unavailable') {
        return _buildLocalMeal();
      }
      rethrow;
    } catch (_) {
      return _buildLocalMeal();
    }
  }

  /// Reads all items in a meal (`mon_an_ke_hoach`).
  Future<List<MealItem>> getMealItems({
    required String userId,
    required String mealId,
  }) async {
    final memoryItems = _memoryMealItems[mealId] ?? const [];
    if (_isMockUser(userId)) return memoryItems;

    try {
      final snapshot = await _itemsRef(userId, mealId).get();
      if (snapshot.docs.isEmpty) return memoryItems;
      return snapshot.docs
          .map((doc) => MealItem.fromMap(_normalizeMap(doc.data()), id: doc.id))
          .toList();
    } catch (_) {
      return memoryItems;
    }
  }

  /// Streams items belonging to [mealId] in real time.
  Stream<List<MealItem>> watchMealItems({
    required String userId,
    required String mealId,
  }) {
    final memoryItems = _memoryMealItems[mealId] ?? const [];
    if (_isMockUser(userId)) {
      return Stream.value(memoryItems);
    }

    return _itemsRef(userId, mealId).snapshots().map(
          (snapshot) {
            if (snapshot.docs.isEmpty) return memoryItems;
            return snapshot.docs
                .map(
                  (doc) => MealItem.fromMap(_normalizeMap(doc.data()), id: doc.id),
                )
                .toList();
          },
        ).handleError((_) => memoryItems);
  }

  /// Adds a recipe or standalone food item to a `PLANNED` meal (`MOD-04-03`, `MOD-04-04`).
  Future<MealItem> addMealItem({
    required String userId,
    required MealItem item,
  }) async {
    final itemId = item.id == 'new' || item.id.isEmpty
        ? 'item_${DateTime.now().microsecondsSinceEpoch}'
        : item.id;
    final persistedItem = item.copyWith(id: itemId);

    _memoryMealItems.putIfAbsent(item.mealId, () => []).add(persistedItem);

    if (_isMockUser(userId)) {
      return persistedItem;
    }

    final mealRef = _mealDoc(userId, item.mealId);
    final itemRef = _itemsRef(userId, item.mealId).doc(itemId);

    try {
      await _firestore.runTransaction((txn) async {
        final snap = await txn.get(mealRef);
        if (!snap.exists || snap.data() == null) {
          // Meal chưa được ghi lên Firestore (do fallback in-memory trước đó)
          // → tự tạo meal doc trong cùng transaction rồi mới add item
          final memMeal = _memoryMeals.cast<Meal?>().firstWhere(
                (m) => m?.id == item.mealId,
                orElse: () => null,
              );
          if (memMeal != null) {
            txn.set(mealRef, memMeal.toMap());
          } else {
            throw const MealNotFoundException();
          }
        } else {
          final existing = _mealFromDoc(snap);
          if (existing.isCompleted) throw const MealAlreadyCompletedException();
          if (existing.isCancelled) {
            throw const MealPlanException('Bữa ăn đã bị hủy, không thể thêm món.');
          }
        }
        txn.set(itemRef, persistedItem.toMap());
      });
    } on FirebaseException {
      // Firestore lỗi (Rules chưa deploy, offline...) → vẫn trả item in-memory
      return persistedItem;
    }

    return persistedItem;
  }

  /// Updates quantity/servings of an item in a `PLANNED` meal (`MOD-04-05`).
  Future<void> updateMealItemQuantity({
    required String userId,
    required String mealId,
    required String itemId,
    required double quantity,
  }) async {
    if (quantity <= 0 || quantity.isNaN || quantity.isInfinite) {
      throw ArgumentError.value(quantity, 'quantity', 'Quantity must be > 0');
    }

    final items = _memoryMealItems[mealId] ?? [];
    final idx = items.indexWhere((i) => i.id == itemId);
    if (idx != -1) {
      items[idx] = items[idx].copyWith(quantity: quantity);
    }

    if (_isMockUser(userId)) return;

    final mealRef = _mealDoc(userId, mealId);
    final itemRef = _itemsRef(userId, mealId).doc(itemId);

    try {
      await _firestore.runTransaction((txn) async {
        await _requirePlannedMealInTxn(txn, mealRef);
        final itemSnap = await txn.get(itemRef);
        if (!itemSnap.exists) return; // item chỉ có in-memory, bỏ qua
        txn.update(itemRef, {'so_luong': quantity});
      });
    } on FirebaseException {
      return; // Firestore lỗi → memory đã cập nhật, không throw
    }
  }

  /// Removes a single item from a `PLANNED` meal (`MOD-04-05`).
  Future<void> removeMealItem({
    required String userId,
    required String mealId,
    required String itemId,
  }) async {
    _memoryMealItems[mealId]?.removeWhere((i) => i.id == itemId);

    if (_isMockUser(userId)) return;

    final mealRef = _mealDoc(userId, mealId);
    final itemRef = _itemsRef(userId, mealId).doc(itemId);

    try {
      await _firestore.runTransaction((txn) async {
        await _requirePlannedMealInTxn(txn, mealRef);
        final itemSnap = await txn.get(itemRef);
        if (!itemSnap.exists) return; // item chỉ có in-memory, bỏ qua
        txn.delete(itemRef);
      });
    } on FirebaseException {
      return; // Firestore lỗi → memory đã xoá, không throw
    }
  }

  /// Moves a `PLANNED` meal and its items to a new `(newDate, newSlot)` (`MOD-04-05`).
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
      final source = _memoryMeals[sIdx];
      final movedMeal = source.copyWith(
        id: targetId,
        mealDate: normalizedDate,
        slot: newSlot,
      );
      _memoryMeals[sIdx] = movedMeal;
      final items = _memoryMealItems.remove(mealId) ?? [];
      _memoryMealItems[targetId] = items.map((i) => i.copyWith(mealId: targetId)).toList();
      return movedMeal;
    }

    final sourceRef = _mealDoc(userId, mealId);
    final targetRef = _mealDoc(userId, targetId);
    final existingItems = await getMealItems(userId: userId, mealId: mealId);

    return _firestore.runTransaction((txn) async {
      final sourceMeal = await _requirePlannedMealInTxn(txn, sourceRef);
      final targetSnap = await txn.get(targetRef);
      if (targetSnap.exists && targetSnap.data() != null) {
        final targetMeal = _mealFromDoc(targetSnap);
        if (!targetMeal.isCancelled) {
          throw const MealSlotConflictException();
        }
      }

      final movedMeal = sourceMeal.copyWith(
        id: targetId,
        mealDate: normalizedDate,
        slot: newSlot,
      );

      txn.set(targetRef, movedMeal.toMap());
      for (final item in existingItems) {
        final movedItem = item.copyWith(mealId: targetId);
        txn.set(_itemsRef(userId, targetId).doc(movedItem.id), movedItem.toMap());
        txn.delete(_itemsRef(userId, mealId).doc(item.id));
      }
      txn.delete(sourceRef);

      return movedMeal;
    });
  }

  /// Marks a `PLANNED` meal as `CANCELLED` (`MOD-04-05`). Does not affect stock.
  Future<void> cancelMeal({
    required String userId,
    required String mealId,
  }) async {
    final idx = _memoryMeals.indexWhere((m) => m.id == mealId);
    if (idx != -1) {
      _memoryMeals[idx] = _memoryMeals[idx].copyWith(status: MealStatus.cancelled);
    }

    if (_isMockUser(userId)) return;

    final mealRef = _mealDoc(userId, mealId);

    try {
      await _firestore.runTransaction((txn) async {
        await _requirePlannedMealInTxn(txn, mealRef);
        txn.update(mealRef, {
          'trang_thai': MealStatus.cancelled.value,
          'gio_nhac': null,
        });
      });
    } on FirebaseException {
      return; // in-memory đã cập nhật
    }
  }

  /// Marks a meal as completed (`MOD-04-08`).
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
      return _memoryMeals[idx];
    }

    final docRef = _mealDoc(userId, mealId);
    await docRef.update({
      'trang_thai': MealStatus.completed.value,
      'hoan_thanh_luc': completedAt.toIso8601String(),
    });
    final updated = await getMealById(userId: userId, mealId: mealId);
    return updated!;
  }

  /// Sets or clears `gio_nhac` on a `PLANNED` meal (`MOD-04-06`).
  Future<void> updateMealReminder({
    required String userId,
    required String mealId,
    DateTime? reminderAt,
  }) async {
    final idx = _memoryMeals.indexWhere((m) => m.id == mealId);
    if (idx != -1) {
      _memoryMeals[idx] = _memoryMeals[idx].copyWith(reminderAt: reminderAt);
    }

    if (_isMockUser(userId)) return;

    final mealRef = _mealDoc(userId, mealId);

    try {
      await _firestore.runTransaction((txn) async {
        await _requirePlannedMealInTxn(txn, mealRef);
        txn.update(mealRef, {
          'gio_nhac': reminderAt?.toIso8601String(),
        });
      });
    } on FirebaseException {
      return; // in-memory đã cập nhật
    }
  }

  /// Ensures the target meal exists and is still `PLANNED` before any mutation.
  Future<Meal> _requirePlannedMealInTxn(
    Transaction txn,
    DocumentReference<Map<String, dynamic>> mealRef,
  ) async {
    final snap = await txn.get(mealRef);
    if (!snap.exists || snap.data() == null) {
      throw const MealNotFoundException();
    }
    final meal = _mealFromDoc(snap);
    if (meal.isCompleted) {
      throw const MealAlreadyCompletedException();
    }
    if (meal.isCancelled) {
      throw const MealPlanException('Bữa ăn đã bị hủy, không thể thao tác.');
    }
    return meal;
  }

  List<Meal> _mapMealSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required bool includeCancelled,
  }) {
    final meals = snapshot.docs.map(_mealFromDoc);
    if (includeCancelled) return meals.toList();
    return meals.where((meal) => !meal.isCancelled).toList();
  }

  Meal _mealFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw const MealNotFoundException();
    }
    return Meal.fromMap(_normalizeMap(data), id: doc.id);
  }

  /// Converts Firestore [Timestamp] instances into Dart [DateTime] for pure-Dart models.
  Map<String, Object?> _normalizeMap(Map<String, dynamic> raw) {
    return raw.map((key, value) {
      if (value is Timestamp) {
        return MapEntry(key, value.toDate());
      }
      return MapEntry(key, value);
    });
  }
}

