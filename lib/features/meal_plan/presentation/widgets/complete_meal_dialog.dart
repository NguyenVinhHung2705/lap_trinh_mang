import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/meal_repository.dart';
import '../../data/models/consumption_request.dart';
import '../../data/models/meal.dart';
import '../../domain/stock_deduction_service.dart';

/// Provides [PantryBatchReader] (`MOD-01` integration point).
final pantryBatchReaderProvider = Provider<PantryBatchReader>((ref) {
  return FirestorePantryBatchReader();
});

/// Provides [StockDeductionService] (`MOD-04-08` / F8).
final stockDeductionServiceProvider = Provider<StockDeductionService>((ref) {
  return StockDeductionService(
    mealRepository: ref.watch(mealRepositoryProvider),
    batchReader: ref.watch(pantryBatchReaderProvider),
  );
});

/// Dialog to preview FEFO batch deductions and confirm atomic completion (`MOD-04-08`).
class CompleteMealDialog extends ConsumerStatefulWidget {
  const CompleteMealDialog({
    super.key,
    required this.request,
  });

  final ConsumptionRequest request;

  /// Helper to show [CompleteMealDialog]. Returns the updated [Meal] if completed.
  static Future<Meal?> show(
    BuildContext context, {
    required ConsumptionRequest request,
  }) {
    return showDialog<Meal>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CompleteMealDialog(request: request),
    );
  }

  @override
  ConsumerState<CompleteMealDialog> createState() => _CompleteMealDialogState();
}

class _CompleteMealDialogState extends ConsumerState<CompleteMealDialog> {
  static const Color _primary = Color(0xFF16A36A);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _dangerTint = Color(0xFFFEECEC);
  static const Color _border = Color(0xFFE5EBE6);
  static const Color _textPrimary = Color(0xFF202B26);
  static const Color _textSecondary = Color(0xFF77847C);

  bool _isLoading = true;
  bool _isDeducting = false;
  String? _errorText;
  MealCompletionPreview? _preview;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final service = ref.read(stockDeductionServiceProvider);
      final preview = await service.previewPlan(
        userId: widget.request.userId,
        request: widget.request,
      );
      if (!mounted) return;
      setState(() => _preview = preview);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = 'Không thể kiểm tra tồn kho: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDeduction() async {
    setState(() => _isDeducting = true);
    final service = ref.read(stockDeductionServiceProvider);

    try {
      final completedMeal = await service.completeMealAtomic(
        userId: widget.request.userId,
        request: widget.request,
      );
      if (!mounted) return;
      Navigator.of(context).pop(completedMeal);
    } on InsufficientStockException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
      _loadPreview(); // Refresh
    } on MealPlanException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Hoàn thành bữa ăn thất bại: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isDeducting = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _danger : _primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F6EF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: _primary, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Xác nhận trừ kho (FEFO)',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildContent(),
      ),
      actions: [
        TextButton(
          onPressed: _isDeducting ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: (_isLoading ||
                  _isDeducting ||
                  _preview == null ||
                  !_preview!.isAllSufficient)
              ? null
              : _confirmDeduction,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _border,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: _isDeducting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'Xác nhận & trừ kho',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }
    if (_errorText != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          _errorText!,
          style: const TextStyle(color: _danger, fontSize: 13),
        ),
      );
    }

    final preview = _preview!;
    final isSufficient = preview.isAllSufficient;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSufficient ? const Color(0xFFEFF6FF) : _dangerTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isSufficient
                  ? 'Tất cả nguyên liệu đều đủ tồn kho khả dụng. Các lô gần hết hạn sẽ được ưu tiên xuất trước (FEFO).'
                  : 'Không đủ tồn kho khả dụng cho toàn bộ nguyên liệu. Hệ thống sẽ không trừ bất kỳ nguyên liệu nào (Nguyên tử / All-or-nothing).',
              style: TextStyle(
                color: isSufficient ? const Color(0xFF2563EB) : _danger,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Phân bổ trừ kho theo từng lô:',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...preview.plans.map((plan) => _PlanItemCard(plan: plan)),
        ],
      ),
    );
  }
}

class _PlanItemCard extends StatelessWidget {
  const _PlanItemCard({required this.plan});

  final FoodDeductionPlan plan;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF16A36A);
    const danger = Color(0xFFEF4444);
    const border = Color(0xFFE5EBE6);
    const textPrimary = Color(0xFF202B26);
    const textSecondary = Color(0xFF77847C);

    final isOk = plan.isSufficient;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOk ? border : danger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.foodName,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Cần: ${_format(plan.requiredQuantity)} ${plan.baseUnitSymbol}',
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isOk
                ? 'Tổng khả dụng: ${_format(plan.totalAvailableQuantity)} ${plan.baseUnitSymbol}'
                : 'Thiếu: ${_format(plan.shortage)} ${plan.baseUnitSymbol} (chỉ có ${_format(plan.totalAvailableQuantity)})',
            style: TextStyle(
              color: isOk ? primary : danger,
              fontSize: 12,
              fontWeight: isOk ? FontWeight.normal : FontWeight.w700,
            ),
          ),
          if (plan.allocations.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...plan.allocations.map((alloc) {
              final exp = alloc.batch.expiryDate;
              final expText =
                  '${exp.day.toString().padLeft(2, '0')}/${exp.month.toString().padLeft(2, '0')}/${exp.year}';
              return Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_right_rounded, size: 16, color: primary),
                    Expanded(
                      child: Text(
                        'Lô ${alloc.batch.id} (HSD: $expText)',
                        style: const TextStyle(fontSize: 11, color: textSecondary),
                      ),
                    ),
                    Text(
                      '-${_format(alloc.quantityToDeduct)} ${plan.baseUnitSymbol}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  static String _format(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}
