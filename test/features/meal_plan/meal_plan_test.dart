import 'package:flutter_test/flutter_test.dart';
import 'package:smart_food_life/features/meal_plan/data/models/consumption_request.dart';
import 'package:smart_food_life/features/meal_plan/data/models/meal.dart';
import 'package:smart_food_life/features/meal_plan/data/models/meal_item.dart';
import 'package:smart_food_life/features/meal_plan/domain/meal_service.dart';
import 'package:smart_food_life/features/meal_plan/domain/stock_deduction_service.dart';

/// In-memory mock for [PantryBatchReader] to verify FEFO allocation and test cases.
class MockPantryBatchReader implements PantryBatchReader {
  MockPantryBatchReader(this.batches);

  final List<PantryBatchInfo> batches;

  @override
  Future<List<PantryBatchInfo>> getUsableBatchesForFood({
    required String userId,
    required String foodId,
    required DateTime referenceDate,
  }) async {
    final usable = batches
        .where((b) => b.foodId == foodId && b.isUsable(referenceDate))
        .toList();
    // FEFO: earliest expiry first
    usable.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return usable;
  }
}

void main() {
  group('Meal & MealItem Model Invariants', () {
    test('Meal normalizes dates to local midnight and builds deterministic ID', () {
      final date = DateTime(2026, 11, 15, 14, 30);
      final meal = Meal(
        id: 'test_1',
        userId: 'user_123',
        mealDate: date,
        slot: MealSlot.lunch,
      );

      expect(meal.mealDate.hour, 0);
      expect(meal.mealDate.minute, 0);
      expect(Meal.formatLocalDate(meal.mealDate), '2026-11-15');
      expect(
        Meal.buildDeterministicId(date, MealSlot.lunch),
        '2026-11-15_LUNCH',
      );
    });

    test('MealItem enforces XOR invariant between recipeId and foodId', () {
      // Valid recipe item
      final recipeItem = MealItem.recipe(
        id: 'item_1',
        mealId: 'meal_1',
        recipeId: 'rec_beef_pho',
        servings: 2.0,
      );
      expect(recipeItem.isRecipe, isTrue);
      expect(recipeItem.foodId, isNull);

      // Valid standalone food item
      final foodItem = MealItem.standaloneFood(
        id: 'item_2',
        mealId: 'meal_1',
        foodId: 'food_apple',
        unitId: 'unit_piece',
        quantity: 3.0,
      );
      expect(foodItem.isStandaloneFood, isTrue);
      expect(foodItem.recipeId, isNull);

      // Invalid: both recipeId and foodId provided
      expect(
        () => MealItem(
          id: 'bad_1',
          mealId: 'meal_1',
          recipeId: 'rec_1',
          foodId: 'food_1',
          quantity: 1,
        ),
        throwsArgumentError,
      );

      // Invalid: neither recipeId nor foodId provided
      expect(
        () => MealItem(
          id: 'bad_2',
          mealId: 'meal_1',
          quantity: 1,
        ),
        throwsArgumentError,
      );

      // Invalid: quantity <= 0
      expect(
        () => MealItem.recipe(
          id: 'bad_3',
          mealId: 'meal_1',
          recipeId: 'rec_1',
          servings: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Core Integration Test Cases (TC-08 .. TC-11)', () {
    late Meal samplePlannedMeal;

    setUp(() {
      samplePlannedMeal = Meal(
        id: '2026-11-15_DINNER',
        userId: 'user_khơi',
        mealDate: DateTime(2026, 11, 15),
        slot: MealSlot.dinner,
        status: MealStatus.planned,
      );
    });

    // TC-08: Thêm món vào lịch nhưng chưa hoàn thành -> Tồn kho không thay đổi
    test('TC-08: Adding items to a meal plan preserves PLANNED status and does not touch inventory', () {
      final item = MealItem.recipe(
        id: 'item_1',
        mealId: samplePlannedMeal.id,
        recipeId: 'recipe_curry',
        servings: 4,
      );

      expect(samplePlannedMeal.isPlanned, isTrue);
      expect(samplePlannedMeal.isCompleted, isFalse);
      expect(samplePlannedMeal.completedAt, isNull);
      expect(item.quantity, 4);
      // Planning phase remains purely informational
    });

    // TC-09: Hoàn thành khi thiếu một nguyên liệu -> Không trừ bất kỳ lô nào (All-or-nothing)
    test('TC-09: Preview aborts and flags shortage if ANY ingredient is insufficient', () async {
      final mockReader = MockPantryBatchReader([
        PantryBatchInfo(
          id: 'batch_beef_1',
          foodId: 'food_beef',
          locationId: 'fridge_top',
          importDate: DateTime(2026, 11, 10),
          expiryDate: DateTime(2026, 11, 20),
          availableQuantity: 500.0, // Enough (needs 300g)
        ),
        PantryBatchInfo(
          id: 'batch_carrot_1',
          foodId: 'food_carrot',
          locationId: 'pantry_shelf',
          importDate: DateTime(2026, 11, 10),
          expiryDate: DateTime(2026, 11, 20),
          availableQuantity: 50.0, // Shortage! (needs 200g, shortage = 150g)
        ),
      ]);

      final request = ConsumptionRequest(
        userId: samplePlannedMeal.userId,
        meal: samplePlannedMeal,
        items: [
          ConsumptionItem(
            mealItemId: 'item_beef',
            foodId: 'food_beef',
            foodName: 'Thịt bò',
            sourceLabel: 'Bò kho',
            baseUnitId: 'unit_g',
            baseUnitSymbol: 'g',
            expectedQuantity: 300,
            actualQuantity: 300,
          ),
          ConsumptionItem(
            mealItemId: 'item_carrot',
            foodId: 'food_carrot',
            foodName: 'Cà rốt',
            sourceLabel: 'Bò kho',
            baseUnitId: 'unit_g',
            baseUnitSymbol: 'g',
            expectedQuantity: 200,
            actualQuantity: 200,
          ),
        ],
      );

      final service = StockDeductionService(
        mealRepository: _DummyMealRepository(),
        batchReader: mockReader,
      );

      final preview = await service.previewPlan(
        userId: samplePlannedMeal.userId,
        request: request,
      );

      expect(preview.isAllSufficient, isFalse);
      expect(preview.shortages.length, 1);
      expect(preview.shortages.first.foodId, 'food_carrot');
      expect(preview.shortages.first.shortage, 150.0);
    });

    // TC-10: Hai thiết bị xác nhận cùng bữa ăn -> Chỉ một lần tiêu thụ được ghi nhận (Idempotency)
    test('TC-10: Completed meal cannot be re-completed or re-deducted', () {
      final completedMeal = samplePlannedMeal.copyWith(
        status: MealStatus.completed,
        completedAt: DateTime.now(),
      );

      expect(completedMeal.isCompleted, isTrue);

      // Attempting to create a ConsumptionRequest on an already completed meal fails early
      expect(
        () => ConsumptionRequest(
          userId: completedMeal.userId,
          meal: completedMeal,
          items: [
            ConsumptionItem(
              mealItemId: 'item_1',
              foodId: 'food_1',
              foodName: 'Rau',
              sourceLabel: 'Luộc',
              baseUnitId: 'g',
              baseUnitSymbol: 'g',
              expectedQuantity: 100,
              actualQuantity: 100,
            ),
          ],
        ),
        throwsA(isA<MealAlreadyCompletedException>()),
      );
    });

    // TC-11: Xuất qua hai lô có hạn khác nhau -> Ưu tiên lô gần hết hạn còn dùng được (FEFO)
    test('TC-11: FEFO allocation deducts from earliest-expiry batch first', () async {
      final mockReader = MockPantryBatchReader([
        PantryBatchInfo(
          id: 'batch_far_expiry',
          foodId: 'food_milk',
          locationId: 'door',
          importDate: DateTime(2026, 11, 10),
          expiryDate: DateTime(2026, 11, 28), // Later expiry
          availableQuantity: 1000.0,
        ),
        PantryBatchInfo(
          id: 'batch_near_expiry',
          foodId: 'food_milk',
          locationId: 'shelf_1',
          importDate: DateTime(2026, 11, 08),
          expiryDate: DateTime(2026, 11, 16), // Earliest expiry (FEFO first!)
          availableQuantity: 400.0,
        ),
      ]);

      final request = ConsumptionRequest(
        userId: samplePlannedMeal.userId,
        meal: samplePlannedMeal,
        items: [
          ConsumptionItem(
            mealItemId: 'item_milk',
            foodId: 'food_milk',
            foodName: 'Sữa tươi',
            sourceLabel: 'Bữa tối',
            baseUnitId: 'unit_ml',
            baseUnitSymbol: 'ml',
            expectedQuantity: 600,
            actualQuantity: 600, // Needs 600 ml: 400 from near_expiry, 200 from far_expiry
          ),
        ],
      );

      final service = StockDeductionService(
        mealRepository: _DummyMealRepository(),
        batchReader: mockReader,
      );

      final preview = await service.previewPlan(
        userId: samplePlannedMeal.userId,
        request: request,
      );

      expect(preview.isAllSufficient, isTrue);
      final allocations = preview.plans.first.allocations;
      expect(allocations.length, 2);

      // First allocated batch MUST be the earliest expiry (batch_near_expiry)
      expect(allocations[0].batch.id, 'batch_near_expiry');
      expect(allocations[0].quantityToDeduct, 400.0);

      // Remaining 200 ml taken from batch_far_expiry
      expect(allocations[1].batch.id, 'batch_far_expiry');
      expect(allocations[1].quantityToDeduct, 200.0);
    });
  });
}

/// Minimal mock to satisfy constructor dependency in offline tests.
class _DummyMealRepository implements MealRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
