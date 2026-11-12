import 'package:flutter/material.dart';

import 'data/models/meal.dart';
import 'presentation/screens/meal_calendar_screen.dart';
import 'presentation/screens/meal_detail_screen.dart';

/// Public interface and navigation entrypoints for `MOD-04: Meal Planning`.
class MealPlanModule {
  const MealPlanModule._();

  /// Route name for the meal planning calendar (Bottom Nav Tab 4: "Kế hoạch").
  static const String calendarRoute = '/meal-plan/calendar';

  /// Route name for meal detail screen.
  static const String detailRoute = '/meal-plan/detail';

  /// Creates the primary calendar view widget.
  static Widget buildCalendarScreen({
    MealSlotTapCallback? onSlotTap,
  }) {
    return MealCalendarScreen(
      onMealSlotTap: onSlotTap,
    );
  }

  /// Opens the detail screen for a specific date and slot, handling default in-app navigation.
  static Future<void> openMealDetail(
    BuildContext context, {
    required DateTime date,
    required MealSlot slot,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MealDetailScreen(
          initialDate: date,
          initialSlot: slot,
        ),
      ),
    );
  }
}
