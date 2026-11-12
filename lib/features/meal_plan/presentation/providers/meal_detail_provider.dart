import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/meal.dart';
import '../../data/models/meal_item.dart';
import 'meal_calendar_provider.dart';

/// Value-typed key identifying a `(date, slot)` pair for `MOD-04-02`.
@immutable
class MealSlotKey {
  MealSlotKey({
    required DateTime date,
    required this.slot,
  }) : date = Meal.normalizeLocalDate(date);

  final DateTime date;
  final MealSlot slot;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MealSlotKey && other.date == date && other.slot == slot;
  }

  @override
  int get hashCode => Object.hash(date, slot);
}

/// Ensures a meal exists for `(currentUser, date, slot)` (`MOD-04-02`) and exposes refresh actions.
class MealDetailController extends AutoDisposeFamilyAsyncNotifier<Meal, MealSlotKey> {
  @override
  Future<Meal> build(MealSlotKey arg) async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null || userId.isEmpty) {
      throw StateError('Vui lòng đăng nhập để mở chi tiết bữa ăn.');
    }

    final repo = ref.read(mealRepositoryProvider);
    return repo.getOrCreateMeal(
      userId: userId,
      date: arg.date,
      slot: arg.slot,
    );
  }

  /// Reloads the meal from Firestore (e.g., after reminder/completion/reschedule updates).
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// Resolves or creates the [Meal] for a [MealSlotKey] (`MOD-04-02`).
final mealDetailProvider = AsyncNotifierProvider.autoDispose
    .family<MealDetailController, Meal, MealSlotKey>(
  MealDetailController.new,
);

/// Streams planned items (`mon_an_ke_hoach`) for a specific [mealId].
final mealItemsProvider =
    StreamProvider.autoDispose.family<List<MealItem>, String>((ref, mealId) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null || userId.isEmpty) {
    return Stream.value(const <MealItem>[]);
  }
  final repo = ref.watch(mealRepositoryProvider);
  return repo.watchMealItems(userId: userId, mealId: mealId);
});

