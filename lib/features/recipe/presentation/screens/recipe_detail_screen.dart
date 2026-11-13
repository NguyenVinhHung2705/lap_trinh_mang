import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/recipe_detail_provider.dart';
import '../providers/recipe_list_provider.dart';
import '../widgets/ingredient_scaling_view.dart';
import 'recipe_editor_screen.dart';

/// Detail screen for viewing recipe, scaling ingredients, and author actions.
class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
  });

  final String recipeId;

  static const Color primary = Color(0xFF16A36A);
  static const Color primaryDark = Color(0xFF087F55);
  static const Color primaryTint = Color(0xFFE7F6EF);
  static const Color background = Color(0xFFF7F9F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5EBE6);
  static const Color textPrimary = Color(0xFF202B26);
  static const Color textSecondary = Color(0xFF77847C);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(recipeDetailDataProvider(recipeId));
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: background,
      body: detailAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: primary),
        ),
        error: (err, stack) => Scaffold(
          appBar: AppBar(title: const Text('Chi tiết công thức')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Lỗi: $err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: textSecondary),
              ),
            ),
          ),
        ),
        data: (detailData) {
          final recipe = detailData.recipe;
          final isAuthor = recipe.isAuthor(userId);
          final isSaved = detailData.isSaved;
          final targetServings = detailData.targetServings;

          return CustomScrollView(
            slivers: [
              // Hero Image App Bar
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: primaryDark,
                iconTheme: const IconThemeData(color: Colors.white),
                actions: [
                  IconButton(
                    icon: Icon(
                      isSaved ? Icons.favorite : Icons.favorite_border,
                      color: isSaved ? const Color(0xFFEF4444) : Colors.white,
                    ),
                    onPressed: () async {
                      final service = ref.read(recipeServiceProvider);
                      await service.toggleSaveRecipe(
                        userId: userId,
                        recipeId: recipe.id,
                      );
                      ref.invalidate(recipeDetailDataProvider(recipeId));
                    },
                  ),
                  if (isAuthor)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (val) async {
                        if (val == 'edit') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RecipeEditorScreen(recipeId: recipe.id),
                            ),
                          );
                        } else if (val == 'delete') {
                          final confirm = await _showDeleteConfirmDialog(context);
                          if (confirm == true) {
                            try {
                              final service = ref.read(recipeServiceProvider);
                              await service.deleteRecipe(
                                userId: userId,
                                recipeId: recipe.id,
                              );
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Đã xóa công thức')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Lỗi xóa công thức: $e')),
                                );
                              }
                            }
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20, color: textPrimary),
                              SizedBox(width: 8),
                              Text('Chỉnh sửa công thức'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Color(0xFFEF4444)),
                              SizedBox(width: 8),
                              Text('Xóa công thức', style: TextStyle(color: Color(0xFFEF4444))),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                          ? Image.network(
                              recipe.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: primaryTint,
                                child: const Icon(
                                  Icons.restaurant_menu,
                                  size: 80,
                                  color: primary,
                                ),
                              ),
                            )
                          : Container(
                              color: primaryTint,
                              child: const Icon(
                                Icons.restaurant_menu,
                                size: 80,
                                color: primary,
                              ),
                            ),
                      // Gradient overlay for text contrast
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.transparent,
                              Colors.black.withOpacity(0.6),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        bottom: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                recipe.source.labelVi,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              recipe.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content Body
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cooking Metadata Bar
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _MetaItem(
                              icon: Icons.timer_outlined,
                              label: 'Thời gian',
                              value: '${recipe.cookingMinutes} phút',
                            ),
                            Container(width: 1, height: 32, color: border),
                            _MetaItem(
                              icon: Icons.people_outline,
                              label: 'Khẩu phần gốc',
                              value: '${_formatNum(recipe.baseServings)} người',
                            ),
                            Container(width: 1, height: 32, color: border),
                            _MetaItem(
                              icon: Icons.lock_outline,
                              label: 'Quyền xem',
                              value: recipe.visibility.labelVi,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Description if available
                      if (recipe.description != null && recipe.description!.isNotEmpty) ...[
                        Text(
                          recipe.description!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Ingredient Scaling View
                      IngredientScalingView(
                        baseServings: recipe.baseServings,
                        currentServings: targetServings,
                        scaledIngredients: detailData.scaledIngredients,
                        onServingsChanged: (newServings) {
                          ref.read(targetServingsProvider(recipeId).notifier).state = newServings;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Step-by-Step Instructions
                      const Text(
                        'Cách làm chi tiết',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        child: Text(
                          recipe.instructions,
                          style: const TextStyle(
                            fontSize: 15,
                            color: textPrimary,
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool?> _showDeleteConfirmDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa công thức này khỏi hệ thống?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  static String _formatNum(double val) {
    if (val == val.roundToDouble()) return val.toInt().toString();
    return val.toStringAsFixed(1);
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 22, color: RecipeDetailScreen.primary),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: RecipeDetailScreen.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: RecipeDetailScreen.textPrimary,
          ),
        ),
      ],
    );
  }
}
