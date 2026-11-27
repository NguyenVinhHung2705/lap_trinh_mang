import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/food_shortage_item.dart';
import 'pantry_adapter.dart';

/// Contract for calculating or retrieving ingredient shortages from recipes (`MOD-03`).
abstract interface class RecipeShortageReader {
  /// Analyzes ingredient shortages for a given recipe and serving count.
  ///
  /// Formula:
  /// - Needed = (baseQuantity * servings) / baseServings
  /// - UsableStock = SUM(so_luong_nhap) - SUM(so_luong_xuat) for unexpired batches
  /// - Shortage = max(0, Needed - UsableStock)
  Future<List<FoodShortageItem>> getShortagesForRecipe({
    required String userId,
    required String recipeId,
    required double desiredServings,
  });

  /// Lists available recipes with shortages for quick selection.
  Future<List<Map<String, dynamic>>> getRecipesWithShortages(String userId);
}

/// Supabase implementation connecting to MOD-03 (`cong_thuc`, `nguyen_lieu_cong_thuc`).
class SupabaseRecipeShortageAdapter implements RecipeShortageReader {
  SupabaseRecipeShortageAdapter({
    SupabaseClient? supabase,
    PantryReader? pantryReader,
  })  : _customSupabase = supabase,
        _pantryReader = pantryReader ??
            SupabasePantryAdapter(
              supabase: supabase,
            );

  final SupabaseClient? _customSupabase;
  SupabaseClient get _supabase =>
      _customSupabase ?? Supabase.instance.client;
  final PantryReader _pantryReader;

  @override
  Future<List<FoodShortageItem>> getShortagesForRecipe({
    required String userId,
    required String recipeId,
    required double desiredServings,
  }) async {
    // 1. Fetch recipe row
    final recipeRow = await _supabase
        .from('cong_thuc')
        .select()
        .eq('id', recipeId)
        .maybeSingle();

    if (recipeRow == null) {
      return [];
    }

    final recipeName = recipeRow['ten'] as String? ?? 'Món ăn';
    final baseServings = (recipeRow['khau_phan'] as num?)?.toDouble() ?? 1.0;
    final scaleFactor = desiredServings / (baseServings > 0 ? baseServings : 1.0);

    // 2. Fetch recipe ingredients
    final ingredientRows = await _supabase
        .from('nguyen_lieu_cong_thuc')
        .select()
        .eq('cong_thuc_id', recipeId);

    final shortages = <FoodShortageItem>[];
    final today = DateTime.now();

    for (final row in (ingredientRows as List)) {
      final ingData = row as Map<String, dynamic>;
      final foodId = ingData['thuc_pham_id']?.toString() ?? ingData['id']?.toString() ?? '';
      final foodName = ingData['ten_thuc_pham'] as String? ?? 'Nguyên liệu';
      final unitId = ingData['don_vi_id']?.toString() ?? '1';
      final unitName = ingData['ky_hieu_don_vi'] as String? ?? 'đơn vị';
      final baseQty = (ingData['so_luong_co_so'] as num?)?.toDouble() ?? 0.0;
      final neededQty = baseQty * scaleFactor;

      if (neededQty <= 0) continue;

      // 3. Query usable pantry stock from MOD-01
      final usableStock = await _pantryReader.getUsableStockForFood(
        userId: userId,
        foodId: foodId,
        referenceDate: today,
      );

      final shortage = neededQty - usableStock;
      // FR-11: Chỉ nhận các nguyên liệu có lượng thiếu lớn hơn 0
      if (shortage > 0) {
        shortages.add(
          FoodShortageItem(
            recipeId: recipeId,
            recipeName: recipeName,
            foodId: foodId,
            foodName: foodName,
            unitId: unitId,
            unitName: unitName,
            shortageQuantity: shortage,
            approvedQuantity: shortage,
            isSelected: true,
          ),
        );
      }
    }

    return shortages;
  }

  @override
  Future<List<Map<String, dynamic>>> getRecipesWithShortages(String userId) async {
    final rows = await _supabase
        .from('cong_thuc')
        .select()
        .limit(20);

    return (rows as List).map((row) {
      final d = row as Map<String, dynamic>;
      return {
        'id': d['id'],
        'name': d['ten'] ?? 'Món ăn',
        'servings': (d['khau_phan'] as num?)?.toDouble() ?? 1.0,
      };
    }).toList();
  }
}
