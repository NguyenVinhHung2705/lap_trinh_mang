import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Supabase data access layer for `cong_thuc`, `nguyen_lieu_cong_thuc`, and `cong_thuc_da_luu`.
///
/// Tables:
/// - `cong_thuc` (id UUID PK, ma_tac_gia, ten, mo_ta, hinh_anh, khau_phan, thoi_gian_nau, loai, created_at)
/// - `nguyen_lieu_cong_thuc` (id UUID PK, cong_thuc_id FK, thuc_pham_id, ten_thuc_pham, don_vi_id, ky_hieu_don_vi, so_luong_co_so)
/// - `cong_thuc_da_luu` (user_id, cong_thuc_id FK, saved_at, PK(user_id, cong_thuc_id))
class RecipeRepository {
  RecipeRepository({SupabaseClient? supabase})
      : _customClient = supabase;

  final SupabaseClient? _customClient;
  SupabaseClient get _supabase =>
      _customClient ?? Supabase.instance.client;

  // In-memory fallback / mock store for offline & guest usage
  static final List<Recipe> _memoryRecipes = List<Recipe>.from(RecipeMockData.initialRecipes);
  static final Map<String, List<RecipeIngredient>> _memoryIngredients =
      RecipeMockData.initialIngredients.map((k, v) => MapEntry(k, List<RecipeIngredient>.from(v)));
  static final Map<String, Set<String>> _memorySavedIds = {};

  bool _isMockUser(String userId) {
    return userId.isEmpty || userId.startsWith('mock_') || userId.startsWith('guest_');
  }

  /// Normalizes a Supabase row map — converts ISO-8601 date strings to DateTime.
  Map<String, Object?> _normalizeMap(Map<String, dynamic> raw) {
    return raw.map((key, value) {
      if (value is String) {
        // Attempt to parse ISO 8601 timestamps
        final dt = DateTime.tryParse(value);
        if (dt != null && (key.contains('created_at') || key.contains('updated_at') || key.contains('saved_at'))) {
          return MapEntry(key, dt);
        }
      }
      return MapEntry(key, value);
    });
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

      final rows = await _supabase.from('cong_thuc').select();
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(rows);
      if (data.isEmpty) {
        // Fallback to mock data if Supabase is empty
        return _filterMemoryRecipes(
          userId: userId,
          query: query,
          sourceFilter: sourceFilter,
          savedOnly: savedOnly,
        );
      }

      return _filterRecipes(
        data,
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
        try {
          final rows = await _supabase.from('cong_thuc').select();
          final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(rows);
          if (data.isEmpty) {
            return _filterMemoryRecipes(
              userId: userId,
              query: query,
              sourceFilter: sourceFilter,
              savedOnly: true,
            );
          }
          return _filterRecipes(
            data,
            userId: userId,
            query: query,
            sourceFilter: sourceFilter,
            savedIds: savedIds,
          );
        } catch (_) {
          return _filterMemoryRecipes(
            userId: userId,
            query: query,
            sourceFilter: sourceFilter,
            savedOnly: true,
          );
        }
      }).handleError((_) {
        return _filterMemoryRecipes(
          userId: userId,
          query: query,
          sourceFilter: sourceFilter,
          savedOnly: savedOnly,
        );
      });
    }

    return _supabase
        .from('cong_thuc')
        .stream(primaryKey: ['id'])
        .map((rows) {
          final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(rows);
          if (data.isEmpty) {
            return _filterMemoryRecipes(
              userId: userId,
              query: query,
              sourceFilter: sourceFilter,
            );
          }
          return _filterRecipes(
            data,
            userId: userId,
            query: query,
            sourceFilter: sourceFilter,
          );
        })
        .handleError((_) {
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
      final row = await _supabase
          .from('cong_thuc')
          .select()
          .eq('id', recipeId)
          .maybeSingle();
      if (row == null) return memoryRecipe;
      return Recipe.fromMap(_normalizeMap(row), id: row['id'] as String);
    } catch (_) {
      return memoryRecipe;
    }
  }

  /// Reads ingredients for a recipe (`nguyen_lieu_cong_thuc`).
  Future<List<RecipeIngredient>> getRecipeIngredients(String recipeId) async {
    final memoryList = _memoryIngredients[recipeId] ?? const [];
    try {
      final rows = await _supabase
          .from('nguyen_lieu_cong_thuc')
          .select()
          .eq('cong_thuc_id', recipeId);
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(rows);
      if (data.isEmpty) return memoryList;
      return data
          .map(
            (row) => RecipeIngredient.fromMap(
              _normalizeMap(row),
              id: row['id'] as String,
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
    return _supabase
        .from('nguyen_lieu_cong_thuc')
        .stream(primaryKey: ['id'])
        .eq('cong_thuc_id', recipeId)
        .map((rows) {
          final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(rows);
          if (data.isEmpty) return memoryList;
          return data
              .map(
                (row) => RecipeIngredient.fromMap(
                  _normalizeMap(row),
                  id: row['id'] as String,
                ),
              )
              .toList();
        })
        .handleError((_) => memoryList);
  }

  /// Creates a new recipe and writes its ingredients.
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
      // Insert the recipe row
      await _supabase.from('cong_thuc').upsert({
        ...persistedRecipe.toMap(),
        'id': newId,
      });

      // Insert all ingredient rows
      for (final ing in _memoryIngredients[newId]!) {
        await _supabase.from('nguyen_lieu_cong_thuc').upsert({
          ...ing.toMap(),
          'id': ing.id,
          'cong_thuc_id': newId,
        });
      }
    } catch (_) {
      // Ignored for offline mode
    }

    return persistedRecipe;
  }

  /// Updates an existing recipe and synchronizes ingredients.
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

    // Update the recipe row
    await _supabase
        .from('cong_thuc')
        .update(recipe.toMap())
        .eq('id', recipe.id);

    // Delete existing ingredients and replace with new set
    await _supabase
        .from('nguyen_lieu_cong_thuc')
        .delete()
        .eq('cong_thuc_id', recipe.id);

    for (final ing in ingredients) {
      final ingId = ing.foodId;
      final persistedIng = ing.copyWith(id: ingId, recipeId: recipe.id);
      await _supabase.from('nguyen_lieu_cong_thuc').insert({
        ...persistedIng.toMap(),
        'id': ingId,
        'cong_thuc_id': recipe.id,
      });
    }
  }

  /// Deletes a recipe and all its ingredient entries.
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

    // Delete ingredients first (FK dependency)
    await _supabase
        .from('nguyen_lieu_cong_thuc')
        .delete()
        .eq('cong_thuc_id', recipeId);

    // Delete the recipe
    await _supabase
        .from('cong_thuc')
        .delete()
        .eq('id', recipeId);
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
      final existing = await _supabase
          .from('cong_thuc_da_luu')
          .select()
          .eq('user_id', userId)
          .eq('cong_thuc_id', recipeId)
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('cong_thuc_da_luu')
            .delete()
            .eq('user_id', userId)
            .eq('cong_thuc_id', recipeId);
        return false;
      } else {
        await _supabase.from('cong_thuc_da_luu').insert({
          'user_id': userId,
          'cong_thuc_id': recipeId,
          'saved_at': DateTime.now().toUtc().toIso8601String(),
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
      final rows = await _supabase
          .from('cong_thuc_da_luu')
          .select('cong_thuc_id')
          .eq('user_id', userId);
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(rows);
      return data.map((row) => row['cong_thuc_id'] as String).toList();
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
    return _supabase
        .from('cong_thuc_da_luu')
        .stream(primaryKey: ['user_id', 'cong_thuc_id'])
        .eq('user_id', userId)
        .map((rows) => rows.map((row) => row['cong_thuc_id'] as String).toList())
        .handleError((_) => memoryList);
  }

  /// Seeds initial recipes into Supabase if the table is empty.
  Future<void> seedInitialRecipesIfEmpty() async {
    try {
      final rows = await _supabase.from('cong_thuc').select().limit(1);
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(rows);
      if (data.isEmpty) {
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
    List<Map<String, dynamic>> rows, {
    required String userId,
    required String query,
    RecipeSource? sourceFilter,
    List<String>? savedIds,
  }) {
    final lowerQuery = query.trim().toLowerCase();
    final result = <Recipe>[];

    for (final row in rows) {
      final recipe = Recipe.fromMap(_normalizeMap(row), id: row['id'] as String);

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
}
