import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/recipe.dart';
import 'models/recipe_ingredient.dart';

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
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
    List<String> savedIds = const [];
    if (savedOnly) {
      savedIds = await getSavedRecipeIds(userId);
      if (savedIds.isEmpty) return const [];
    }

    final snapshot = await _recipesRef.get();
    return _filterRecipes(
      snapshot.docs,
      userId: userId,
      query: query,
      sourceFilter: sourceFilter,
      savedIds: savedOnly ? savedIds : null,
    );
  }

  /// Streams accessible recipes in real-time.
  Stream<List<Recipe>> watchAccessibleRecipes({
    required String userId,
    String query = '',
    RecipeSource? sourceFilter,
    bool savedOnly = false,
  }) {
    if (savedOnly) {
      return watchSavedRecipeIds(userId).asyncMap((savedIds) async {
        if (savedIds.isEmpty) return const <Recipe>[];
        final snapshot = await _recipesRef.get();
        return _filterRecipes(
          snapshot.docs,
          userId: userId,
          query: query,
          sourceFilter: sourceFilter,
          savedIds: savedIds,
        );
      });
    }

    return _recipesRef.snapshots().map(
          (snapshot) => _filterRecipes(
            snapshot.docs,
            userId: userId,
            query: query,
            sourceFilter: sourceFilter,
          ),
        );
  }

  /// Fetches a single recipe by [recipeId].
  Future<Recipe?> getRecipeById(String recipeId) async {
    final doc = await _recipeDoc(recipeId).get();
    if (!doc.exists || doc.data() == null) return null;
    return Recipe.fromMap(_normalizeMap(doc.data()!), id: doc.id);
  }

  /// Reads ingredients for a recipe (`nguyen_lieu_cong_thuc`).
  Future<List<RecipeIngredient>> getRecipeIngredients(String recipeId) async {
    final snapshot = await _ingredientsRef(recipeId).get();
    return snapshot.docs
        .map(
          (doc) => RecipeIngredient.fromMap(
            _normalizeMap(doc.data()),
            id: doc.id,
          ),
        )
        .toList();
  }

  /// Streams ingredients for a recipe in real time.
  Stream<List<RecipeIngredient>> watchRecipeIngredients(String recipeId) {
    return _ingredientsRef(recipeId).snapshots().map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => RecipeIngredient.fromMap(
                  _normalizeMap(doc.data()),
                  id: doc.id,
                ),
              )
              .toList(),
        );
  }

  /// Creates a new recipe and writes its ingredient subcollection atomically.
  Future<Recipe> createRecipe({
    required Recipe recipe,
    required List<RecipeIngredient> ingredients,
  }) async {
    final docRef = recipe.id == 'new' || recipe.id.isEmpty
        ? _recipesRef.doc()
        : _recipeDoc(recipe.id);

    final persistedRecipe = recipe.copyWith(id: docRef.id);

    final batch = _firestore.batch();
    batch.set(docRef, persistedRecipe.toMap());

    for (final ing in ingredients) {
      final ingRef = ing.id == 'new' || ing.id.isEmpty
          ? _ingredientsRef(docRef.id).doc(ing.foodId)
          : _ingredientsRef(docRef.id).doc(ing.id);
      final persistedIng = ing.copyWith(id: ingRef.id, recipeId: docRef.id);
      batch.set(ingRef, persistedIng.toMap());
    }

    await batch.commit();
    return persistedRecipe;
  }

  /// Updates an existing recipe and synchronizes ingredients subcollection.
  Future<void> updateRecipe({
    required String userId,
    required Recipe recipe,
    required List<RecipeIngredient> ingredients,
  }) async {
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
    final docRef = _savedRef(userId).doc(recipeId);
    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.delete();
      return false; // Now un-saved
    } else {
      await docRef.set({
        'ma_cong_thuc': recipeId,
        'ngay_luu': DateTime.now().toIso8601String(),
      });
      return true; // Now saved
    }
  }

  /// Gets list of saved recipe IDs for [userId].
  Future<List<String>> getSavedRecipeIds(String userId) async {
    final snap = await _savedRef(userId).get();
    return snap.docs.map((doc) => doc.id).toList();
  }

  /// Streams list of saved recipe IDs for real-time bookmark toggles.
  Stream<List<String>> watchSavedRecipeIds(String userId) {
    return _savedRef(userId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.id).toList());
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
