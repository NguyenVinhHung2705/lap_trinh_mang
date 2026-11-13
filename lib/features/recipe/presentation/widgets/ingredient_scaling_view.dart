import 'package:flutter/material.dart';

import '../../domain/recipe_service.dart';

/// Widget for scaling and displaying recipe ingredients by target servings.
class IngredientScalingView extends StatelessWidget {
  const IngredientScalingView({
    super.key,
    required this.baseServings,
    required this.currentServings,
    required this.scaledIngredients,
    required this.onServingsChanged,
  });

  final double baseServings;
  final double currentServings;
  final List<ScaledIngredient> scaledIngredients;
  final ValueChanged<double> onServingsChanged;

  static const Color primary = Color(0xFF16A36A);
  static const Color primaryDark = Color(0xFF087F55);
  static const Color primaryTint = Color(0xFFE7F6EF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5EBE6);
  static const Color textPrimary = Color(0xFF202B26);
  static const Color textSecondary = Color(0xFF77847C);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Serving Counter Control Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: primaryTint,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Số khẩu phần',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    'Gốc: ${_formatNumber(baseServings)} khẩu phần',
                    style: const TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _IconButton(
                    icon: Icons.remove,
                    onPressed: currentServings > 1
                        ? () => onServingsChanged(currentServings - 1)
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _formatNumber(currentServings),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryDark,
                      ),
                    ),
                  ),
                  _IconButton(
                    icon: Icons.add,
                    onPressed: () => onServingsChanged(currentServings + 1),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Danh sách nguyên liệu',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            Text(
              '${scaledIngredients.length} loại',
              style: const TextStyle(
                fontSize: 13,
                color: textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Scaled Ingredients List
        Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: scaledIngredients.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: border),
            itemBuilder: (context, index) {
              final ing = scaledIngredients[index];
              return Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          ing.foodName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_formatNumber(ing.scaledQuantity)} ${ing.unitSymbol}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryDark,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static String _formatNumber(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(1);
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onPressed != null ? IngredientScalingView.primary : Colors.grey.shade300,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
