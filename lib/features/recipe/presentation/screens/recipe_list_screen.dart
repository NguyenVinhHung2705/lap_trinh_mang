import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/recipe.dart';
import '../providers/recipe_list_provider.dart';
import '../widgets/recipe_card.dart';
import '../widgets/recipe_filter_sheet.dart';
import 'recipe_detail_screen.dart';
import 'recipe_editor_screen.dart';

/// Screen for Tab 3: Recipe library listing, search, filtering, and bookmark management.
class RecipeListScreen extends ConsumerWidget {
  const RecipeListScreen({super.key});

  static const Color primary = Color(0xFF16A36A);
  static const Color primaryTint = Color(0xFFE7F6EF);
  static const Color background = Color(0xFFF7F9F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5EBE6);
  static const Color textPrimary = Color(0xFF202B26);
  static const Color textSecondary = Color(0xFF77847C);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(accessibleRecipesStreamProvider);
    final savedIdsAsync = ref.watch(savedRecipeIdsStreamProvider);
    final currentQuery = ref.watch(recipeSearchQueryProvider);
    final currentSource = ref.watch(recipeSourceFilterProvider);
    final savedOnly = ref.watch(recipeSavedOnlyFilterProvider);
    final userId = ref.watch(currentUserIdProvider);

    final savedIds = savedIdsAsync.asData?.value ?? const [];

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: surface,
        title: const Text(
          'Công thức nấu ăn',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.tune,
                  color: (currentSource != null || savedOnly) ? primary : textPrimary,
                ),
                if (currentSource != null || savedOnly)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => RecipeFilterSheet(
                  selectedSource: currentSource,
                  savedOnly: savedOnly,
                  onApply: (source, isSaved) {
                    ref.read(recipeSourceFilterProvider.notifier).state = source;
                    ref.read(recipeSavedOnlyFilterProvider.notifier).state = isSaved;
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Category Bar Header
          Container(
            color: surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                // Search Input
                TextField(
                  onChanged: (val) {
                    ref.read(recipeSearchQueryProvider.notifier).state = val;
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm món ăn hoặc nguyên liệu...',
                    hintStyle: const TextStyle(fontSize: 14, color: textSecondary),
                    prefixIcon: const Icon(Icons.search, color: textSecondary),
                    suffixIcon: currentQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              ref.read(recipeSearchQueryProvider.notifier).state = '';
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: background,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter Quick Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Tất cả',
                        isSelected: currentSource == null && !savedOnly,
                        onTap: () {
                          ref.read(recipeSourceFilterProvider.notifier).state = null;
                          ref.read(recipeSavedOnlyFilterProvider.notifier).state = false;
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Của tôi',
                        isSelected: currentSource == RecipeSource.user && !savedOnly,
                        onTap: () {
                          ref.read(recipeSourceFilterProvider.notifier).state = RecipeSource.user;
                          ref.read(recipeSavedOnlyFilterProvider.notifier).state = false;
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Hệ thống',
                        isSelected: currentSource == RecipeSource.system && !savedOnly,
                        onTap: () {
                          ref.read(recipeSourceFilterProvider.notifier).state = RecipeSource.system;
                          ref.read(recipeSavedOnlyFilterProvider.notifier).state = false;
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Đã lưu',
                        icon: Icons.favorite,
                        isSelected: savedOnly,
                        onTap: () {
                          ref.read(recipeSavedOnlyFilterProvider.notifier).state = !savedOnly;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: border),
          // Recipes Stream List
          Expanded(
            child: recipesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: primary),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
                      const SizedBox(height: 12),
                      Text(
                        'Lỗi tải công thức: $err',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              data: (recipes) {
                if (recipes.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.menu_book_outlined,
                            size: 64,
                            color: textSecondary,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Chưa có công thức nào',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Hãy thêm công thức mới hoặc thay đổi từ khóa tìm kiếm.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: textSecondary),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text(
                              'Tạo công thức mới',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RecipeEditorScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: recipes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final recipe = recipes[index];
                    final isSaved = savedIds.contains(recipe.id);

                    return RecipeCard(
                      recipe: recipe,
                      isSaved: isSaved,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RecipeDetailScreen(recipeId: recipe.id),
                          ),
                        );
                      },
                      onToggleSave: () async {
                        final service = ref.read(recipeServiceProvider);
                        await service.toggleSaveRecipe(
                          userId: userId,
                          recipeId: recipe.id,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Thêm công thức',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const RecipeEditorScreen(),
            ),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  static const Color primary = Color(0xFF16A36A);
  static const Color primaryTint = Color(0xFFE7F6EF);
  static const Color border = Color(0xFFE5EBE6);
  static const Color textPrimary = Color(0xFF202B26);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? primaryTint : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primary : border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? primary : textPrimary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? primary : textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
