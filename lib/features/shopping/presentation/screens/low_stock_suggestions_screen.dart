import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/models/low_stock_suggestion.dart';
import '../providers/shopping_providers.dart';

/// Screen displaying low-stock suggestions calculated from pantry ledger (MOD-02-04 / FR-12).
class LowStockSuggestionsScreen extends ConsumerStatefulWidget {
  const LowStockSuggestionsScreen({
    super.key,
    required this.userId,
    required this.listId,
  });

  final String userId;
  final String listId;

  @override
  ConsumerState<LowStockSuggestionsScreen> createState() =>
      _LowStockSuggestionsScreenState();
}

class _LowStockSuggestionsScreenState
    extends ConsumerState<LowStockSuggestionsScreen> {
  List<LowStockSuggestion> _suggestions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await ref
          .read(shoppingSuggestionsControllerProvider.notifier)
          .loadLowStockSuggestions(
            userId: widget.userId,
            listId: widget.listId,
          );

      if (mounted) {
        setState(() {
          _suggestions = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Gợi ý Thực phẩm Sắp hết',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _buildBody(),
      bottomNavigationBar: _suggestions.isNotEmpty
          ? Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleImport,
                icon: const Icon(Icons.playlist_add, color: Colors.white),
                label: Text(
                  'Thêm vào danh sách (${_suggestions.where((s) => s.isSelected).length} mục)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppColors.radiusInput),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Lỗi: $_error',
                  style: const TextStyle(color: AppColors.statusDanger)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadSuggestions,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.statusSuccessTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 36,
                  color: AppColors.statusSuccess,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Kho thực phẩm dồi dào!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hiện không có thực phẩm nào dưới ngưỡng cảnh báo sắp hết.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final item = _suggestions[index];

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusCard),
            side: BorderSide(
              color: item.alreadyInList
                  ? AppColors.statusWarning
                  : (item.isSelected ? AppColors.primary : AppColors.border),
              width: item.isSelected ? 1.5 : 1,
            ),
          ),
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Checkbox(
                  value: item.isSelected,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() {
                      _suggestions[index] =
                          item.copyWith(isSelected: val ?? false);
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.foodName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.statusWarningTint,
                              borderRadius:
                                  BorderRadius.circular(AppColors.radiusBadge),
                            ),
                            child: Text(
                              'Tồn: ${item.currentUsableStock} / Ngưỡng: ${item.threshold} ${item.unitName}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.statusWarning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item.alreadyInList) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Đã có ${item.existingPendingQuantity} ${item.unitName} trong danh sách mua',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Adjustable Quantity Input
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    initialValue: item.approvedQuantity.toString(),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: item.unitName,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppColors.radiusBadge),
                      ),
                    ),
                    onChanged: (val) {
                      final parsed =
                          double.tryParse(val) ?? item.suggestedQuantity;
                      if (parsed > 0) {
                        _suggestions[index] =
                            item.copyWith(approvedQuantity: parsed);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleImport() async {
    final selected = _suggestions.where((s) => s.isSelected).toList();
    if (selected.isEmpty) return;

    final count = await ref
        .read(shoppingSuggestionsControllerProvider.notifier)
        .importLowStockSuggestions(
          userId: widget.userId,
          listId: widget.listId,
          suggestions: selected,
        );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm $count thực phẩm sắp hết vào danh sách mua!'),
          backgroundColor: AppColors.statusSuccess,
        ),
      );
    }
  }
}

