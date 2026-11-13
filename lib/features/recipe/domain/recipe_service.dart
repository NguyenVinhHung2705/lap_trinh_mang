import '../data/models/recipe.dart';
import '../data/models/recipe_ingredient.dart';
import '../data/recipe_repository.dart';

/// DTO representing an ingredient line item dynamically scaled to target servings.
class ScaledIngredient {
  const ScaledIngredient({
    required this.foodId,
    required this.foodName,
    required this.unitId,
    required this.unitSymbol,
    required this.baseQuantity,
    required this.scaledQuantity,
    required this.targetServings,
  });

  final String foodId;
  final String foodName;
  final String unitId;
  final String unitSymbol;

  /// Quantity for base servings (`khau_phan`).
  final double baseQuantity;

  /// Quantity scaled for [targetServings] using formula: `baseQuantity * targetServings / baseServings`.
  final double scaledQuantity;

  /// Target servings user is scaling for.
  final double targetServings;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScaledIngredient &&
        other.foodId == foodId &&
        other.foodName == foodName &&
        other.unitId == unitId &&
        other.unitSymbol == unitSymbol &&
        other.baseQuantity == baseQuantity &&
        other.scaledQuantity == scaledQuantity &&
        other.targetServings == targetServings;
  }

  @override
  int get hashCode => Object.hash(
        foodId,
        foodName,
        unitId,
        unitSymbol,
        baseQuantity,
        scaledQuantity,
        targetServings,
      );
}

/// DTO containing full details of a recipe, scaled ingredients, and user bookmark status.
class RecipeDetailData {
  const RecipeDetailData({
    required this.recipe,
    required this.ingredients,
    required this.scaledIngredients,
    required this.targetServings,
    required this.isSaved,
  });

  final Recipe recipe;
  final List<RecipeIngredient> ingredients;
  final List<ScaledIngredient> scaledIngredients;
  final double targetServings;
  final bool isSaved;
}

/// Domain service for recipe management operations (`MOD-03`).
class RecipeService {
  RecipeService({
    required RecipeRepository recipeRepository,
  }) : _recipeRepository = recipeRepository;

  final RecipeRepository _recipeRepository;

  /// Calculates scaled ingredient quantities for [targetServings].
  ///
  /// MOD-03 Formula: `scaledQuantity = (baseQuantity * targetServings) / baseServings`.
  List<ScaledIngredient> calculateScaledIngredients({
    required Recipe recipe,
    required List<RecipeIngredient> ingredients,
    required double targetServings,
  }) {
    if (targetServings <= 0 || targetServings.isNaN || targetServings.isInfinite) {
      throw ArgumentError.value(
        targetServings,
        'targetServings',
        'Target servings must be > 0',
      );
    }

    return ingredients.map((ing) {
      final scaled = ing.calculateScaledQuantity(
        targetServings: targetServings,
        baseServings: recipe.baseServings,
      );
      return ScaledIngredient(
        foodId: ing.foodId,
        foodName: ing.foodName,
        unitId: ing.unitId,
        unitSymbol: ing.unitSymbol,
        baseQuantity: ing.baseQuantity,
        scaledQuantity: scaled,
        targetServings: targetServings,
      );
    }).toList();
  }

  /// Fetches a recipe detail and scales ingredients to [targetServings] (defaults to base servings).
  Future<RecipeDetailData> getRecipeDetail({
    required String userId,
    required String recipeId,
    double? targetServings,
  }) async {
    final recipe = await _recipeRepository.getRecipeById(recipeId);
    if (recipe == null) {
      throw const RecipeNotFoundException();
    }
    if (!recipe.canUserAccess(userId)) {
      throw const RecipePermissionDeniedException('Bạn không có quyền xem công thức này.');
    }

    final ingredients = await _recipeRepository.getRecipeIngredients(recipeId);
    final savedIds = await _recipeRepository.getSavedRecipeIds(userId);
    final servings = targetServings ?? recipe.baseServings;

    final scaled = calculateScaledIngredients(
      recipe: recipe,
      ingredients: ingredients,
      targetServings: servings,
    );

    return RecipeDetailData(
      recipe: recipe,
      ingredients: ingredients,
      scaledIngredients: scaled,
      targetServings: servings,
      isSaved: savedIds.contains(recipeId),
    );
  }

  /// Creates a new recipe for [userId]. Validates recipe fields and ingredient list.
  Future<Recipe> createRecipe({
    required String userId,
    required Recipe recipe,
    required List<RecipeIngredient> ingredients,
  }) async {
    _validateRecipeInputs(recipe, ingredients);

    final preparedRecipe = recipe.copyWith(authorId: userId);
    return _recipeRepository.createRecipe(
      recipe: preparedRecipe,
      ingredients: ingredients,
    );
  }

  /// Updates an existing recipe owned by [userId].
  Future<void> updateRecipe({
    required String userId,
    required Recipe recipe,
    required List<RecipeIngredient> ingredients,
  }) async {
    _validateRecipeInputs(recipe, ingredients);
    await _recipeRepository.updateRecipe(
      userId: userId,
      recipe: recipe,
      ingredients: ingredients,
    );
  }

  /// Deletes a recipe owned by [userId].
  Future<void> deleteRecipe({
    required String userId,
    required String recipeId,
  }) async {
    await _recipeRepository.deleteRecipe(
      userId: userId,
      recipeId: recipeId,
    );
  }

  /// Toggles saved/bookmarked status of a recipe.
  Future<bool> toggleSaveRecipe({
    required String userId,
    required String recipeId,
  }) async {
    return _recipeRepository.toggleSaveRecipe(
      userId: userId,
      recipeId: recipeId,
    );
  }

  static void _validateRecipeInputs(
    Recipe recipe,
    List<RecipeIngredient> ingredients,
  ) {
    if (recipe.name.trim().isEmpty) {
      throw const RecipeException('Tên món ăn không được để trống.');
    }
    if (recipe.instructions.trim().isEmpty) {
      throw const RecipeException('Hướng dẫn cách làm không được để trống.');
    }
    if (recipe.baseServings <= 0) {
      throw const RecipeException('Khẩu phần cơ sở phải lớn hơn 0.');
    }
    if (recipe.cookingMinutes < 0) {
      throw const RecipeException('Thời gian nấu phải >= 0 phút.');
    }
    if (ingredients.isEmpty) {
      throw const RecipeException('Công thức phải có ít nhất 1 nguyên liệu.');
    }
    for (final ing in ingredients) {
      if (ing.foodName.trim().isEmpty || ing.foodId.trim().isEmpty) {
        throw const RecipeException('Tên nguyên liệu không được để trống.');
      }
      if (ing.baseQuantity <= 0) {
        throw RecipeException('Định lượng cho "${ing.foodName}" phải lớn hơn 0.');
      }
    }
  }
}
