import 'models/recipe.dart';
import 'models/recipe_ingredient.dart';

/// Mock data cho phân hệ MOD-03: Công thức nấu ăn (Nguyễn Khang Hy)
/// Phục vụ chế độ Local / Khách và làm hạt giống (seed data) đẩy lên Firestore.
class RecipeMockData {
  const RecipeMockData._();

  static final List<Recipe> initialRecipes = [
    Recipe(
      id: 'recipe_pho_bo',
      authorId: 'system',
      name: 'Phở bò tái truyền thống',
      description: 'Món phở bò thơm ngon, đậm đà hương vị truyền thống Hà Nội.',
      instructions:
          '1. Nấu nước dùng từ xương bò với quế, hồi, thảo quả trong 4-6 giờ.\n2. Trụng bánh phở vào tô.\n3. Xếp thịt bò tái mỏng lên trên cùng hành tây và hành hoa.\n4. Chan nước dùng sôi sùng sục và thưởng thức kèm chanh, ớt.',
      imageUrl: 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=800',
      baseServings: 2,
      cookingMinutes: 45,
      source: RecipeSource.system,
      visibility: RecipeVisibility.public,
    ),
    Recipe(
      id: 'recipe_com_tam',
      authorId: 'system',
      name: 'Cơm tấm sườn nướng chả trứng',
      description: 'Đặc sản Sài Gòn với sườn nướng mỡ hành đậm vị, chả trứng bùi béo.',
      instructions:
          '1. Ướp sườn với sả, mật ong, nước mắm, tiêu trong ít nhất 1 giờ.\n2. Nướng sườn trên than hoa hoặc nồi chiên không dầu ở 180°C.\n3. Hấp chả trứng thịt băm mộc nhĩ.\n4. Đơm cơm tấm ra đĩa, xếp sườn, chả, dưa leo, chan mỡ hành và nước mắm chua ngọt.',
      imageUrl: 'https://images.unsplash.com/photo-1594998893017-36147cbcae05?w=800',
      baseServings: 1,
      cookingMinutes: 35,
      source: RecipeSource.system,
      visibility: RecipeVisibility.public,
    ),
    Recipe(
      id: 'recipe_canh_chua',
      authorId: 'system',
      name: 'Canh chua cá lóc Nam Bộ',
      description: 'Món canh giải nhiệt thanh mát với vị chua dịu của me và mùi thơm ngò gai.',
      instructions:
          '1. Làm sạch cá lóc, cắt khúc vừa ăn.\n2. Nấu nước me lọc lấy cốt chua.\n3. Cho cá vào nấu chín rồi thêm dứa, cà chua, đậu bắp, bạc hà.\n4. Nêm gia vị vừa ăn, rắc giá đỗ, ngò gai, ớt sừng cắt lát trước khi tắt bếp.',
      imageUrl: 'https://images.unsplash.com/photo-1547592180-85f173990554?w=800',
      baseServings: 4,
      cookingMinutes: 25,
      source: RecipeSource.system,
      visibility: RecipeVisibility.public,
    ),
    Recipe(
      id: 'recipe_trung_cuon',
      authorId: 'system',
      name: 'Trứng cuộn hành hoa',
      description: 'Món ăn gia đình nhanh gọn, giàu đạm và dễ chế biến cho bữa sáng.',
      instructions:
          '1. Đập 3 quả trứng vào bát, thêm hành hoa cắt nhỏ, chút nước mắm và tiêu.\n2. Đánh tan đều hỗn hợp.\n3. Đun nóng chảo chống dính với chút dầu, đổ từng lớp trứng mỏng rồi cuộn tròn lại.\n4. Cắt khoanh vừa ăn và dùng kèm cơm nóng.',
      imageUrl: 'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=800',
      baseServings: 2,
      cookingMinutes: 10,
      source: RecipeSource.system,
      visibility: RecipeVisibility.public,
    ),
    Recipe(
      id: 'recipe_salad_uc_ga',
      authorId: 'system',
      name: 'Salad ức gà sốt mè rang',
      description: 'Món ăn healthy giàu protein, ít calo cho người tập luyện và ăn kiêng.',
      instructions:
          '1. Luộc hoặc áp chảo ức gà với chút muối và tiêu, sau đó xé phay.\n2. Rửa sạch các loại xà lách, cà chua bi, dưa leo.\n3. Trộn rau và ức gà vào tô lớn.\n4. Rưới sốt mè rang lên trên và rắc chút hạt mè thơm.',
      imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800',
      baseServings: 2,
      cookingMinutes: 15,
      source: RecipeSource.system,
      visibility: RecipeVisibility.public,
    ),
  ];

  static final Map<String, List<RecipeIngredient>> initialIngredients = {
    'recipe_pho_bo': [
      RecipeIngredient(
        id: 'ing_pb_1',
        recipeId: 'recipe_pho_bo',
        foodId: 'food_2',
        foodName: 'Thịt bò thăn',
        unitId: 'g',
        unitSymbol: 'g',
        baseQuantity: 300,
      ),
      RecipeIngredient(
        id: 'ing_pb_2',
        recipeId: 'recipe_pho_bo',
        foodId: 'f10',
        foodName: 'Bánh phở tươi',
        unitId: 'g',
        unitSymbol: 'g',
        baseQuantity: 500,
      ),
      RecipeIngredient(
        id: 'ing_pb_3',
        recipeId: 'recipe_pho_bo',
        foodId: 'f11',
        foodName: 'Hành tây & rau thơm',
        unitId: 'g',
        unitSymbol: 'g',
        baseQuantity: 100,
      ),
    ],
    'recipe_com_tam': [
      RecipeIngredient(
        id: 'ing_ct_1',
        recipeId: 'recipe_com_tam',
        foodId: 'f12',
        foodName: 'Sườn cốt lết',
        unitId: 'g',
        unitSymbol: 'g',
        baseQuantity: 250,
      ),
      RecipeIngredient(
        id: 'ing_ct_2',
        recipeId: 'recipe_com_tam',
        foodId: 'food_5',
        foodName: 'Trứng gà',
        unitId: 'qua',
        unitSymbol: 'quả',
        baseQuantity: 1,
      ),
      RecipeIngredient(
        id: 'ing_ct_3',
        recipeId: 'recipe_com_tam',
        foodId: 'f13',
        foodName: 'Gạo tấm',
        unitId: 'g',
        unitSymbol: 'g',
        baseQuantity: 150,
      ),
    ],
    'recipe_canh_chua': [
      RecipeIngredient(
        id: 'ing_cc_1',
        recipeId: 'recipe_canh_chua',
        foodId: 'f14',
        foodName: 'Cá lóc đồng',
        unitId: 'g',
        unitSymbol: 'g',
        baseQuantity: 500,
      ),
      RecipeIngredient(
        id: 'ing_cc_2',
        recipeId: 'recipe_canh_chua',
        foodId: 'f15',
        foodName: 'Cà chua & dứa',
        unitId: 'g',
        unitSymbol: 'g',
        baseQuantity: 250,
      ),
      RecipeIngredient(
        id: 'ing_cc_3',
        recipeId: 'recipe_canh_chua',
        foodId: 'f16',
        foodName: 'Bạc hà, đậu bắp, giá đỗ',
        unitId: 'g',
        unitSymbol: 'g',
        baseQuantity: 200,
      ),
    ],
    'recipe_trung_cuon': [
      RecipeIngredient(
        id: 'ing_tc_1',
        recipeId: 'recipe_trung_cuon',
        foodId: 'food_5',
        foodName: 'Trứng gà',
        unitId: 'qua',
        unitSymbol: 'quả',
        baseQuantity: 3,
      ),
      RecipeIngredient(
        id: 'ing_tc_2',
        recipeId: 'recipe_trung_cuon',
        foodId: 'f11',
        foodName: 'Hành hoa',
        unitId: 'g',
        unitSymbol: 'g',
        baseQuantity: 20,
      ),
    ],
    'recipe_salad_uc_ga': [
      RecipeIngredient(
        id: 'ing_sg_1',
        recipeId: 'recipe_salad_uc_ga',
        foodId: 'f18',
        foodName: 'Ức gà phi lê',
        unitId: 'g',
        unitSymbol: 'g',
        baseQuantity: 300,
      ),
      RecipeIngredient(
        id: 'ing_sg_2',
        recipeId: 'recipe_salad_uc_ga',
        foodId: 'f19',
        foodName: 'Xà lách & cà chua bi',
        unitId: 'g',
        unitSymbol: 'g',
        baseQuantity: 200,
      ),
      RecipeIngredient(
        id: 'ing_sg_3',
        recipeId: 'recipe_salad_uc_ga',
        foodId: 'f20',
        foodName: 'Sốt mè rang',
        unitId: 'ml',
        unitSymbol: 'ml',
        baseQuantity: 30,
      ),
    ],
  };
}
