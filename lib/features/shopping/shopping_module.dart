import 'package:flutter/material.dart';

import 'data/models/shopping_item.dart';
import 'data/models/shopping_list.dart';
import 'presentation/screens/add_edit_shopping_item_screen.dart';
import 'presentation/screens/shopping_detail_screen.dart';
import 'presentation/screens/shopping_mode_screen.dart';
import 'presentation/screens/shopping_screen.dart';
import 'presentation/screens/shopping_sync_screen.dart';

/// Public interface and navigation entrypoints for `MOD-02: Shopping Management`.
class ShoppingModule {
  const ShoppingModule._();

  /// Route name for the shopping overview screen (Bottom Nav Tab / Dashboard Quick Action).
  static const String shoppingRoute = '/shopping';

  /// Route name for shopping list detail screen.
  static const String detailRoute = '/shopping/detail';

  /// Route name for supermarket in-store shopping mode.
  static const String modeRoute = '/shopping/mode';

  /// Route name for pantry synchronization screen.
  static const String syncRoute = '/shopping/sync';

  /// Creates the primary shopping overview widget.
  static Widget buildShoppingScreen({
    String? userId,
    ValueChanged<ShoppingList>? onSelectList,
  }) {
    return ShoppingScreen(
      userId: userId,
      onSelectList: onSelectList,
    );
  }

  /// Opens the detail screen for a specific shopping list.
  static Future<void> openShoppingDetail(
    BuildContext context, {
    required String userId,
    required String listId,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShoppingDetailScreen(
          userId: userId,
          listId: listId,
        ),
      ),
    );
  }

  /// Opens in-store shopping mode (MOD-02-05).
  static Future<void> openShoppingMode(
    BuildContext context, {
    required String userId,
    required String listId,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShoppingModeScreen(
          userId: userId,
          listId: listId,
        ),
      ),
    );
  }

  /// Opens pantry synchronization screen (MOD-02-08).
  static Future<void> openShoppingSync(
    BuildContext context, {
    required String userId,
    required String listId,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShoppingSyncScreen(
          userId: userId,
          listId: listId,
        ),
      ),
    );
  }

  /// Opens manual item creation or editing form (MOD-02-02).
  static Future<void> openAddEditItem(
    BuildContext context, {
    required String userId,
    required String listId,
    ShoppingItem? item,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditShoppingItemScreen(
          userId: userId,
          listId: listId,
          editingItem: item,
        ),
      ),
    );
  }
}

