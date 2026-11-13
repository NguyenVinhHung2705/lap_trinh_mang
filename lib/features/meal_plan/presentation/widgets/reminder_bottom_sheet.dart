import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/meal_repository.dart';
import '../../data/models/meal.dart';
import '../../domain/reminder_service.dart';
import '../providers/meal_calendar_provider.dart';

/// Provides the shared [ReminderService] instance (`MOD-04-06`).
final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(
    mealRepository: ref.watch(mealRepositoryProvider),
  );
});

/// Bottom sheet for configuring or cancelling a meal preparation reminder (`MOD-04-06`).
class ReminderBottomSheet extends ConsumerStatefulWidget {
  const ReminderBottomSheet({
    super.key,
    required this.meal,
  });

  final Meal meal;

  /// Convenience helper to open [ReminderBottomSheet] with design-system top radius (`24dp`).
  static Future<bool?> show(BuildContext context, {required Meal meal}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReminderBottomSheet(meal: meal),
    );
  }

  @override
  ConsumerState<ReminderBottomSheet> createState() =>
      _ReminderBottomSheetState();
}

class _ReminderBottomSheetState extends ConsumerState<ReminderBottomSheet> {
  static const Color _primary = Color(0xFF16A36A);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _background = Color(0xFFF7F9F7);
  static const Color _border = Color(0xFFE5EBE6);
  static const Color _textPrimary = Color(0xFF202B26);
  static const Color _textSecondary = Color(0xFF77847C);

  late bool _enabled;
  late TimeOfDay _selectedTime;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.meal.reminderAt;
    _enabled = existing != null;
    _selectedTime = existing != null
        ? TimeOfDay(hour: existing.hour, minute: existing.minute)
        : _defaultTimeForSlot(widget.meal.slot);
  }

  static TimeOfDay _defaultTimeForSlot(MealSlot slot) {
    return switch (slot) {
      MealSlot.breakfast => const TimeOfDay(hour: 6, minute: 30),
      MealSlot.lunch => const TimeOfDay(hour: 11, minute: 0),
      MealSlot.dinner => const TimeOfDay(hour: 17, minute: 30),
      MealSlot.snack => const TimeOfDay(hour: 15, minute: 0),
    };
  }

  DateTime _buildScheduledDateTime() {
    final d = widget.meal.mealDate;
    return DateTime(
      d.year,
      d.month,
      d.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked == null) return;
    setState(() {
      _selectedTime = picked;
      _enabled = true;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final service = ref.read(reminderServiceProvider);

    try {
      if (!_enabled) {
        await service.cancelMealReminder(
          userId: widget.meal.userId,
          mealId: widget.meal.id,
        );
        if (!mounted) return;
        _showFeedback('Đã tắt nhắc nhở bữa ăn.');
        Navigator.of(context).pop(true);
        return;
      }

      final scheduledAt = _buildScheduledDateTime();
      final result = await service.scheduleMealReminder(
        meal: widget.meal,
        reminderAt: scheduledAt,
      );
      if (!mounted) return;
      final message = result.fellBackToInAppOnly
          ? 'Quyền thông báo thiết bị đang tắt. Đã lưu nhắc trong ứng dụng.'
          : 'Đã đặt nhắc chuẩn bị bữa ${widget.meal.slot.labelVi}.';
      _showFeedback(message, isWarning: result.fellBackToInAppOnly);
      Navigator.of(context).pop(true);
    } on MealPlanException catch (e) {
      if (!mounted) return;
      _showFeedback(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showFeedback('Không thể lưu lịch nhắc: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showFeedback(
    String message, {
    bool isError = false,
    bool isWarning = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFFEF4444)
            : isWarning
                ? const Color(0xFFF59E0B)
                : _primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.meal.mealDate;
    final dateText =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final timeText =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Nhắc chuẩn bị bữa ${widget.meal.slot.labelVi}',
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ngày ăn: $dateText',
            style: const TextStyle(color: _textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: _primary,
            title: const Text(
              'Bật thông báo nhắc chuẩn bị',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              'Nếu thiết bị từ chối quyền thông báo, nhắc vẫn hiển thị trong ứng dụng.',
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _enabled ? _pickTime : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: _background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.alarm_rounded,
                    color: _enabled ? _primary : _textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Giờ nhắc: $timeText',
                    style: TextStyle(
                      color: _enabled ? _textPrimary : _textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Chọn giờ',
                    style: TextStyle(
                      color: _enabled ? _primary : _textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Lưu lịch nhắc',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

