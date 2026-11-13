import 'package:cloud_firestore/cloud_firestore.dart';

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

/// Firestore implementation connecting to MOD-03 (`cong_thuc`, `nguyen_lieu_cong_thuc`).
class FirestoreRecipeShortageAdapter implements RecipeShortageReader {
  FirestoreRecipeShortageAdapter({
    FirebaseFirestore? firestore,
    PantryReader? pantryReader,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _pantryReader = pantryReader ??
            FirestorePantryAdapter(
              firestore: firestore ?? FirebaseFirestore.instance,
            );

  final FirebaseFirestore _firestore;
  final PantryReader _pantryReader;

  @override
  Future<List<FoodShortageItem>> getShortagesForRecipe({
    required String userId,
    required String recipeId,
    required double desiredServings,
  }) async {
    // 1. Fetch recipe doc
    DocumentSnapshot<Map<String, dynamic>> recipeSnap =
        await _firestore.collection('cong_thuc').doc(recipeId).get();

    if (!recipeSnap.exists) {
      recipeSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('cong_thuc')
          .doc(recipeId)
          .get();
    }

    if (!recipeSnap.exists || recipeSnap.data() == null) {
      return [];
    }

    final recipeData = recipeSnap.data()!;
    final recipeName = recipeData['ten_mon'] as String? ?? 'Món ăn';
    final baseServings = (recipeData['khau_phan'] as num?)?.toDouble() ?? 1.0;
    final scaleFactor = desiredServings / (baseServings > 0 ? baseServings : 1.0);

    // 2. Fetch recipe ingredients
    final ingredientsSnap = await recipeSnap.reference
        .collection('nguyen_lieu_cong_thuc')
        .get();

    final shortages = <FoodShortageItem>[];
    final today = DateTime.now();

    for (final doc in ingredientsSnap.docs) {
      final ingData = doc.data();
      final foodId = ingData['ma_thuc_pham']?.toString() ?? doc.id;
      final foodName = ingData['ten_thuc_pham'] as String? ?? 'Nguyên liệu';
      final unitId = ingData['ma_don_vi']?.toString() ?? '1';
      final unitName = ingData['ten_don_vi'] as String? ?? 'đơn vị';
      final baseQty = (ingData['so_luong'] as num?)?.toDouble() ?? 0.0;
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
    final snapshot = await _firestore.collection('cong_thuc').limit(20).get();
    return snapshot.docs.map((doc) {
      final d = doc.data();
      return {
        'id': doc.id,
        'name': d['ten_mon'] ?? 'Món ăn',
        'servings': (d['khau_phan'] as num?)?.toDouble() ?? 1.0,
      };
    }).toList();
  }
}

