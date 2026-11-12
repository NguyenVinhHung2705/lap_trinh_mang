import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/meal_repository.dart';
import '../../data/models/meal.dart';

/// Display mode for the meal planning calendar (`MOD-04-01`).
enum CalendarViewMode {
  week('Tuần'),
  month('Tháng');

  const CalendarViewMode(this.labelVi);
  final String labelVi;
}

/// Immutable UI state for [MealCalendarController].
class MealCalendarState {
  MealCalendarState({
    this.viewMode = CalendarViewMode.week,
    DateTime? focusedDate,
    DateTime? selectedDate,
  })  : focusedDate = Meal.normalizeLocalDate(focusedDate ?? DateTime.now()),
        selectedDate = Meal.normalizeLocalDate(selectedDate ?? DateTime.now());

  final CalendarViewMode viewMode;
  final DateTime focusedDate;
  final DateTime selectedDate;

  /// Inclusive start date (local) of the currently displayed week or month.
  DateTime get rangeStart {
    if (viewMode == CalendarViewMode.week) {
      return focusedDate.subtract(Duration(days: focusedDate.weekday - 1));
    }
    return DateTime(focusedDate.year, focusedDate.month, 1);
  }

  /// Inclusive end date (local) of the currently displayed week or month.
  DateTime get rangeEnd {
    if (viewMode == CalendarViewMode.week) {
      return rangeStart.add(const Duration(days: 6));
    }
    return DateTime(focusedDate.year, focusedDate.month + 1, 0);
  }

  MealCalendarState copyWith({
    CalendarViewMode? viewMode,
    DateTime? focusedDate,
    DateTime? selectedDate,
  }) {
    return MealCalendarState(
      viewMode: viewMode ?? this.viewMode,
      focusedDate: focusedDate ?? this.focusedDate,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }
}

/// Manages view mode, active week/month navigation, and selected day (`MOD-04-01`).
class MealCalendarController extends Notifier<MealCalendarState> {
  @override
  MealCalendarState build() => MealCalendarState();

  void setViewMode(CalendarViewMode mode) {
    if (state.viewMode == mode) return;
    state = state.copyWith(viewMode: mode, focusedDate: state.selectedDate);
  }

  void selectDate(DateTime date) {
    final normalized = Meal.normalizeLocalDate(date);
    state = state.copyWith(selectedDate: normalized, focusedDate: normalized);
  }

  void goToToday() {
    final today = Meal.normalizeLocalDate(DateTime.now());
    state = state.copyWith(focusedDate: today, selectedDate: today);
  }

  void previousPeriod() => _shiftPeriod(-1);

  void nextPeriod() => _shiftPeriod(1);

  void _shiftPeriod(int delta) {
    final current = state.focusedDate;
    final shifted = state.viewMode == CalendarViewMode.week
        ? current.add(Duration(days: 7 * delta))
        : _shiftMonthSafely(current, delta);
    state = state.copyWith(focusedDate: shifted, selectedDate: shifted);
  }

  static DateTime _shiftMonthSafely(DateTime date, int monthDelta) {
    final targetFirst = DateTime(date.year, date.month + monthDelta, 1);
    final lastDayOfTargetMonth = DateTime(
      targetFirst.year,
      targetFirst.month + 1,
      0,
    ).day;
    final clampedDay = date.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : date.day;
    return DateTime(targetFirst.year, targetFirst.month, clampedDay);
  }
}

/// Provides the shared [MealRepository] instance.
final mealRepositoryProvider = Provider<MealRepository>((ref) {
  return MealRepository();
});

/// Provides the authenticated user's UID from Firebase Auth (`MOD-05` contract).
final currentUserIdProvider = Provider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});

/// Controller provider for [MealCalendarState].
final mealCalendarControllerProvider =
    NotifierProvider<MealCalendarController, MealCalendarState>(
  MealCalendarController.new,
);

/// Streams meals in the active week/month range for the current user (`MOD-04-01`).
final mealsInRangeProvider = StreamProvider.autoDispose<List<Meal>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null || userId.isEmpty) {
    return Stream.value(const <Meal>[]);
  }

  final calendarState = ref.watch(mealCalendarControllerProvider);
  final repo = ref.watch(mealRepositoryProvider);

  return repo.watchMealsInRange(
    userId: userId,
    startDate: calendarState.rangeStart,
    endDate: calendarState.rangeEnd,
  );
});

/// Groups meals by `YYYY-MM-DD` local date key and [MealSlot] for O(1) calendar lookup.
Map<String, Map<MealSlot, Meal>> groupMealsByDateAndSlot(List<Meal> meals) {
  final grouped = <String, Map<MealSlot, Meal>>{};
  for (final meal in meals) {
    final dateKey = Meal.formatLocalDate(meal.mealDate);
    grouped.putIfAbsent(dateKey, () => <MealSlot, Meal>{})[meal.slot] = meal;
  }
  return grouped;
}

