import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/recipe_service.dart';
import 'recipe_list_provider.dart';

/// Target serving override for a specific recipe detail view.
final targetServingsProvider = StateProvider.family<double?, String>((ref, recipeId) => null);

/// Future/Stream provider for full recipe detail data with scaled ingredients.
final recipeDetailDataProvider = FutureProvider.autoDispose.family<RecipeDetailData, String>((ref, recipeId) async {
  final userId = ref.watch(currentUserIdProvider);
  final service = ref.watch(recipeServiceProvider);
  final targetServings = ref.watch(targetServingsProvider(recipeId));

  return service.getRecipeDetail(
    userId: userId,
    recipeId: recipeId,
    targetServings: targetServings,
  );
});
