import 'package:flutter/material.dart';

import '../../data/models/recipe.dart';

/// Recipe card component adhering to DESIGN_PREVIEW.md design tokens.
class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    this.isSaved = false,
    this.onTap,
    this.onToggleSave,
  });

  final Recipe recipe;
  final bool isSaved;
  final VoidCallback? onTap;
  final VoidCallback? onToggleSave;

  static const Color primary = Color(0xFF16A36A);
  static const Color primaryTint = Color(0xFFE7F6EF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5EBE6);
  static const Color textPrimary = Color(0xFF202B26);
  static const Color textSecondary = Color(0xFF77847C);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recipe Image / Fallback Icon Box
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 90,
                    height: 90,
                    color: primaryTint,
                    child: recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                        ? Image.network(
                            recipe.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.restaurant_menu,
                              size: 40,
                              color: primary,
                            ),
                          )
                        : const Icon(
                            Icons.restaurant_menu,
                            size: 40,
                            color: primary,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title and Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Source/Visibility badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: primaryTint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              recipe.source.labelVi,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: primary,
                              ),
                            ),
                          ),
                          if (onToggleSave != null)
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                isSaved ? Icons.favorite : Icons.favorite_border,
                                color: isSaved ? const Color(0xFFEF4444) : textSecondary,
                                size: 22,
                              ),
                              onPressed: onToggleSave,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        recipe.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.cookingMinutes} phút',
                            style: const TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.people_outline,
                            size: 16,
                            color: textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.baseServings.toStringAsFixed(recipe.baseServings.truncateToDouble() == recipe.baseServings ? 0 : 1)} khẩu phần',
                            style: const TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
