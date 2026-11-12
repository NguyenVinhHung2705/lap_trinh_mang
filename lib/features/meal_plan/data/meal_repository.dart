import 'package:cloud_firestore/cloud_firestore.dart';

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
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
    final startKey = Meal.formatLocalDate(startDate);
    final endKey = Meal.formatLocalDate(endDate);

    final snapshot = await _mealsRef(userId)
        .where('ngay_an', isGreaterThanOrEqualTo: startKey)
        .where('ngay_an', isLessThanOrEqualTo: endKey)
        .orderBy('ngay_an')
        .get();

    return _mapMealSnapshot(snapshot, includeCancelled: includeCancelled);
  }

  /// Streams meals for [userId] within [startDate]..[endDate] for reactive calendar updates.
  Stream<List<Meal>> watchMealsInRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    bool includeCancelled = false,
  }) {
    final startKey = Meal.formatLocalDate(startDate);
    final endKey = Meal.formatLocalDate(endDate);

    return _mealsRef(userId)
        .where('ngay_an', isGreaterThanOrEqualTo: startKey)
        .where('ngay_an', isLessThanOrEqualTo: endKey)
        .orderBy('ngay_an')
        .snapshots()
        .map(
          (snapshot) =>
              _mapMealSnapshot(snapshot, includeCancelled: includeCancelled),
        );
  }

  /// Fetches a single meal by [mealId], or returns `null` if not found.
  Future<Meal?> getMealById({
    required String userId,
    required String mealId,
  }) async {
    final doc = await _mealDoc(userId, mealId).get();
    if (!doc.exists || doc.data() == null) return null;
    return _mealFromDoc(doc);
  }

  /// Finds the meal for `(userId, date, slot)` or creates a new `PLANNED` one (`MOD-04-02`).
  ///
  /// Uses a deterministic document ID inside a transaction to prevent duplicate slots.
  /// If a previous plan for that slot was `CANCELLED`, it is reactivated as `PLANNED`.
  Future<Meal> getOrCreateMeal({
    required String userId,
    required DateTime date,
    required MealSlot slot,
  }) async {
    final normalizedDate = Meal.normalizeLocalDate(date);
    final docId = Meal.buildDeterministicId(normalizedDate, slot);
    final docRef = _mealDoc(userId, docId);

    return _firestore.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      if (snap.exists && snap.data() != null) {
        final existing = _mealFromDoc(snap);
        if (!existing.isCancelled) {
          return existing;
        }
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
  }

  /// Reads all items in a meal (`mon_an_ke_hoach`).
  Future<List<MealItem>> getMealItems({
    required String userId,
    required String mealId,
  }) async {
    final snapshot = await _itemsRef(userId, mealId).get();
    return snapshot.docs
        .map((doc) => MealItem.fromMap(_normalizeMap(doc.data()), id: doc.id))
        .toList();
  }

  /// Streams items belonging to [mealId] in real time.
  Stream<List<MealItem>> watchMealItems({
    required String userId,
    required String mealId,
  }) {
    return _itemsRef(userId, mealId).snapshots().map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => MealItem.fromMap(_normalizeMap(doc.data()), id: doc.id),
              )
              .toList(),
        );
  }

  /// Adds a recipe or standalone food item to a `PLANNED` meal (`MOD-04-03`, `MOD-04-04`).
  ///
  /// Never modifies pantry stock. Generates a new document ID if [item.id] is `'new'`.
  Future<MealItem> addMealItem({
    required String userId,
    required MealItem item,
  }) async {
    final mealRef = _mealDoc(userId, item.mealId);
    final itemRef = item.id == 'new'
        ? _itemsRef(userId, item.mealId).doc()
        : _itemsRef(userId, item.mealId).doc(item.id);
    final persistedItem = item.id == itemRef.id ? item : item.copyWith(id: itemRef.id);

    await _firestore.runTransaction((txn) async {
      await _requirePlannedMealInTxn(txn, mealRef);
      txn.set(itemRef, persistedItem.toMap());
    });

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

    final mealRef = _mealDoc(userId, mealId);
    final itemRef = _itemsRef(userId, mealId).doc(itemId);

    await _firestore.runTransaction((txn) async {
      await _requirePlannedMealInTxn(txn, mealRef);
      final itemSnap = await txn.get(itemRef);
      if (!itemSnap.exists) {
        throw const MealNotFoundException();
      }
      txn.update(itemRef, {'so_luong': quantity});
    });
  }

  /// Removes a single item from a `PLANNED` meal (`MOD-04-05`).
  Future<void> removeMealItem({
    required String userId,
    required String mealId,
    required String itemId,
  }) async {
    final mealRef = _mealDoc(userId, mealId);
    final itemRef = _itemsRef(userId, mealId).doc(itemId);

    await _firestore.runTransaction((txn) async {
      await _requirePlannedMealInTxn(txn, mealRef);
      final itemSnap = await txn.get(itemRef);
      if (!itemSnap.exists) {
        throw const MealNotFoundException();
      }
      txn.delete(itemRef);
    });
  }

  /// Moves a `PLANNED` meal and its items to a new `(newDate, newSlot)` (`MOD-04-05`).
  ///
  /// Throws [MealSlotConflictException] if the target slot already has a non-cancelled meal.
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
    final mealRef = _mealDoc(userId, mealId);

    await _firestore.runTransaction((txn) async {
      await _requirePlannedMealInTxn(txn, mealRef);
      txn.update(mealRef, {
        'trang_thai': MealStatus.cancelled.value,
        'gio_nhac': null,
      });
    });
  }

  /// Sets or clears `gio_nhac` on a `PLANNED` meal (`MOD-04-06`).
  Future<void> updateMealReminder({
    required String userId,
    required String mealId,
    DateTime? reminderAt,
  }) async {
    final mealRef = _mealDoc(userId, mealId);

    await _firestore.runTransaction((txn) async {
      await _requirePlannedMealInTxn(txn, mealRef);
      txn.update(mealRef, {
        'gio_nhac': reminderAt?.toIso8601String(),
      });
    });
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

