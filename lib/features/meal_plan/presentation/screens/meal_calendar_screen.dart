import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/meal.dart';
import '../providers/meal_calendar_provider.dart';

/// Callback invoked when the user taps a meal slot on the calendar.
typedef MealSlotTapCallback = void Function(
  DateTime date,
  MealSlot slot,
  Meal? existingMeal,
);

/// Read-only weekly/monthly meal plan calendar screen (`MOD-04-01`).
class MealCalendarScreen extends ConsumerWidget {
  const MealCalendarScreen({
    super.key,
    this.onMealSlotTap,
  });

  final MealSlotTapCallback? onMealSlotTap;

  // Design system color tokens
  static const Color _primary = Color(0xFF16A36A);
  static const Color _primaryTint = Color(0xFFE7F6EF);
  static const Color _background = Color(0xFFF7F9F7);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _border = Color(0xFFE5EBE6);
  static const Color _textPrimary = Color(0xFF202B26);
  static const Color _textSecondary = Color(0xFF77847C);
  static const Color _plannedBlue = Color(0xFF2563EB);
  static const Color _plannedBlueTint = Color(0xFFEFF6FF);
  static const Color _completedGray = Color(0xFF6B7280);
  static const Color _completedGrayTint = Color(0xFFF3F4F6);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final calendarState = ref.watch(mealCalendarControllerProvider);
    final controller = ref.read(mealCalendarControllerProvider.notifier);
    final mealsAsync = ref.watch(mealsInRangeProvider);

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Kế hoạch bữa ăn',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: controller.goToToday,
            child: const Text(
              'Hôm nay',
              style: TextStyle(
                color: _primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: userId == null || userId.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Vui lòng đăng nhập để xem lịch bữa ăn cá nhân.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _textSecondary, fontSize: 14),
                ),
              ),
            )
          : Column(
              children: [
                _CalendarHeader(
                  state: calendarState,
                  onPrevious: controller.previousPeriod,
                  onNext: controller.nextPeriod,
                  onModeChanged: controller.setViewMode,
                ),
                Expanded(
                  child: mealsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: _primary),
                    ),
                    error: (error, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Không thể tải lịch bữa ăn: $error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFEF4444)),
                        ),
                      ),
                    ),
                    data: (meals) {
                      final grouped = groupMealsByDateAndSlot(meals);
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          if (calendarState.viewMode == CalendarViewMode.week)
                            _WeekStrip(
                              rangeStart: calendarState.rangeStart,
                              selectedDate: calendarState.selectedDate,
                              groupedMeals: grouped,
                              onSelectDate: controller.selectDate,
                            )
                          else
                            _MonthGrid(
                              focusedDate: calendarState.focusedDate,
                              selectedDate: calendarState.selectedDate,
                              groupedMeals: grouped,
                              onSelectDate: controller.selectDate,
                            ),
                          const SizedBox(height: 20),
                          _DaySlotsSection(
                            selectedDate: calendarState.selectedDate,
                            slotsForDay: grouped[
                                    Meal.formatLocalDate(calendarState.selectedDate)] ??
                                const <MealSlot, Meal>{},
                            onMealSlotTap: onMealSlotTap,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.state,
    required this.onPrevious,
    required this.onNext,
    required this.onModeChanged,
  });

  final MealCalendarState state;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<CalendarViewMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MealCalendarScreen._surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
                color: MealCalendarScreen._textPrimary,
                tooltip: 'Kỳ trước',
              ),
              Expanded(
                child: Text(
                  _formatRangeTitle(state),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: MealCalendarScreen._textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
                color: MealCalendarScreen._textPrimary,
                tooltip: 'Kỳ sau',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: MealCalendarScreen._background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MealCalendarScreen._border),
            ),
            child: Row(
              children: CalendarViewMode.values.map((mode) {
                final selected = state.viewMode == mode;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onModeChanged(mode),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? MealCalendarScreen._primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        mode.labelVi,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : MealCalendarScreen._textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatRangeTitle(MealCalendarState state) {
    if (state.viewMode == CalendarViewMode.month) {
      return 'Tháng ${state.focusedDate.month}/${state.focusedDate.year}';
    }
    final start = state.rangeStart;
    final end = state.rangeEnd;
    String ddMm(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return '${ddMm(start)} – ${ddMm(end)}/${end.year}';
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.rangeStart,
    required this.selectedDate,
    required this.groupedMeals,
    required this.onSelectDate,
  });

  final DateTime rangeStart;
  final DateTime selectedDate;
  final Map<String, Map<MealSlot, Meal>> groupedMeals;
  final ValueChanged<DateTime> onSelectDate;

  static const _weekdayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final today = Meal.normalizeLocalDate(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MealCalendarScreen._surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MealCalendarScreen._border),
      ),
      child: Row(
        children: List.generate(7, (index) {
          final day = rangeStart.add(Duration(days: index));
          final dayMeals =
              groupedMeals[Meal.formatLocalDate(day)]?.values.toList() ??
                  const <Meal>[];
          return Expanded(
            child: _DayCell(
              label: _weekdayLabels[index],
              dayNumber: day.day,
              isSelected: day == selectedDate,
              isToday: day == today,
              meals: dayMeals,
              onTap: () => onSelectDate(day),
            ),
          );
        }),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.focusedDate,
    required this.selectedDate,
    required this.groupedMeals,
    required this.onSelectDate,
  });

  final DateTime focusedDate;
  final DateTime selectedDate;
  final Map<String, Map<MealSlot, Meal>> groupedMeals;
  final ValueChanged<DateTime> onSelectDate;

  static const _weekdayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final today = Meal.normalizeLocalDate(DateTime.now());
    final firstDay = DateTime(focusedDate.year, focusedDate.month, 1);
    final daysInMonth = DateTime(focusedDate.year, focusedDate.month + 1, 0).day;
    final leadingEmpty = firstDay.weekday - 1;
    final totalCells = ((leadingEmpty + daysInMonth + 6) ~/ 7) * 7;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MealCalendarScreen._surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MealCalendarScreen._border),
      ),
      child: Column(
        children: [
          Row(
            children: _weekdayLabels
                .map(
                  (w) => Expanded(
                    child: Text(
                      w,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: MealCalendarScreen._textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 4,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (_, index) {
              final dayOffset = index - leadingEmpty;
              if (dayOffset < 0 || dayOffset >= daysInMonth) {
                return const SizedBox.shrink();
              }
              final day = DateTime(
                focusedDate.year,
                focusedDate.month,
                dayOffset + 1,
              );
              final dayMeals =
                  groupedMeals[Meal.formatLocalDate(day)]?.values.toList() ??
                      const <Meal>[];
              return _DayCell(
                dayNumber: day.day,
                isSelected: day == selectedDate,
                isToday: day == today,
                meals: dayMeals,
                onTap: () => onSelectDate(day),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    this.label,
    required this.dayNumber,
    required this.isSelected,
    required this.isToday,
    required this.meals,
    required this.onTap,
  });

  final String? label;
  final int dayNumber;
  final bool isSelected;
  final bool isToday;
  final List<Meal> meals;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPlanned = meals.any((m) => m.isPlanned);
    final hasCompleted = meals.any((m) => m.isCompleted);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? MealCalendarScreen._primary
              : isToday
                  ? MealCalendarScreen._primaryTint
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (label != null) ...[
              Text(
                label!,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white.withOpacity(0.9)
                      : MealCalendarScreen._textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              '$dayNumber',
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : isToday
                        ? MealCalendarScreen._primary
                        : MealCalendarScreen._textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasPlanned)
                  _Dot(
                    color: isSelected
                        ? Colors.white
                        : MealCalendarScreen._plannedBlue,
                  ),
                if (hasPlanned && hasCompleted) const SizedBox(width: 3),
                if (hasCompleted)
                  _Dot(
                    color: isSelected
                        ? Colors.white.withOpacity(0.7)
                        : MealCalendarScreen._completedGray,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _DaySlotsSection extends StatelessWidget {
  const _DaySlotsSection({
    required this.selectedDate,
    required this.slotsForDay,
    this.onMealSlotTap,
  });

  final DateTime selectedDate;
  final Map<MealSlot, Meal> slotsForDay;
  final MealSlotTapCallback? onMealSlotTap;

  @override
  Widget build(BuildContext context) {
    final formattedDate =
        '${selectedDate.day.toString().padLeft(2, '0')}/'
        '${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bữa ăn ngày $formattedDate',
          style: const TextStyle(
            color: MealCalendarScreen._textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...MealSlot.values.map((slot) {
          final meal = slotsForDay[slot];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SlotSummaryCard(
              slot: slot,
              meal: meal,
              onTap: onMealSlotTap == null
                  ? null
                  : () => onMealSlotTap!(selectedDate, slot, meal),
            ),
          );
        }),
      ],
    );
  }
}

class _SlotSummaryCard extends StatelessWidget {
  const _SlotSummaryCard({
    required this.slot,
    required this.meal,
    this.onTap,
  });

  final MealSlot slot;
  final Meal? meal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final status = meal?.status;
    final Color badgeBg;
    final Color badgeFg;
    final String badgeText;
    final String subtitle;

    if (status == MealStatus.completed) {
      badgeBg = MealCalendarScreen._completedGrayTint;
      badgeFg = MealCalendarScreen._completedGray;
      badgeText = 'Đã hoàn thành';
      subtitle = 'Đã ghi nhận tiêu thụ & trừ kho';
    } else if (status == MealStatus.planned) {
      badgeBg = MealCalendarScreen._plannedBlueTint;
      badgeFg = MealCalendarScreen._plannedBlue;
      badgeText = 'Đã lên lịch';
      subtitle = 'Chưa trừ kho · Nhấn để xem hoặc sửa';
    } else {
      badgeBg = MealCalendarScreen._background;
      badgeFg = MealCalendarScreen._textSecondary;
      badgeText = 'Trống';
      subtitle = 'Chưa có món · Nhấn để lập kế hoạch';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MealCalendarScreen._surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MealCalendarScreen._border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Bữa ${slot.labelVi}',
                        style: const TextStyle(
                          color: MealCalendarScreen._textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            color: badgeFg,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: MealCalendarScreen._textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: MealCalendarScreen._textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

