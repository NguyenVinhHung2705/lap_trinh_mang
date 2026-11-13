import 'package:flutter/material.dart';

import '../../data/models/recipe.dart';

/// Filter options bottom sheet for recipe library.
class RecipeFilterSheet extends StatelessWidget {
  const RecipeFilterSheet({
    super.key,
    required this.selectedSource,
    required this.savedOnly,
    required this.onApply,
  });

  final RecipeSource? selectedSource;
  final bool savedOnly;
  final void Function(RecipeSource? source, bool savedOnly) onApply;

  static const Color primary = Color(0xFF16A36A);
  static const Color primaryTint = Color(0xFFE7F6EF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5EBE6);
  static const Color textPrimary = Color(0xFF202B26);

  @override
  Widget build(BuildContext context) {
    RecipeSource? currentSource = selectedSource;
    bool currentSavedOnly = savedOnly;

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Bộ lọc công thức',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: border),
              const SizedBox(height: 12),
              const Text(
                'Nguồn công thức',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Tất cả nguồn'),
                    selected: currentSource == null,
                    selectedColor: primaryTint,
                    labelStyle: TextStyle(
                      color: currentSource == null ? primary : textPrimary,
                      fontWeight: currentSource == null ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() => currentSource = null),
                  ),
                  ...RecipeSource.values.map(
                    (s) => ChoiceChip(
                      label: Text(s.labelVi),
                      selected: currentSource == s,
                      selectedColor: primaryTint,
                      labelStyle: TextStyle(
                        color: currentSource == s ? primary : textPrimary,
                        fontWeight: currentSource == s ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) => setState(() => currentSource = s),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: primary,
                title: const Text(
                  'Chỉ hiển thị công thức đã lưu',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
                value: currentSavedOnly,
                onChanged: (val) => setState(() => currentSavedOnly = val),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    onApply(currentSource, currentSavedOnly);
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Áp dụng bộ lọc',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
