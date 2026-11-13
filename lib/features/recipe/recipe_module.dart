import 'package:flutter/material.dart';

import 'presentation/screens/recipe_detail_screen.dart';
import 'presentation/screens/recipe_editor_screen.dart';
import 'presentation/screens/recipe_list_screen.dart';

/// Public interface and navigation entrypoints for `MOD-03: Recipe Management`.
class RecipeModule {
  const RecipeModule._();

  /// Route name for the recipe catalog library (Bottom Nav Tab 3: "Công thức").
  static const String listRoute = '/recipe/list';

  /// Route name for recipe detail screen.
  static const String detailRoute = '/recipe/detail';

  /// Route name for recipe editor screen (Create / Edit).
  static const String editorRoute = '/recipe/editor';

  /// Creates the primary recipe list screen widget for embedding in Tab 3 or standalone.
  static Widget buildRecipeListScreen() {
    return const RecipeListScreen();
  }

  /// Opens the recipe detail screen for [recipeId].
  static Future<void> openRecipeDetail(
    BuildContext context, {
    required String recipeId,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(recipeId: recipeId),
      ),
    );
  }

  /// Opens the recipe editor screen for creating (recipeId == null) or editing.
  static Future<void> openRecipeEditor(
    BuildContext context, {
    String? recipeId,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeEditorScreen(recipeId: recipeId),
      ),
    );
  }
}
