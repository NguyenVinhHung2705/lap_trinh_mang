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

/// Supabase (PostgreSQL) data access layer for `cong_thuc`, `nguyen_lieu_cong_thuc`, and `cong_thuc_da_luu`.
///
/// Tables (see `SPRINT_FINAL.md`):
/// - `cong_thuc` (id UUID PK, ma_tac_gia, ten, mo_ta, hinh_anh, khau_phan, thoi_gian_nau, loai, created_at)
/// - `nguyen_lieu_cong_thuc` (id UUID PK, cong_thuc_id UUID FK, thuc_pham_id, ten_thuc_pham, don_vi_id, ky_hieu_don_vi, so_luong_co_so)
/// - `cong_thuc_da_luu` (user_id, cong_thuc_id UUID FK, saved_at, PK(user_id, cong_thuc_id))
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

  static bool _isValidUuid(String str) {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(str.trim());
  }

  // ---------------------------------------------------------------------------
  // Row <-> Model serialization helpers
  // ---------------------------------------------------------------------------

  static Map<String, Object?> recipeToRow(Recipe recipe) {
    final row = <String, Object?>{
      'ma_tac_gia': recipe.authorId,
      'ten': recipe.name,
      'mo_ta': recipe.instructions.isNotEmpty ? recipe.instructions : recipe.description,
      'hinh_anh': recipe.imageUrl,
      'khau_phan': recipe.baseServings.round(),
      'thoi_gian_nau': recipe.cookingMinutes,
      'loai': recipe.source == RecipeSource.system ? 'SYSTEM' : 'USER',
    };
    if (_isValidUuid(recipe.id)) {
      row['id'] = recipe.id;
    }
    return row;
  }

  static Recipe recipeFromRow(Map<String, dynamic> row) {
    final id = row['id'] as String;
    final authorId = (row['ma_tac_gia'] as String?) ?? 'system';
    final name = (row['ten'] as String?) ?? 'Công thức';
    final description = row['mo_ta'] as String?;
    final imageUrl = row['hinh_anh'] as String?;
    final servings = ((row['khau_phan'] as num?) ?? 1).toDouble();
    final cookingTime = ((row['thoi_gian_nau'] as num?) ?? 0).toInt();
    final loaiStr = (row['loai'] as String? ?? 'USER').toUpperCase();
    final source = loaiStr == 'SYSTEM' ? RecipeSource.system : RecipeSource.user;
    final visibility = loaiStr == 'SYSTEM'
        ? RecipeVisibility.system
        : (authorId == 'system' ? RecipeVisibility.public : RecipeVisibility.private);
    final createdAt = _toDateTime(row['created_at']);

    return Recipe(
      id: id,
      authorId: authorId,
      name: name,
      description: description,
      instructions: description ?? 'Sơ chế và chế biến theo khẩu phần.',
      imageUrl: imageUrl,
      baseServings: servings,
      cookingMinutes: cookingTime,
      source: source,
      visibility: visibility,
      createdAt: createdAt,
    );
  }

  static Map<String, Object?> ingredientToRow(RecipeIngredient ing, String recipeId) {
    final row = <String, Object?>{
      'cong_thuc_id': recipeId,
      'thuc_pham_id': ing.foodId,
      'ten_thuc_pham': ing.foodName,
      'don_vi_id': ing.unitId,
      'ky_hieu_don_vi': ing.unitSymbol,
      'so_luong_co_so': ing.baseQuantity,
    };
    if (_isValidUuid(ing.id)) {
      row['id'] = ing.id;
    }
    return row;
  }

  static RecipeIngredient ingredientFromRow(Map<String, dynamic> row) {
    final id = row['id'] as String;
    final recipeId = (row['cong_thuc_id'] as String?) ?? '';
    final foodId = (row['thuc_pham_id'] as String?) ?? id;
    final foodName = (row['ten_thuc_pham'] as String?) ?? 'Nguyên liệu';
    final unitId = (row['don_vi_id'] as String?) ?? '';
    final unitSymbol = (row['ky_hieu_don_vi'] as String?) ?? 'g';
    final quantity = ((row['so_luong_co_so'] as num?) ?? 1.0).toDouble();

    return RecipeIngredient(
      id: id,
      recipeId: recipeId,
      foodId: foodId,
      foodName: foodName,
      unitId: unitId,
      unitSymbol: unitSymbol,
      baseQuantity: quantity,
    );
  }

  static DateTime? _toDateTime(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  // ---------------------------------------------------------------------------
  // READ METHODS
  // ---------------------------------------------------------------------------

  /// 1. getAccessibleRecipes: Queries all recipes accessible to [userId] (user created or loai == SYSTEM).
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

      final rows = await _supabase
          .from('cong_thuc')
          .select()
          .or('ma_tac_gia.eq.$userId,loai.eq.SYSTEM');

      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(rows);
      if (data.isEmpty) {
        return _filterMemoryRecipes(
          userId: userId,
          query: query,
          sourceFilter: sourceFilter,
          savedOnly: savedOnly,
        );
      }

      return _filterRows(
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

  /// 2. watchAccessibleRecipes: Streams accessible recipes in real-time using Supabase Realtime.
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
          final rows = await _supabase
              .from('cong_thuc')
              .select()
              .or('ma_tac_gia.eq.$userId,loai.eq.SYSTEM');
          final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(rows);
          if (data.isEmpty) {
            return _filterMemoryRecipes(
              userId: userId,
              query: query,
              sourceFilter: sourceFilter,
              savedOnly: true,
            );
          }
          return _filterRows(
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
          return _filterRows(
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

  /// 3. getRecipeById: Fetches a single recipe by [recipeId].
  Future<Recipe?> getRecipeById(String recipeId) async {
    final memoryRecipe = _memoryRecipes.cast<Recipe?>().firstWhere(
          (r) => r?.id == recipeId,
          orElse: () => null,
        );
    if (!_isValidUuid(recipeId)) return memoryRecipe;

    try {
      final row = await _supabase
          .from('cong_thuc')
          .select()
          .eq('id', recipeId)
          .maybeSingle();
      if (row == null) return memoryRecipe;
      return recipeFromRow(row);
    } catch (_) {
      return memoryRecipe;
    }
  }

  /// 4. getRecipeIngredients: Reads ingredients for a recipe (`nguyen_lieu_cong_thuc`).
  Future<List<RecipeIngredient>> getRecipeIngredients(String recipeId) async {
    final memoryList = _memoryIngredients[recipeId] ?? const [];
    if (!_isValidUuid(recipeId)) return memoryList;

    try {
      final rows = await _supabase
          .from('nguyen_lieu_cong_thuc')
          .select()
          .eq('cong_thuc_id', recipeId);
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(rows);
      if (data.isEmpty) return memoryList;
      return data.map(ingredientFromRow).toList();
    } catch (_) {
      return memoryList;
    }
  }

  /// Streams ingredients for a recipe in real time.
  Stream<List<RecipeIngredient>> watchRecipeIngredients(String recipeId) {
    final memoryList = _memoryIngredients[recipeId] ?? const [];
    if (!_isValidUuid(recipeId)) {
      return Stream.value(memoryList);
    }
    return _supabase
        .from('nguyen_lieu_cong_thuc')
        .stream(primaryKey: ['id'])
        .eq('cong_thuc_id', recipeId)
        .map((rows) {
          final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(rows);
          if (data.isEmpty) return memoryList;
          return data.map(ingredientFromRow).toList();
        })
        .handleError((_) => memoryList);
  }

  // ---------------------------------------------------------------------------
  // WRITE METHODS (CREATE / UPDATE / DELETE)
  // ---------------------------------------------------------------------------

  /// 5. createRecipe: Creates a new recipe and writes its ingredient entries.
  Future<Recipe> createRecipe({
    required Recipe recipe,
    required List<RecipeIngredient> ingredients,
  }) async {
    String createdId = recipe.id;
    Recipe persistedRecipe = recipe;

    if (_isMockUser(recipe.authorId)) {
      final memId = recipe.id == 'new' || recipe.id.isEmpty
          ? 'recipe_${DateTime.now().millisecondsSinceEpoch}'
          : recipe.id;
      persistedRecipe = recipe.copyWith(id: memId);
      _memoryRecipes.insert(0, persistedRecipe);
      _memoryIngredients[memId] = ingredients
          .map((i) => i.copyWith(
                id: i.id == 'new' || i.id.isEmpty
                    ? 'ing_${DateTime.now().microsecondsSinceEpoch}_${i.foodId}'
                    : i.id,
                recipeId: memId,
              ))
          .toList();
      return persistedRecipe;
    }

    try {
      final rowMap = recipeToRow(recipe);
      final createdRow = await _supabase
          .from('cong_thuc')
          .insert(rowMap)
          .select()
          .single();

      createdId = createdRow['id'] as String;
      persistedRecipe = recipeFromRow(createdRow);

      // Insert ingredient rows with foreign key cong_thuc_id = createdId
      final persistedIngredients = <RecipeIngredient>[];
      for (final ing in ingredients) {
        final ingRow = ingredientToRow(ing, createdId);
        final createdIngRow = await _supabase
            .from('nguyen_lieu_cong_thuc')
            .insert(ingRow)
            .select()
            .single();
        persistedIngredients.add(ingredientFromRow(createdIngRow));
      }

      // Sync memory cache
      _memoryRecipes.insert(0, persistedRecipe);
      _memoryIngredients[createdId] = persistedIngredients;
    } catch (_) {
      // Fallback to local memory on network error
      final fallbackId = recipe.id == 'new' || recipe.id.isEmpty
          ? 'recipe_${DateTime.now().millisecondsSinceEpoch}'
          : recipe.id;
      persistedRecipe = recipe.copyWith(id: fallbackId);
      _memoryRecipes.insert(0, persistedRecipe);
      _memoryIngredients[fallbackId] = ingredients
          .map((i) => i.copyWith(recipeId: fallbackId))
          .toList();
    }

    return persistedRecipe;
  }

  /// 6. updateRecipe: Updates an existing recipe and synchronizes ingredients.
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

    if (_isMockUser(userId) || !_isValidUuid(recipe.id)) return;

    final existing = await getRecipeById(recipe.id);
    if (existing == null) {
      throw const RecipeNotFoundException();
    }
    if (!existing.isAuthor(userId)) {
      throw const RecipePermissionDeniedException();
    }

    try {
      // Update the recipe row
      await _supabase
          .from('cong_thuc')
          .update(recipeToRow(recipe))
          .eq('id', recipe.id);

      // Delete old ingredients
      await _supabase
          .from('nguyen_lieu_cong_thuc')
          .delete()
          .eq('cong_thuc_id', recipe.id);

      // Re-insert updated ingredients
      for (final ing in ingredients) {
        await _supabase
            .from('nguyen_lieu_cong_thuc')
            .insert(ingredientToRow(ing, recipe.id));
      }
    } catch (_) {
      // Offline fallback
    }
  }

  /// 7. deleteRecipe: Deletes a recipe and all its ingredient entries.
  Future<void> deleteRecipe({
    required String userId,
    required String recipeId,
  }) async {
    _memoryRecipes.removeWhere((r) => r.id == recipeId);
    _memoryIngredients.remove(recipeId);

    if (_isMockUser(userId) || !_isValidUuid(recipeId)) return;

    final existing = await getRecipeById(recipeId);
    if (existing == null) {
      throw const RecipeNotFoundException();
    }
    if (!existing.isAuthor(userId)) {
      throw const RecipePermissionDeniedException();
    }

    try {
      // Delete ingredients first
      await _supabase
          .from('nguyen_lieu_cong_thuc')
          .delete()
          .eq('cong_thuc_id', recipeId);

      // Delete recipe
      await _supabase
          .from('cong_thuc')
          .delete()
          .eq('id', recipeId);
    } catch (_) {
      // Offline fallback
    }
  }

  // ---------------------------------------------------------------------------
  // BOOKMARK / SAVED RECIPES (cong_thuc_da_luu)
  // ---------------------------------------------------------------------------

  /// 8. toggleSaveRecipe: Bookmarks or un-bookmarks a recipe for [userId] (`cong_thuc_da_luu`).
  Future<bool> toggleSaveRecipe({
    required String userId,
    required String recipeId,
  }) async {
    final userSaved = _memorySavedIds.putIfAbsent(userId, () => <String>{});
    final isCurrentlySaved = userSaved.contains(recipeId);

    if (isCurrentlySaved) {
      userSaved.remove(recipeId);
    } else {
      userSaved.add(recipeId);
    }

    if (_isMockUser(userId) || !_isValidUuid(recipeId)) {
      return !isCurrentlySaved;
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

  /// 9. getSavedRecipeIds: Gets list of saved recipe IDs for [userId].
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
      // Non-fatal
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

  List<Recipe> _filterRows(
    List<Map<String, dynamic>> rows, {
    required String userId,
    required String query,
    RecipeSource? sourceFilter,
    List<String>? savedIds,
  }) {
    final lowerQuery = query.trim().toLowerCase();
    final result = <Recipe>[];

    for (final row in rows) {
      final recipe = recipeFromRow(row);

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
