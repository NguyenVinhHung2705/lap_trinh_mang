import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/meal_repository.dart';
import '../../data/models/meal.dart';
import '../../data/models/meal_item.dart';
import '../providers/meal_detail_provider.dart';
import '../widgets/complete_meal_dialog.dart';
import '../widgets/reminder_bottom_sheet.dart';
import 'add_dish_screen.dart';
import 'confirm_consumption_screen.dart';

/// Detail screen for a selected `(date, slot)` meal (`MOD-04-02` & `MOD-04-05`).
class MealDetailScreen extends ConsumerStatefulWidget {
  const MealDetailScreen({
    super.key,
    required this.initialDate,
    required this.initialSlot,
    this.itemTitleBuilder,
    this.onAddDish,
    this.onCompleteMeal,
    this.onConfigureReminder,
    this.onEditItem,
    this.onDeleteItem,
    this.onCancelMeal,
    this.onCancelReminders,
    this.onReminderRescheduled,
  });

  final DateTime initialDate;
  final MealSlot initialSlot;
  final String Function(MealItem item)? itemTitleBuilder;
  final ValueChanged<Meal>? onAddDish;
  final void Function(Meal meal, List<MealItem> items)? onCompleteMeal;
  final ValueChanged<Meal>? onConfigureReminder;
  final void Function(Meal meal, MealItem item)? onEditItem;
  final void Function(Meal meal, MealItem item)? onDeleteItem;
  final ValueChanged<Meal>? onCancelMeal;
  final Future<void> Function(String mealId)? onCancelReminders;
  final Future<void> Function(Meal updatedMeal)? onReminderRescheduled;

  @override
  ConsumerState<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends ConsumerState<MealDetailScreen> {
  static const Color _primary = Color(0xFF16A36A);
  static const Color _background = Color(0xFFF7F9F7);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _border = Color(0xFFE5EBE6);
  static const Color _textPrimary = Color(0xFF202B26);
  static const Color _textSecondary = Color(0xFF77847C);
  static const Color _plannedBlue = Color(0xFF2563EB);
  static const Color _plannedBlueTint = Color(0xFFEFF6FF);
  static const Color _completedGray = Color(0xFF6B7280);
  static const Color _completedGrayTint = Color(0xFFF3F4F6);

  late DateTime _selectedDate;
  late MealSlot _selectedSlot;

  @override
  void initState() {
    super.initState();
    _selectedDate = Meal.normalizeLocalDate(widget.initialDate);
    _selectedSlot = widget.initialSlot;
  }

  MealSlotKey get _slotKey =>
      MealSlotKey(date: _selectedDate, slot: _selectedSlot);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = Meal.normalizeLocalDate(picked);
    });
  }

  Future<void> _openAddDish(Meal meal) async {
    if (widget.onAddDish != null) {
      widget.onAddDish!(meal);
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddDishScreen(meal: meal)),
    );
  }

  Future<void> _handleEditItem(Meal meal, MealItem item) async {
    if (widget.onEditItem != null) {
      widget.onEditItem!(meal, item);
      return;
    }
    final newQuantity = await _promptQuantityEdit(item);
    if (newQuantity == null || !mounted) return;

    await _runAction(() async {
      await ref.read(mealServiceProvider).updateItemQuantity(
            userId: meal.userId,
            mealId: meal.id,
            itemId: item.id,
            quantity: newQuantity,
          );
    }, successMessage: 'Đã cập nhật định lượng món.');
  }

  Future<void> _handleDeleteItem(Meal meal, MealItem item) async {
    if (widget.onDeleteItem != null) {
      widget.onDeleteItem!(meal, item);
      return;
    }
    final confirmed = await _confirmDialog(
      title: 'Bỏ món khỏi bữa ăn?',
      message: 'Thao tác này chỉ xóa khỏi kế hoạch, không làm thay đổi tồn kho.',
      confirmLabel: 'Bỏ món',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    await _runAction(() async {
      await ref.read(mealServiceProvider).removeItem(
            userId: meal.userId,
            mealId: meal.id,
            itemId: item.id,
          );
    }, successMessage: 'Đã bỏ món khỏi kế hoạch.');
  }

  Future<void> _handleRescheduleMeal(Meal meal) async {
    final target = await _promptReschedule(meal);
    if (target == null || !mounted) return;

    await _runAction(() async {
      final moved = await ref.read(mealServiceProvider).rescheduleMeal(
            userId: meal.userId,
            mealId: meal.id,
            newDate: target.date,
            newSlot: target.slot,
            onReminderRescheduled: widget.onReminderRescheduled,
          );
      if (!mounted) return;
      setState(() {
        _selectedDate = moved.mealDate;
        _selectedSlot = moved.slot;
      });
    }, successMessage: 'Đã dời lịch bữa ăn.');
  }

  Future<void> _handleConfigureReminder(Meal meal) async {
    if (widget.onConfigureReminder != null) {
      widget.onConfigureReminder!(meal);
      return;
    }
    final updated = await ReminderBottomSheet.show(context, meal: meal);
    if (updated == true && mounted) {
      await ref.read(mealDetailProvider(_slotKey).notifier).refresh();
    }
  }

  Future<void> _handleCompleteMeal(Meal meal, List<MealItem> items) async {
    if (widget.onCompleteMeal != null) {
      widget.onCompleteMeal!(meal, items);
      return;
    }
    final consumptionRequest =
        await Navigator.of(context).push<ConsumptionRequest>(
      MaterialPageRoute(
        builder: (_) =>
            ConfirmConsumptionScreen(meal: meal, mealItems: items),
      ),
    );
    if (consumptionRequest == null || !mounted) return;

    final completedMeal = await CompleteMealDialog.show(
      context,
      request: consumptionRequest,
    );
    if (completedMeal != null && mounted) {
      _showSnack('Bữa ăn đã hoàn thành và trừ tồn kho thành công!');
      await ref.read(mealDetailProvider(_slotKey).notifier).refresh();
    }
  }

  Future<void> _handleCancelMeal(Meal meal) async {
    if (widget.onCancelMeal != null) {
      widget.onCancelMeal!(meal);
      return;
    }
    final confirmed = await _confirmDialog(
      title: 'Hủy kế hoạch bữa ăn?',
      message:
          'Kế hoạch bữa ${meal.slot.labelVi} sẽ bị hủy và lịch nhắc liên quan sẽ được gỡ. Tồn kho không bị ảnh hưởng.',
      confirmLabel: 'Hủy kế hoạch',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    await _runAction(() async {
      await ref.read(mealServiceProvider).cancelMeal(
            userId: meal.userId,
            mealId: meal.id,
            onCancelReminders: widget.onCancelReminders,
          );
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        await ref.read(mealDetailProvider(_slotKey).notifier).refresh();
      }
    }, successMessage: 'Đã hủy kế hoạch bữa ăn.');
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    try {
      await action();
      if (!mounted) return;
      _showSnack(successMessage);
    } on MealPlanException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Thao tác thất bại: $e', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFEF4444) : _primary,
      ),
    );
  }

  Future<double?> _promptQuantityEdit(MealItem item) async {
    final controller = TextEditingController(
      text: item.quantity == item.quantity.roundToDouble()
          ? item.quantity.toInt().toString()
          : item.quantity.toString(),
    );
    String? error;

    return showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(item.isRecipe ? 'Sửa số khẩu phần' : 'Sửa số lượng'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: item.isRecipe ? 'Khẩu phần' : 'Số lượng (${item.unitId})',
              errorText: error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text.trim());
                if (parsed == null || parsed <= 0) {
                  setDialogState(() => error = 'Vui lòng nhập số > 0');
                  return;
                }
                Navigator.of(ctx).pop(parsed);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<({DateTime date, MealSlot slot})?> _promptReschedule(Meal meal) async {
    DateTime pickedDate = meal.mealDate;
    MealSlot pickedSlot = meal.slot;

    return showDialog<({DateTime date, MealSlot slot})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final dateLabel =
              '${pickedDate.day.toString().padLeft(2, '0')}/'
              '${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.year}';
          return AlertDialog(
            title: const Text('Dời lịch bữa ăn'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined, color: _primary),
                  title: Text('Ngày: $dateLabel'),
                  trailing: const Text(
                    'Chọn',
                    style: TextStyle(color: _primary, fontWeight: FontWeight.w700),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: pickedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (date != null) {
                      setDialogState(
                        () => pickedDate = Meal.normalizeLocalDate(date),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<MealSlot>(
                  value: pickedSlot,
                  decoration: InputDecoration(
                    labelText: 'Khung bữa',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: MealSlot.values
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text('Bữa ${s.labelVi}'),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => pickedSlot = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(
                  (date: pickedDate, slot: pickedSlot),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Dời lịch'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDestructive ? const Color(0xFFEF4444) : _primary,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final mealAsync = ref.watch(mealDetailProvider(_slotKey));

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Chi tiết bữa ăn',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          mealAsync.maybeWhen(
            data: (meal) => meal.isPlanned
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _handleRescheduleMeal(meal),
                        icon: const Icon(Icons.edit_calendar_outlined),
                        color: _textPrimary,
                        tooltip: 'Dời ngày/khung bữa',
                      ),
                      IconButton(
                        onPressed: () => _handleConfigureReminder(meal),
                        icon: const Icon(Icons.notifications_outlined),
                        color: _textPrimary,
                        tooltip: 'Nhắc chuẩn bị bữa ăn',
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: mealAsync.maybeWhen(
        data: (meal) => meal.isPlanned
            ? FloatingActionButton.extended(
                onPressed: () => _openAddDish(meal),
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Thêm món',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            : null,
        orElse: () => null,
      ),
      body: Column(
        children: [
          _DateAndSlotSelector(
            selectedDate: _selectedDate,
            selectedSlot: _selectedSlot,
            onPickDate: _pickDate,
            onSelectSlot: (slot) => setState(() => _selectedSlot = slot),
          ),
          Expanded(
            child: mealAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: _primary),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Không thể mở bữa ăn: $error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFEF4444)),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () =>
                            ref.read(mealDetailProvider(_slotKey).notifier).refresh(),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (meal) => _MealDetailBody(
                meal: meal,
                itemTitleBuilder: widget.itemTitleBuilder,
                onCompleteMeal: _handleCompleteMeal,
                onEditItem: _handleEditItem,
                onDeleteItem: _handleDeleteItem,
                onCancelMeal: _handleCancelMeal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateAndSlotSelector extends StatelessWidget {
  const _DateAndSlotSelector({
    required this.selectedDate,
    required this.selectedSlot,
    required this.onPickDate,
    required this.onSelectSlot,
  });

  final DateTime selectedDate;
  final MealSlot selectedSlot;
  final VoidCallback onPickDate;
  final ValueChanged<MealSlot> onSelectSlot;

  @override
  Widget build(BuildContext context) {
    final dateText =
        '${selectedDate.day.toString().padLeft(2, '0')}/'
        '${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}';

    return Container(
      color: _MealDetailScreenState._surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _MealDetailScreenState._background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _MealDetailScreenState._border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: _MealDetailScreenState._primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ngày ăn: $dateText',
                    style: const TextStyle(
                      color: _MealDetailScreenState._textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Đổi ngày',
                    style: TextStyle(
                      color: _MealDetailScreenState._primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: MealSlot.values.map((slot) {
              final selected = slot == selectedSlot;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: slot == MealSlot.snack ? 0 : 6,
                  ),
                  child: GestureDetector(
                    onTap: () => onSelectSlot(slot),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? _MealDetailScreenState._primary
                            : _MealDetailScreenState._background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? _MealDetailScreenState._primary
                              : _MealDetailScreenState._border,
                        ),
                      ),
                      child: Text(
                        slot.labelVi,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : _MealDetailScreenState._textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _MealDetailBody extends ConsumerWidget {
  const _MealDetailBody({
    required this.meal,
    this.itemTitleBuilder,
    this.onCompleteMeal,
    required this.onEditItem,
    required this.onDeleteItem,
    required this.onCancelMeal,
  });

  final Meal meal;
  final String Function(MealItem item)? itemTitleBuilder;
  final void Function(Meal meal, List<MealItem> items)? onCompleteMeal;
  final void Function(Meal meal, MealItem item) onEditItem;
  final void Function(Meal meal, MealItem item) onDeleteItem;
  final ValueChanged<Meal> onCancelMeal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(mealItemsProvider(meal.id));

    return itemsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: _MealDetailScreenState._primary),
      ),
      error: (error, _) => Center(
        child: Text(
          'Lỗi tải danh sách món: $error',
          style: const TextStyle(color: Color(0xFFEF4444)),
        ),
      ),
      data: (items) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _StatusSummaryCard(meal: meal),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Danh sách món ăn',
                  style: TextStyle(
                    color: _MealDetailScreenState._textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${items.length} món',
                  style: const TextStyle(
                    color: _MealDetailScreenState._textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _MealDetailScreenState._surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _MealDetailScreenState._border),
                ),
                child: const Text(
                  'Bữa ăn chưa có món nào.\nNhấn "Thêm món" để chọn công thức hoặc thực phẩm ăn liền (chưa trừ kho).',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _MealDetailScreenState._textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              )
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MealItemCard(
                    meal: meal,
                    item: item,
                    title: itemTitleBuilder?.call(item) ?? _defaultTitle(item),
                    onEdit: () => onEditItem(meal, item),
                    onDelete: () => onDeleteItem(meal, item),
                  ),
                ),
              ),
            if (meal.isPlanned) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: items.isEmpty || onCompleteMeal == null
                      ? null
                      : () => onCompleteMeal!(meal, items),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _MealDetailScreenState._primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _MealDetailScreenState._border,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Hoàn thành bữa ăn & trừ kho',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => onCancelMeal(meal),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Hủy kế hoạch bữa ăn',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  static String _defaultTitle(MealItem item) {
    if (item.isRecipe) {
      return 'Món theo công thức (${item.recipeId})';
    }
    return 'Thực phẩm ăn liền (${item.foodId})';
  }
}

class _StatusSummaryCard extends StatelessWidget {
  const _StatusSummaryCard({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final isCompleted = meal.isCompleted;
    final badgeBg = isCompleted
        ? _MealDetailScreenState._completedGrayTint
        : _MealDetailScreenState._plannedBlueTint;
    final badgeFg = isCompleted
        ? _MealDetailScreenState._completedGray
        : _MealDetailScreenState._plannedBlue;
    final statusLabel = isCompleted
        ? 'Đã hoàn thành'
        : 'Đã lên lịch · Chưa trừ kho';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _MealDetailScreenState._surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _MealDetailScreenState._border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: badgeFg,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          if (meal.reminderAt != null)
            Row(
              children: [
                const Icon(
                  Icons.alarm_rounded,
                  size: 16,
                  color: _MealDetailScreenState._primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${meal.reminderAt!.hour.toString().padLeft(2, '0')}:'
                  '${meal.reminderAt!.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: _MealDetailScreenState._textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MealItemCard extends StatelessWidget {
  const _MealItemCard({
    required this.meal,
    required this.item,
    required this.title,
    required this.onEdit,
    required this.onDelete,
  });

  final Meal meal;
  final MealItem item;
  final String title;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final quantityText = item.isRecipe
        ? '${_formatNumber(item.quantity)} khẩu phần'
        : '${_formatNumber(item.quantity)} (${item.unitId})';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _MealDetailScreenState._surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _MealDetailScreenState._border),
      ),
      child: Row(
        children: [
          Icon(
            item.isRecipe ? Icons.menu_book_rounded : Icons.fastfood_outlined,
            color: _MealDetailScreenState._primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _MealDetailScreenState._textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  quantityText,
                  style: const TextStyle(
                    color: _MealDetailScreenState._textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (meal.isPlanned) ...[
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: _MealDetailScreenState._textSecondary,
              tooltip: 'Sửa định lượng',
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: const Color(0xFFEF4444),
              tooltip: 'Bỏ món',
            ),
          ],
        ],
      ),
    );
  }

  static String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }
}
