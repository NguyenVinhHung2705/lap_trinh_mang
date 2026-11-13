import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/adapters/pantry_adapter.dart';
import '../../data/adapters/recipe_shortage_adapter.dart';
import '../../data/models/food_shortage_item.dart';
import '../../data/models/low_stock_suggestion.dart';
import '../../data/models/shopping_item.dart';
import '../../data/models/shopping_list.dart';
import '../../data/shopping_repository.dart';
import '../../domain/shopping_service.dart';
import '../../domain/shopping_sync_service.dart';

// ---------------------------------------------------------------------------
// DEPENDENCY INJECTION PROVIDERS
// ---------------------------------------------------------------------------

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  return ShoppingRepository();
});

final pantryReaderProvider = Provider<PantryReader>((ref) {
  return FirestorePantryAdapter();
});

final pantrySyncWriterProvider = Provider<PantrySyncWriter>((ref) {
  return FirestorePantryAdapter();
});

final recipeShortageReaderProvider = Provider<RecipeShortageReader>((ref) {
  final pantryReader = ref.watch(pantryReaderProvider);
  return FirestoreRecipeShortageAdapter(pantryReader: pantryReader);
});

final shoppingServiceProvider = Provider<ShoppingService>((ref) {
  final repo = ref.watch(shoppingRepositoryProvider);
  final pantryReader = ref.watch(pantryReaderProvider);
  final recipeReader = ref.watch(recipeShortageReaderProvider);

  return ShoppingService(
    shoppingRepository: repo,
    pantryReader: pantryReader,
    recipeShortageReader: recipeReader,
  );
});

final shoppingSyncServiceProvider = Provider<ShoppingSyncService>((ref) {
  final repo = ref.watch(shoppingRepositoryProvider);
  final pantryReader = ref.watch(pantryReaderProvider);
  final pantryWriter = ref.watch(pantrySyncWriterProvider);

  return ShoppingSyncService(
    shoppingRepository: repo,
    pantryReader: pantryReader,
    pantrySyncWriter: pantryWriter,
  );
});

// ---------------------------------------------------------------------------
// STREAMS & DATA PROVIDERS
// ---------------------------------------------------------------------------

/// Streams all shopping lists for the given [userId].
final shoppingListsStreamProvider =
    StreamProvider.family<List<ShoppingList>, String>((ref, userId) {
  final repo = ref.watch(shoppingRepositoryProvider);
  return repo.watchShoppingLists(userId: userId);
});

/// Streams items for a specific shopping list.
final shoppingItemsStreamProvider = StreamProvider.family<List<ShoppingItem>,
    ({String userId, String listId})>((ref, arg) {
  final repo = ref.watch(shoppingRepositoryProvider);
  return repo.watchItems(userId: arg.userId, listId: arg.listId);
});

/// Fetches storage locations for the given user.
final storageLocationsProvider =
    FutureProvider.family<List<StorageLocationInfo>, String>((ref, userId) {
  final reader = ref.watch(pantryReaderProvider);
  return reader.getStorageLocations(userId);
});

/// Fetches available food items for manual adding.
final pantryFoodsProvider =
    FutureProvider.family<List<PantryFoodInfo>, String>((ref, userId) {
  final reader = ref.watch(pantryReaderProvider);
  return reader.getFoods(userId);
});

/// Fetches measurement units.
final measurementUnitsProvider =
    FutureProvider<List<MeasurementUnitInfo>>((ref) {
  final reader = ref.watch(pantryReaderProvider);
  return reader.getUnits();
});

// ---------------------------------------------------------------------------
// CONTROLLERS
// ---------------------------------------------------------------------------

/// Controller for shopping list management (MOD-02-01).
class ShoppingListController extends StateNotifier<AsyncValue<void>> {
  ShoppingListController(this._service) : super(const AsyncValue.data(null));

  final ShoppingService _service;

  Future<ShoppingList?> createList({
    required String userId,
    required String name,
    String? note,
  }) async {
    state = const AsyncValue.loading();
    try {
      final list = await _service.createList(
        userId: userId,
        name: name,
        note: note,
      );
      state = const AsyncValue.data(null);
      return list;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> renameList({
    required String userId,
    required String listId,
    required String newName,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _service.renameList(
        userId: userId,
        listId: listId,
        newName: newName,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteList({
    required String userId,
    required String listId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _service.deleteList(userId: userId, listId: listId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final shoppingListControllerProvider =
    StateNotifierProvider<ShoppingListController, AsyncValue<void>>((ref) {
  final service = ref.watch(shoppingServiceProvider);
  return ShoppingListController(service);
});

/// Controller for shopping mode (MOD-02-05 & MOD-02-06).
class ShoppingModeState {
  const ShoppingModeState({
    this.selectedCategory = 'Tất cả',
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
  });

  final String selectedCategory;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  ShoppingModeState copyWith({
    String? selectedCategory,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ShoppingModeState(
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ShoppingModeController extends StateNotifier<ShoppingModeState> {
  ShoppingModeController(this._service) : super(const ShoppingModeState());

  final ShoppingService _service;

  void selectCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void updateSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<bool> toggleBought({
    required String userId,
    required String listId,
    required String itemId,
    required bool isBought,
  }) async {
    try {
      await _service.toggleItemBought(
        userId: userId,
        listId: listId,
        itemId: itemId,
        isBought: isBought,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateActualQuantity({
    required String userId,
    required String listId,
    required String itemId,
    required double actualQuantity,
    required DateTime expiryDate,
    required String locationId,
    required String locationName,
  }) async {
    try {
      await _service.updateItemActualDetails(
        userId: userId,
        listId: listId,
        itemId: itemId,
        actualQuantity: actualQuantity,
        expiryDate: expiryDate,
        locationId: locationId,
        locationName: locationName,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

final shoppingModeControllerProvider =
    StateNotifierProvider<ShoppingModeController, ShoppingModeState>((ref) {
  final service = ref.watch(shoppingServiceProvider);
  return ShoppingModeController(service);
});

/// Controller for suggestions (MOD-02-03 Recipe Shortages & MOD-02-04 Low Stock).
class ShoppingSuggestionsController
    extends StateNotifier<AsyncValue<List<dynamic>>> {
  ShoppingSuggestionsController(this._service)
      : super(const AsyncValue.data([]));

  final ShoppingService _service;

  Future<List<FoodShortageItem>> loadRecipeShortages({
    required String userId,
    required String listId,
    required String recipeId,
    required double servings,
  }) async {
    state = const AsyncValue.loading();
    try {
      final items = await _service.getRecipeShortagesPreview(
        userId: userId,
        listId: listId,
        recipeId: recipeId,
        desiredServings: servings,
      );
      state = AsyncValue.data(items);
      return items;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return [];
    }
  }

  Future<int> importShortages({
    required String userId,
    required String listId,
    required List<FoodShortageItem> shortages,
  }) async {
    state = const AsyncValue.loading();
    try {
      final count = await _service.importApprovedShortages(
        userId: userId,
        listId: listId,
        approvedShortages: shortages,
      );
      state = const AsyncValue.data([]);
      return count;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return 0;
    }
  }

  Future<List<LowStockSuggestion>> loadLowStockSuggestions({
    required String userId,
    required String listId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final items = await _service.getLowStockSuggestions(
        userId: userId,
        listId: listId,
      );
      state = AsyncValue.data(items);
      return items;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return [];
    }
  }

  Future<int> importLowStockSuggestions({
    required String userId,
    required String listId,
    required List<LowStockSuggestion> suggestions,
  }) async {
    state = const AsyncValue.loading();
    try {
      final count = await _service.importApprovedSuggestions(
        userId: userId,
        listId: listId,
        approvedSuggestions: suggestions,
      );
      state = const AsyncValue.data([]);
      return count;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return 0;
    }
  }
}

final shoppingSuggestionsControllerProvider = StateNotifierProvider<
    ShoppingSuggestionsController, AsyncValue<List<dynamic>>>((ref) {
  final service = ref.watch(shoppingServiceProvider);
  return ShoppingSuggestionsController(service);
});

