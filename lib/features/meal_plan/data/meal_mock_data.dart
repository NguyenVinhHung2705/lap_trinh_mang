import 'models/meal.dart';
import 'models/meal_item.dart';

/// Mock data cho phân hệ MOD-04: Kế hoạch Bữa ăn (Hồ Nguyên Khởi)
/// Phục vụ chế độ Local / Khách trải nghiệm mượt mà không cần Firestore.
class MealPlanMockData {
  const MealPlanMockData._();

  static final DateTime _today = Meal.normalizeLocalDate(DateTime.now());

  static List<Meal> get initialMeals => [
        Meal(
          id: 'meal_today_breakfast',
          userId: 'mock_user_nguyen_van_dinh',
          mealDate: _today,
          slot: MealSlot.breakfast,
          status: MealStatus.completed,
          completedAt: _today.add(const Duration(hours: 7, minutes: 30)),
          reminderAt: _today.add(const Duration(hours: 7)),
        ),
        Meal(
          id: 'meal_today_lunch',
          userId: 'mock_user_nguyen_van_dinh',
          mealDate: _today,
          slot: MealSlot.lunch,
          status: MealStatus.planned,
          reminderAt: _today.add(const Duration(hours: 11, minutes: 30)),
        ),
        Meal(
          id: 'meal_today_dinner',
          userId: 'mock_user_nguyen_van_dinh',
          mealDate: _today,
          slot: MealSlot.dinner,
          status: MealStatus.planned,
          reminderAt: _today.add(const Duration(hours: 18, minutes: 30)),
        ),
        Meal(
          id: 'meal_tomorrow_lunch',
          userId: 'mock_user_nguyen_van_dinh',
          mealDate: _today.add(const Duration(days: 1)),
          slot: MealSlot.lunch,
          status: MealStatus.planned,
        ),
      ];

  static Map<String, List<MealItem>> get initialMealItems => {
        'meal_today_breakfast': [
          MealItem(
            id: 'item_bf_1',
            mealId: 'meal_today_breakfast',
            recipeId: 'recipe_pho_bo',
            quantity: 2,
          ),
        ],
        'meal_today_lunch': [
          MealItem(
            id: 'item_lu_1',
            mealId: 'meal_today_lunch',
            recipeId: 'recipe_com_tam',
            quantity: 1,
          ),
        ],
        'meal_today_dinner': [
          MealItem(
            id: 'item_di_1',
            mealId: 'meal_today_dinner',
            recipeId: 'recipe_canh_chua',
            quantity: 4,
          ),
          MealItem(
            id: 'item_di_2',
            mealId: 'meal_today_dinner',
            recipeId: 'recipe_trung_cuon',
            quantity: 2,
          ),
        ],
        'meal_tomorrow_lunch': [
          MealItem(
            id: 'item_tml_1',
            mealId: 'meal_tomorrow_lunch',
            recipeId: 'recipe_salad_uc_ga',
            quantity: 2,
          ),
        ],
      };
}
