import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/recipe.dart';
import '../../data/recipe_repository.dart';
import '../../domain/recipe_service.dart';

/// Provider for [RecipeRepository]. Override in tests.
final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository();
});

/// Provider for [RecipeService].
final recipeServiceProvider = Provider<RecipeService>((ref) {
  final repo = ref.watch(recipeRepositoryProvider);
  return RecipeService(recipeRepository: repo);
});

/// Current active user UID from Firebase Auth.
final currentUserIdProvider = Provider<String>((ref) {
  final authUser = FirebaseAuth.instance.currentUser;
  return authUser?.uid ?? 'guest_user';
});

/// State provider for search query text filter.
final recipeSearchQueryProvider = StateProvider<String>((ref) => '');

/// State provider for recipe source filter (Tất cả / Tự tạo / Hệ thống / Cộng đồng).
final recipeSourceFilterProvider = StateProvider<RecipeSource?>((ref) => null);

/// State provider for toggling saved/bookmarked tab filter.
final recipeSavedOnlyFilterProvider = StateProvider<bool>((ref) => false);

/// Stream provider for accessible recipe list with active filters.
final accessibleRecipesStreamProvider = StreamProvider.autoDispose<List<Recipe>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final repo = ref.watch(recipeRepositoryProvider);
  final query = ref.watch(recipeSearchQueryProvider);
  final source = ref.watch(recipeSourceFilterProvider);
  final savedOnly = ref.watch(recipeSavedOnlyFilterProvider);

  return repo.watchAccessibleRecipes(
    userId: userId,
    query: query,
    sourceFilter: source,
    savedOnly: savedOnly,
  );
});

/// Stream provider for saved recipe IDs for real-time bookmark indicators.
final savedRecipeIdsStreamProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.watchSavedRecipeIds(userId);
});
