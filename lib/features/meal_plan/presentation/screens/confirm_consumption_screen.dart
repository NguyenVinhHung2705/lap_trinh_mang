import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/meal_repository.dart';
import '../../data/models/consumption_request.dart';
import '../../data/models/meal.dart';
import '../../data/models/meal_item.dart';
import 'add_dish_screen.dart';

/// Screen for reviewing and adjusting actual ingredient consumption (`MOD-04-07`).
///
/// Produces a validated [ConsumptionRequest] and passes it to [onConfirmed] (`MOD-04-08`).
/// Never modifies pantry stock directly.
class ConfirmConsumptionScreen extends ConsumerStatefulWidget {
  const ConfirmConsumptionScreen({
    super.key,
    required this.meal,
    required this.mealItems,
    this.onConfirmed,
  });

  final Meal meal;
  final List<MealItem> mealItems;

  /// Invoked after the user approves the consumption quantities (Step 9 `MOD-04-08`).
  final ValueChanged<ConsumptionRequest>? onConfirmed;

  @override
  ConsumerState<ConfirmConsumptionScreen> createState() =>
      _ConfirmConsumptionScreenState();
}

class _ConfirmConsumptionScreenState
    extends ConsumerState<ConfirmConsumptionScreen> {
  static const Color _primary = Color(0xFF16A36A);
  static const Color _background = Color(0xFFF7F9F7);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _border = Color(0xFFE5EBE6);
  static const Color _textPrimary = Color(0xFF202B26);
  static const Color _textSecondary = Color(0xFF77847C);

  bool _isLoading = true;
  String? _loadError;
  List<ConsumptionItem> _items = const [];
  final Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadExpectedConsumption();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExpectedConsumption() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final estimator = ConsumptionEstimator(
        recipeReader: ref.read(recipeCatalogReaderProvider),
        foodReader: ref.read(foodCatalogReaderProvider),
      );
      final estimated = await estimator.buildExpectedItems(widget.mealItems);
      if (!mounted) return;

      for (final c in _controllers.values) {
        c.dispose();
      }
      _controllers.clear();
      for (var i = 0; i < estimated.length; i++) {
        _controllers[i] = TextEditingController(
          text: _formatNumber(estimated[i].actualQuantity),
        );
      }

      setState(() => _items = estimated);
    } on MealPlanException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = 'Không tính được định lượng dự kiến: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleIncluded(int index, bool included) {
    final updated = List<ConsumptionItem>.from(_items);
    updated[index] = updated[index].copyWith(isIncluded: included);
    setState(() => _items = updated);
  }

  void _submitApproval() {
    final updated = <ConsumptionItem>[];
    for (var i = 0; i < _items.length; i++) {
      final current = _items[i];
      if (!current.isIncluded) {
        updated.add(current);
        continue;
      }
      final raw = _controllers[i]?.text.trim() ?? '';
      final parsed = double.tryParse(raw);
      if (parsed == null || parsed < 0 || parsed.isNaN || parsed.isInfinite) {
        _showError(
          'Số lượng của "${current.foodName}" không hợp lệ (phải >= 0).',
        );
        return;
      }
      updated.add(current.copyWith(actualQuantity: parsed));
    }

    try {
      final request = ConsumptionRequest(
        userId: widget.meal.userId,
        meal: widget.meal,
        items: updated,
      );
      if (widget.onConfirmed != null) {
        widget.onConfirmed!(request);
      } else {
        Navigator.of(context).pop(request);
      }
    } on MealPlanException catch (e) {
      _showError(e.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Xác nhận lượng dùng thực tế',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _items.isEmpty || _isLoading || _loadError != null
          ? null
          : SafeArea(
              child: Container(
                color: _surface,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submitApproval,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Tiếp tục hoàn thành & trừ kho',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFEF4444)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loadExpectedConsumption,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Không có nguyên liệu nào phát sinh từ các món trong bữa ăn.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSecondary),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Kiểm tra hoặc điều chỉnh lượng thực dùng (đã quy đổi về đơn vị tồn kho). Bỏ chọn nguyên liệu không sử dụng. Tồn kho chỉ bị trừ sau khi bạn xác nhận ở bước tiếp theo.',
            style: TextStyle(
              color: Color(0xFF2563EB),
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...List.generate(_items.length, (index) {
          final item = _items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ConsumptionItemCard(
              item: item,
              controller: _controllers[index]!,
              onToggleIncluded: (val) => _toggleIncluded(index, val),
            ),
          );
        }),
      ],
    );
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

class _ConsumptionItemCard extends StatelessWidget {
  const _ConsumptionItemCard({
    required this.item,
    required this.controller,
    required this.onToggleIncluded,
  });

  final ConsumptionItem item;
  final TextEditingController controller;
  final ValueChanged<bool> onToggleIncluded;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _ConfirmConsumptionScreenState._surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ConfirmConsumptionScreenState._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: item.isIncluded,
                activeColor: _ConfirmConsumptionScreenState._primary,
                onChanged: (val) => onToggleIncluded(val ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.foodName,
                      style: TextStyle(
                        color: item.isIncluded
                            ? _ConfirmConsumptionScreenState._textPrimary
                            : _ConfirmConsumptionScreenState._textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        decoration: item.isIncluded
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    Text(
                      'Nguồn: ${item.sourceLabel} · Dự kiến: '
                      '${_ConfirmConsumptionScreenState._formatNumber(item.expectedQuantity)} ${item.baseUnitSymbol}',
                      style: const TextStyle(
                        color: _ConfirmConsumptionScreenState._textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.isIncluded) ...[
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Lượng dùng thực tế (${item.baseUnitSymbol})',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

