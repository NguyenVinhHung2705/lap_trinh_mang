import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_food_life/features/recipe/data/models/recipe.dart';
import 'package:smart_food_life/features/recipe/data/models/recipe_ingredient.dart';
import 'package:smart_food_life/features/recipe/data/recipe_repository.dart';
import 'package:smart_food_life/features/recipe/domain/recipe_service.dart';
import 'package:smart_food_life/features/recipe/presentation/widgets/ingredient_scaling_view.dart';
import 'package:smart_food_life/features/recipe/presentation/widgets/recipe_card.dart';

/// In-memory mock repository for testing MOD-03 logic without network calls.
class FakeRecipeRepository implements RecipeRepository {
  final Map<String, Recipe> _recipes = {};
  final Map<String, List<RecipeIngredient>> _ingredients = {};
  final Map<String, Set<String>> _saved = {};

  @override
  Future<List<Recipe>> getAccessibleRecipes({
    required String userId,
    String query = '',
    RecipeSource? sourceFilter,
    bool savedOnly = false,
  }) async {
    final lowerQuery = query.toLowerCase();
    final savedIds = _saved[userId] ?? {};

    return _recipes.values.where((r) {
      if (!r.canUserAccess(userId)) return false;
      if (sourceFilter != null && r.source != sourceFilter) return false;
      if (savedOnly && !savedIds.contains(r.id)) return false;
      if (lowerQuery.isNotEmpty && !r.name.toLowerCase().contains(lowerQuery)) return false;
      return true;
    }).toList();
  }

  @override
  Stream<List<Recipe>> watchAccessibleRecipes({
    required String userId,
    String query = '',
    RecipeSource? sourceFilter,
    bool savedOnly = false,
  }) {
    return Stream.value([]);
  }

  @override
  Future<Recipe?> getRecipeById(String recipeId) async {
    return _recipes[recipeId];
  }

  @override
  Future<List<RecipeIngredient>> getRecipeIngredients(String recipeId) async {
    return _ingredients[recipeId] ?? [];
  }

  @override
  Stream<List<RecipeIngredient>> watchRecipeIngredients(String recipeId) {
    return Stream.value(_ingredients[recipeId] ?? []);
  }

  @override
  Future<Recipe> createRecipe({
    required Recipe recipe,
    required List<RecipeIngredient> ingredients,
  }) async {
    final id = recipe.id == 'new' || recipe.id.isEmpty ? 'rec_${_recipes.length + 1}' : recipe.id;
    final persistedRecipe = recipe.copyWith(id: id);
    _recipes[id] = persistedRecipe;
    _ingredients[id] = ingredients.map((ing) => ing.copyWith(recipeId: id)).toList();
    return persistedRecipe;
  }

  @override
  Future<void> updateRecipe({
    required String userId,
    required Recipe recipe,
    required List<RecipeIngredient> ingredients,
  }) async {
    final existing = _recipes[recipe.id];
    if (existing == null) throw const RecipeNotFoundException();
    if (!existing.isAuthor(userId)) throw const RecipePermissionDeniedException();

    _recipes[recipe.id] = recipe;
    _ingredients[recipe.id] = ingredients;
  }

  @override
  Future<void> deleteRecipe({
    required String userId,
    required String recipeId,
  }) async {
    final existing = _recipes[recipeId];
    if (existing == null) throw const RecipeNotFoundException();
    if (!existing.isAuthor(userId)) throw const RecipePermissionDeniedException();

    _recipes.remove(recipeId);
    _ingredients.remove(recipeId);
  }

  @override
  Future<bool> toggleSaveRecipe({
    required String userId,
    required String recipeId,
  }) async {
    final userSaved = _saved.putIfAbsent(userId, () => <String>{});
    if (userSaved.contains(recipeId)) {
      userSaved.remove(recipeId);
      return false;
    } else {
      userSaved.add(recipeId);
      return true;
    }
  }

  @override
  Future<List<String>> getSavedRecipeIds(String userId) async {
    return (_saved[userId] ?? {}).toList();
  }

  @override
  Stream<List<String>> watchSavedRecipeIds(String userId) {
    return Stream.value((_saved[userId] ?? {}).toList());
  }
}

void main() {
  group('MOD-03 Recipe & RecipeIngredient Model Invariants', () {
    test('Recipe model validates inputs and enforces access controls', () {
      final sampleRecipe = Recipe(
        id: 'rec_pho',
        authorId: 'user_hy',
        name: 'Phở bò Hà Nội',
        instructions: 'Bước 1: Ninh xương...\nBước 2: Trụng bánh phở...',
        baseServings: 4,
        cookingMinutes: 120,
        source: RecipeSource.user,
        visibility: RecipeVisibility.private,
      );

      expect(sampleRecipe.baseServings, 4);
      expect(sampleRecipe.cookingMinutes, 120);

      // Author can access and edit
      expect(sampleRecipe.canUserAccess('user_hy'), isTrue);
      expect(sampleRecipe.isAuthor('user_hy'), isTrue);

      // Other user cannot access private recipe
      expect(sampleRecipe.canUserAccess('user_other'), isFalse);
      expect(sampleRecipe.isAuthor('user_other'), isFalse);

      // Public / System recipes are accessible to anyone
      final publicRecipe = sampleRecipe.copyWith(visibility: RecipeVisibility.public);
      expect(publicRecipe.canUserAccess('user_other'), isTrue);
    });

    test('Recipe throws ArgumentError on invalid servings or cooking time', () {
      expect(
        () => Recipe(
          id: 'rec_bad1',
          authorId: 'user_1',
          name: 'Món ăn',
          instructions: 'Nấu',
          baseServings: 0, // Invalid: <= 0
          cookingMinutes: 10,
        ),
        throwsArgumentError,
      );

      expect(
        () => Recipe(
          id: 'rec_bad2',
          authorId: 'user_1',
          name: 'Món ăn',
          instructions: 'Nấu',
          baseServings: 2,
          cookingMinutes: -5, // Invalid: < 0
        ),
        throwsArgumentError,
      );
    });

    test('RecipeIngredient calculates scaled quantity formula correctly', () {
      // Base recipe is for 2 servings
      final ing = RecipeIngredient(
        id: 'ing_beef',
        recipeId: 'rec_beef_noodle',
        foodId: 'food_beef',
        foodName: 'Thịt bò',
        unitId: 'unit_g',
        unitSymbol: 'g',
        baseQuantity: 300, // 300g for 2 servings
      );

      // Formula: scaledQuantity = (baseQuantity * targetServings) / baseServings
      // For 4 servings: 300 * 4 / 2 = 600g
      final scaled4 = ing.calculateScaledQuantity(
        targetServings: 4,
        baseServings: 2,
      );
      expect(scaled4, 600.0);

      // For 1 serving: 300 * 1 / 2 = 150g
      final scaled1 = ing.calculateScaledQuantity(
        targetServings: 1,
        baseServings: 2,
      );
      expect(scaled1, 150.0);

      // For 3 servings: 300 * 3 / 2 = 450g
      final scaled3 = ing.calculateScaledQuantity(
        targetServings: 3,
        baseServings: 2,
      );
      expect(scaled3, 450.0);
    });
  });

  group('MOD-03 RecipeService Domain Business Logic', () {
    late FakeRecipeRepository fakeRepo;
    late RecipeService recipeService;

    setUp(() {
      fakeRepo = FakeRecipeRepository();
      recipeService = RecipeService(recipeRepository: fakeRepo);
    });

    test('calculateScaledIngredients returns correct ScaledIngredient objects', () {
      final recipe = Recipe(
        id: 'rec_curry',
        authorId: 'user_hy',
        name: 'Cà rốt hầm bò',
        instructions: 'Hầm kỹ',
        baseServings: 4,
        cookingMinutes: 45,
      );

      final ingredients = [
        RecipeIngredient(
          id: 'ing_1',
          recipeId: recipe.id,
          foodId: 'food_beef',
          foodName: 'Thịt bò',
          unitId: 'unit_g',
          unitSymbol: 'g',
          baseQuantity: 500,
        ),
        RecipeIngredient(
          id: 'ing_2',
          recipeId: recipe.id,
          foodId: 'food_carrot',
          foodName: 'Cà rốt',
          unitId: 'unit_g',
          unitSymbol: 'g',
          baseQuantity: 200,
        ),
      ];

      // Scale to 2 servings (half)
      final scaled = recipeService.calculateScaledIngredients(
        recipe: recipe,
        ingredients: ingredients,
        targetServings: 2,
      );

      expect(scaled.length, 2);
      expect(scaled[0].foodName, 'Thịt bò');
      expect(scaled[0].scaledQuantity, 250.0); // 500 * 2 / 4
      expect(scaled[1].foodName, 'Cà rốt');
      expect(scaled[1].scaledQuantity, 100.0); // 200 * 2 / 4
    });

    test('createRecipe validates required fields and persists recipe with ingredients', () async {
      final newRecipe = Recipe(
        id: 'new',
        authorId: 'user_hy',
        name: 'Canh chua cá lóc',
        instructions: 'Nấu nước dùng chua ngọt...',
        baseServings: 3,
        cookingMinutes: 25,
        visibility: RecipeVisibility.public,
      );

      final ings = [
        RecipeIngredient(
          id: 'ing_fish',
          recipeId: 'new',
          foodId: 'food_fish',
          foodName: 'Cá lóc',
          unitId: 'unit_g',
          unitSymbol: 'g',
          baseQuantity: 400,
        ),
      ];

      final created = await recipeService.createRecipe(
        userId: 'user_hy',
        recipe: newRecipe,
        ingredients: ings,
      );

      expect(created.id, isNotEmpty);
      expect(created.id, isNot('new'));

      final detail = await recipeService.getRecipeDetail(
        userId: 'user_hy',
        recipeId: created.id,
      );

      expect(detail.recipe.name, 'Canh chua cá lóc');
      expect(detail.ingredients.length, 1);
      expect(detail.ingredients.first.foodName, 'Cá lóc');
    });

    test('createRecipe throws exception when input validation fails', () {
      final invalidRecipe = Recipe(
        id: 'new',
        authorId: 'user_hy',
        name: 'Món ăn không hướng dẫn',
        instructions: '   ', // Empty instructions -> throws RecipeException in service
        baseServings: 2,
        cookingMinutes: 15,
      );

      expect(
        () => recipeService.createRecipe(
          userId: 'user_hy',
          recipe: invalidRecipe,
          ingredients: [
            RecipeIngredient(
              id: '1',
              recipeId: 'new',
              foodId: 'f1',
              foodName: 'Rau',
              unitId: 'u1',
              unitSymbol: 'g',
              baseQuantity: 100,
            ),
          ],
        ),
        throwsA(isA<RecipeException>()),
      );
    });

    test('toggleSaveRecipe toggles bookmark state correctly', () async {
      final recipe = Recipe(
        id: 'rec_saved_1',
        authorId: 'user_other',
        name: 'Món hệ thống',
        instructions: 'Nấu đơn giản',
        baseServings: 2,
        cookingMinutes: 10,
        visibility: RecipeVisibility.public,
      );

      await fakeRepo.createRecipe(recipe: recipe, ingredients: []);

      // Toggle save: returns true (saved)
      final saved1 = await recipeService.toggleSaveRecipe(
        userId: 'user_hy',
        recipeId: recipe.id,
      );
      expect(saved1, isTrue);

      final detailSaved = await recipeService.getRecipeDetail(
        userId: 'user_hy',
        recipeId: recipe.id,
      );
      expect(detailSaved.isSaved, isTrue);

      // Toggle again: returns false (un-saved)
      final saved2 = await recipeService.toggleSaveRecipe(
        userId: 'user_hy',
        recipeId: recipe.id,
      );
      expect(saved2, isFalse);
    });
  });

  group('MOD-03 Presentation Widgets Tests', () {
    testWidgets('RecipeCard renders recipe title, cooking time, and base servings', (tester) async {
      final sample = Recipe(
        id: 'rec_widget_1',
        authorId: 'user_hy',
        name: 'Bún chả Hà Nội',
        instructions: 'Nướng chả...',
        baseServings: 3,
        cookingMinutes: 40,
        source: RecipeSource.user,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecipeCard(recipe: sample),
          ),
        ),
      );

      expect(find.text('Bún chả Hà Nội'), findsOneWidget);
      expect(find.text('40 phút'), findsOneWidget);
      expect(find.text('3 khẩu phần'), findsOneWidget);
      expect(find.text('Tự tạo'), findsOneWidget);
    });

    testWidgets('IngredientScalingView displays scaled quantities dynamically', (tester) async {
      double currentServings = 4;

      final scaledIngs = [
        const ScaledIngredient(
          foodId: 'food_beef',
          foodName: 'Thịt bò',
          unitId: 'unit_g',
          unitSymbol: 'g',
          baseQuantity: 300,
          scaledQuantity: 600,
          targetServings: 4,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return IngredientScalingView(
                  baseServings: 2,
                  currentServings: currentServings,
                  scaledIngredients: scaledIngs,
                  onServingsChanged: (val) {
                    setState(() => currentServings = val);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Số khẩu phần'), findsOneWidget);
      expect(find.text('Gốc: 2 khẩu phần'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Thịt bò'), findsOneWidget);
      expect(find.text('600 g'), findsOneWidget);

      // Tap decrease button (-)
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      expect(currentServings, 3.0);
    });
  });
}
