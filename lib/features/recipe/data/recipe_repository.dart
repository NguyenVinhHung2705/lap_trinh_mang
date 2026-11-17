import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/recipe.dart';
import 'models/recipe_ingredient.dart';
import 'recipe_mock_data.dart';

/// Base exception for recipe repository operations.
class RecipeException implements Exception {
  const RecipeException(this.message);

  final String message;

  @override
  String toString() => 'RecipeException: $message';
}

/// Thrown when a requested recipe document is missing.
class RecipeNotFoundException extends RecipeException {
  const RecipeNotFoundException([
    super.message = 'Không tìm thấy công thức nấu ăn.',
  ]);
}

/// Thrown when a user attempts to edit or delete a recipe they do not own.
class RecipePermissionDeniedException extends RecipeException {
  const RecipePermissionDeniedException([
    super.message = 'Bạn không có quyền chỉnh sửa hoặc xóa công thức này.',
  ]);
}

/// Firestore data access layer for `cong_thuc`, `nguyen_lieu_cong_thuc`, and `cong_thuc_da_luu`.
///
/// Maps to:
/// - `/cong_thuc/{recipeId}`
/// - `/cong_thuc/{recipeId}/nguyen_lieu/{ingredientId}`
/// - `/users/{userId}/cong_thuc_da_luu/{recipeId}`
class RecipeRepository {
  RecipeRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  // In-memory fallback / mock store for offline & guest usage
  static final List<Recipe> _memoryRecipes = List<Recipe>.from(RecipeMockData.initialRecipes);
  static final Map<String, List<RecipeIngredient>> _memoryIngredients =
      RecipeMockData.initialIngredients.map((k, v) => MapEntry(k, List<RecipeIngredient>.from(v)));
  static final Map<String, Set<String>> _memorySavedIds = {};

  bool _isMockUser(String userId) {
    return userId.isEmpty || userId.startsWith('mock_') || userId.startsWith('guest_');
  }

  CollectionReference<Map<String, dynamic>> get _recipesRef {
    return _firestore.collection('cong_thuc');
  }

  DocumentReference<Map<String, dynamic>> _recipeDoc(String recipeId) {
    return _recipesRef.doc(recipeId);
  }

  CollectionReference<Map<String, dynamic>> _ingredientsRef(String recipeId) {
    return _recipeDoc(recipeId).collection('nguyen_lieu');
  }

  CollectionReference<Map<String, dynamic>> _savedRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('cong_thuc_da_luu');
  }

  /// Queries all recipes accessible to [userId], with optional title search, source filter, and saved filter.
  Future<List<Recipe>> getAccessibleRecipes({
    required String userId,
    String query = '',
    RecipeSource? sourceFilter,
    bool savedOnly = false,
  }) async {
    if (_isMockUser(userId)) {
      return _filterMemoryRecipes(
        userId: userId,
        query: query,
        sourceFilter: sourceFilter,
        savedOnly: savedOnly,
      );
    }

    try {
      List<String> savedIds = const [];
      if (savedOnly) {
        savedIds = await getSavedRecipeIds(userId);
        if (savedIds.isEmpty) return const [];
      }

      final snapshot = await _recipesRef.get();
      if (snapshot.docs.isEmpty) {
        // Fallback to mock data if Firestore is empty
        return _filterMemoryRecipes(
          userId: userId,
          query: query,
          sourceFilter: sourceFilter,
          savedOnly: savedOnly,
        );
      }

      return _filterRecipes(
        snapshot.docs,
        userId: userId,
        query: query,
        sourceFilter: sourceFilter,
        savedIds: savedOnly ? savedIds : null,
      );
    } catch (_) {
      return _filterMemoryRecipes(
        userId: userId,
        query: query,
        sourceFilter: sourceFilter,
        savedOnly: savedOnly,
      );
    }
  }

  /// Streams accessible recipes in real-time.
  Stream<List<Recipe>> watchAccessibleRecipes({
    required String userId,
    String query = '',
    RecipeSource? sourceFilter,
    bool savedOnly = false,
  }) {
    if (_isMockUser(userId)) {
      final recipes = _filterMemoryRecipes(
        userId: userId,
        query: query,
        sourceFilter: sourceFilter,
        savedOnly: savedOnly,
      );
      return Stream.value(recipes);
    }

    if (savedOnly) {
      return watchSavedRecipeIds(userId).asyncMap((savedIds) async {
        if (savedIds.isEmpty) return const <Recipe>[];
        final snapshot = await _recipesRef.get();
        if (snapshot.docs.isEmpty) {
          return _filterMemoryRecipes(
            userId: userId,
            query: query,
            sourceFilter: sourceFilter,
            savedOnly: true,
          );
        }
        return _filterRecipes(
          snapshot.docs,
          userId: userId,
          query: query,
          sourceFilter: sourceFilter,
          savedIds: savedIds,
        );
      }).handleError((_) {
        return _filterMemoryRecipes(
          userId: userId,
          query: query,
          sourceFilter: sourceFilter,
          savedOnly: savedOnly,
        );
      });
    }

    return _recipesRef.snapshots().map(
          (snapshot) {
            if (snapshot.docs.isEmpty) {
              return _filterMemoryRecipes(
                userId: userId,
                query: query,
                sourceFilter: sourceFilter,
              );
            }
            return _filterRecipes(
              snapshot.docs,
              userId: userId,
              query: query,
              sourceFilter: sourceFilter,
            );
          },
        ).handleError((_) {
          return _filterMemoryRecipes(
            userId: userId,
            query: query,
            sourceFilter: sourceFilter,
            savedOnly: savedOnly,
          );
        });
  }

  /// Fetches a single recipe by [recipeId].
  Future<Recipe?> getRecipeById(String recipeId) async {
    final memoryRecipe = _memoryRecipes.cast<Recipe?>().firstWhere(
          (r) => r?.id == recipeId,
          orElse: () => null,
        );
    try {
      final doc = await _recipeDoc(recipeId).get();
      if (!doc.exists || doc.data() == null) return memoryRecipe;
      return Recipe.fromMap(_normalizeMap(doc.data()!), id: doc.id);
    } catch (_) {
      return memoryRecipe;
    }
  }

  /// Reads ingredients for a recipe (`nguyen_lieu_cong_thuc`).
  Future<List<RecipeIngredient>> getRecipeIngredients(String recipeId) async {
    final memoryList = _memoryIngredients[recipeId] ?? const [];
    try {
      final snapshot = await _ingredientsRef(recipeId).get();
      if (snapshot.docs.isEmpty) return memoryList;
      return snapshot.docs
          .map(
            (doc) => RecipeIngredient.fromMap(
              _normalizeMap(doc.data()),
              id: doc.id,
            ),
          )
          .toList();
    } catch (_) {
      return memoryList;
    }
  }

  /// Streams ingredients for a recipe in real time.
  Stream<List<RecipeIngredient>> watchRecipeIngredients(String recipeId) {
    final memoryList = _memoryIngredients[recipeId] ?? const [];
    return _ingredientsRef(recipeId).snapshots().map(
          (snapshot) {
            if (snapshot.docs.isEmpty) return memoryList;
            return snapshot.docs
                .map(
                  (doc) => RecipeIngredient.fromMap(
                    _normalizeMap(doc.data()),
                    id: doc.id,
                  ),
                )
                .toList();
          },
        ).handleError((_) => memoryList);
  }

  /// Creates a new recipe and writes its ingredient subcollection atomically.
  Future<Recipe> createRecipe({
    required Recipe recipe,
    required List<RecipeIngredient> ingredients,
  }) async {
    final newId = recipe.id == 'new' || recipe.id.isEmpty
        ? 'recipe_${DateTime.now().millisecondsSinceEpoch}'
        : recipe.id;
    final persistedRecipe = recipe.copyWith(id: newId);

    _memoryRecipes.insert(0, persistedRecipe);
    _memoryIngredients[newId] = ingredients
        .map((i) => i.copyWith(
              id: i.id == 'new' || i.id.isEmpty
                  ? 'ing_${DateTime.now().microsecondsSinceEpoch}_${i.foodId}'
                  : i.id,
              recipeId: newId,
            ))
        .toList();

    if (_isMockUser(recipe.authorId)) {
      return persistedRecipe;
    }

    try {
      final docRef = _recipeDoc(newId);
      final batch = _firestore.batch();
      batch.set(docRef, persistedRecipe.toMap());

      for (final ing in _memoryIngredients[newId]!) {
        final ingRef = _ingredientsRef(newId).doc(ing.id);
        batch.set(ingRef, ing.toMap());
      }

      await batch.commit();
    } catch (_) {
      // Ignored for offline mode
    }

    return persistedRecipe;
  }

  /// Updates an existing recipe and synchronizes ingredients subcollection.
  Future<void> updateRecipe({
    required String userId,
    required Recipe recipe,
    required List<RecipeIngredient> ingredients,
  }) async {
    final idx = _memoryRecipes.indexWhere((r) => r.id == recipe.id);
    if (idx != -1) {
      _memoryRecipes[idx] = recipe;
      _memoryIngredients[recipe.id] = ingredients;
    }

    if (_isMockUser(userId)) return;

    final existing = await getRecipeById(recipe.id);
    if (existing == null) {
      throw const RecipeNotFoundException();
    }
    if (!existing.isAuthor(userId)) {
      throw const RecipePermissionDeniedException();
    }

    final batch = _firestore.batch();
    final docRef = _recipeDoc(recipe.id);
    batch.update(docRef, recipe.toMap());

    // Clean up existing ingredients and replace with new set
    final existingIngs = await _ingredientsRef(recipe.id).get();
    for (final doc in existingIngs.docs) {
      batch.delete(doc.reference);
    }

    for (final ing in ingredients) {
      final ingRef = _ingredientsRef(recipe.id).doc(ing.foodId);
      final persistedIng = ing.copyWith(id: ingRef.id, recipeId: recipe.id);
      batch.set(ingRef, persistedIng.toMap());
    }

    await batch.commit();
  }

  /// Deletes a recipe document and all its ingredient subcollection entries.
  Future<void> deleteRecipe({
    required String userId,
    required String recipeId,
  }) async {
    _memoryRecipes.removeWhere((r) => r.id == recipeId);
    _memoryIngredients.remove(recipeId);

    if (_isMockUser(userId)) return;

    final existing = await getRecipeById(recipeId);
    if (existing == null) {
      throw const RecipeNotFoundException();
    }
    if (!existing.isAuthor(userId)) {
      throw const RecipePermissionDeniedException();
    }

    final batch = _firestore.batch();
    final docRef = _recipeDoc(recipeId);

    final ingredientsSnap = await _ingredientsRef(recipeId).get();
    for (final doc in ingredientsSnap.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(docRef);
    await batch.commit();
  }

  /// Bookmarks or un-bookmarks a recipe for [userId] (`cong_thuc_da_luu`).
  Future<bool> toggleSaveRecipe({
    required String userId,
    required String recipeId,
  }) async {
    final userSaved = _memorySavedIds.putIfAbsent(userId, () => <String>{});
    if (userSaved.contains(recipeId)) {
      userSaved.remove(recipeId);
    } else {
      userSaved.add(recipeId);
    }

    if (_isMockUser(userId)) {
      return userSaved.contains(recipeId);
    }

    try {
      final docRef = _savedRef(userId).doc(recipeId);
      final doc = await docRef.get();
      if (doc.exists) {
        await docRef.delete();
        return false;
      } else {
        await docRef.set({
          'ma_cong_thuc': recipeId,
          'ngay_luu': DateTime.now().toIso8601String(),
        });
        return true;
      }
    } catch (_) {
      return userSaved.contains(recipeId);
    }
  }

  /// Gets list of saved recipe IDs for [userId].
  Future<List<String>> getSavedRecipeIds(String userId) async {
    final memoryList = _memorySavedIds[userId]?.toList() ?? const [];
    if (_isMockUser(userId)) return memoryList;
    try {
      final snap = await _savedRef(userId).get();
      return snap.docs.map((doc) => doc.id).toList();
    } catch (_) {
      return memoryList;
    }
  }

  /// Streams list of saved recipe IDs for real-time bookmark toggles.
  Stream<List<String>> watchSavedRecipeIds(String userId) {
    final memoryList = _memorySavedIds[userId]?.toList() ?? const [];
    if (_isMockUser(userId)) {
      return Stream.value(memoryList);
    }
    return _savedRef(userId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.id).toList())
        .handleError((_) => memoryList);
  }

  /// Seeds initial recipes into Firestore if the collection is empty.
  Future<void> seedInitialRecipesIfEmpty() async {
    try {
      final snap = await _recipesRef.limit(1).get();
      if (snap.docs.isEmpty) {
        for (final recipe in RecipeMockData.initialRecipes) {
          final ingList = RecipeMockData.initialIngredients[recipe.id] ?? const [];
          await createRecipe(recipe: recipe, ingredients: ingList);
        }
      }
    } catch (_) {
      // Non-fatal if offline
    }
  }

  List<Recipe> _filterMemoryRecipes({
    required String userId,
    required String query,
    RecipeSource? sourceFilter,
    bool savedOnly = false,
  }) {
    final lowerQuery = query.trim().toLowerCase();
    final savedIds = _memorySavedIds[userId] ?? const <String>{};

    return _memoryRecipes.where((recipe) {
      if (!recipe.canUserAccess(userId)) return false;
      if (sourceFilter != null && recipe.source != sourceFilter) return false;
      if (savedOnly && !savedIds.contains(recipe.id)) return false;
      if (lowerQuery.isNotEmpty && !recipe.name.toLowerCase().contains(lowerQuery)) {
        return false;
      }
      return true;
    }).toList();
  }

  List<Recipe> _filterRecipes(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required String userId,
    required String query,
    RecipeSource? sourceFilter,
    List<String>? savedIds,
  }) {
    final lowerQuery = query.trim().toLowerCase();
    final result = <Recipe>[];

    for (final doc in docs) {
      final data = doc.data();
      final recipe = Recipe.fromMap(_normalizeMap(data), id: doc.id);

      if (!recipe.canUserAccess(userId)) continue;
      if (sourceFilter != null && recipe.source != sourceFilter) continue;
      if (savedIds != null && !savedIds.contains(recipe.id)) continue;
      if (lowerQuery.isNotEmpty && !recipe.name.toLowerCase().contains(lowerQuery)) {
        continue;
      }
      result.add(recipe);
    }

    return result;
  }

  Map<String, Object?> _normalizeMap(Map<String, dynamic> raw) {
    return raw.map((key, value) {
      if (value is Timestamp) {
        return MapEntry(key, value.toDate());
      }
      return MapEntry(key, value);
    });
  }
}
