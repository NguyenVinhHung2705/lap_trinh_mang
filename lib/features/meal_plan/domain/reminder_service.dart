import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/meal_repository.dart';
import '../data/models/meal.dart';

/// Result returned after scheduling or updating a meal reminder (`MOD-04-06`).
class ReminderScheduleResult {
  const ReminderScheduleResult({
    required this.reminderAt,
    required this.osNotificationScheduled,
    required this.inAppReminderSaved,
  });

  final DateTime reminderAt;
  final bool osNotificationScheduled;
  final bool inAppReminderSaved;

  bool get fellBackToInAppOnly => inAppReminderSaved && !osNotificationScheduled;
}

/// Read model for an in-app meal reminder stored in `thong_bao`.
class MealReminderNotification {
  const MealReminderNotification({
    required this.id,
    required this.userId,
    required this.mealId,
    required this.message,
    required this.scheduledAt,
    required this.isRead,
  });

  final String id;
  final String userId;
  final String mealId;
  final String message;
  final DateTime scheduledAt;
  final bool isRead;
}

/// Abstraction over local OS notifications for testability.
abstract interface class LocalNotificationScheduler {
  Future<bool> ensurePermission();
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  });
  Future<void> cancel(int id);
}

/// Android/iOS implementation using `flutter_local_notifications` and `timezone`.
class FlutterLocalNotificationScheduler implements LocalNotificationScheduler {
  FlutterLocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> _initIfNeeded() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  @override
  Future<bool> ensurePermission() async {
    // Web build (Vercel demo): no OS notifications → in-app reminder only.
    if (kIsWeb) return false;
    await _initIfNeeded();
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return true;

    final alreadyEnabled = await androidImpl.areNotificationsEnabled();
    if (alreadyEnabled == true) return true;

    final granted = await androidImpl.requestNotificationsPermission();
    return granted ?? false;
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    await _initIfNeeded();
    final tzDateTime = tz.TZDateTime.from(scheduledAt, tz.local);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'meal_reminders',
        'Nhắc chuẩn bị bữa ăn',
        channelDescription: 'Thông báo nhắc chuẩn bị bữa ăn theo kế hoạch',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzDateTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await _initIfNeeded();
    await _plugin.cancel(id);
  }
}

/// Manages meal preparation reminders (`MOD-04-06`) across OS notifications and `thong_bao`.
class ReminderService {
  ReminderService({
    required MealRepository mealRepository,
    LocalNotificationScheduler? scheduler,
    SupabaseClient? supabase,
  })  : _mealRepository = mealRepository,
        _scheduler = scheduler ?? FlutterLocalNotificationScheduler(),
        _customSupabase = supabase;

  final MealRepository _mealRepository;
  final LocalNotificationScheduler _scheduler;
  final SupabaseClient? _customSupabase;
  SupabaseClient get _db => _customSupabase ?? Supabase.instance.client;

  static const String notificationsTable = 'thong_bao';

  static bool _isMockUser(String userId) =>
      userId.isEmpty || userId.startsWith('mock_') || userId.startsWith('guest_');

  /// In-memory reminders for guest/offline mode.
  static final Map<String, MealReminderNotification> _memoryReminders = {};

  /// Deterministic row ID in `thong_bao` so rescheduling updates in place without duplicates.
  static String notificationDocId(String mealId) => 'meal_reminder_$mealId';

  static String _rowId(String userId, String mealId) =>
      'meal_reminder_${userId}_$mealId';

  /// Stable 31-bit integer ID for `flutter_local_notifications` derived deterministically from [mealId].
  static int notificationIntId(String mealId) {
    // FNV-1a instead of String.hashCode (not stable across restarts).
    var hash = 0x811c9dc5;
    for (final unit in mealId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  /// Schedules or updates a meal preparation reminder (`MOD-04-06`).
  ///
  /// Always saves an in-app `MEAL_REMINDER` record in `thong_bao`. If OS notification
  /// permission is denied (or running on web), falls back to in-app reminder only.
  Future<ReminderScheduleResult> scheduleMealReminder({
    required Meal meal,
    required DateTime reminderAt,
  }) async {
    if (!meal.isPlanned) {
      throw const MealPlanException(
        'Chỉ có thể đặt nhắc cho bữa ăn chưa hoàn thành.',
      );
    }
    if (!reminderAt.isAfter(DateTime.now())) {
      throw const MealPlanException('Thời gian nhắc phải ở tương lai.');
    }

    await _mealRepository.updateMealReminder(
      userId: meal.userId,
      mealId: meal.id,
      reminderAt: reminderAt,
    );

    final message = _buildReminderMessage(meal);
    await _upsertNotificationRecord(
      userId: meal.userId,
      mealId: meal.id,
      message: message,
      scheduledAt: reminderAt,
    );

    var osScheduled = false;
    try {
      if (await _scheduler.ensurePermission()) {
        await _scheduler.schedule(
          id: notificationIntId(meal.id),
          title: 'Nhắc chuẩn bị bữa ${meal.slot.labelVi}',
          body: message,
          scheduledAt: reminderAt,
        );
        osScheduled = true;
      }
    } catch (_) {
      osScheduled = false; // plugin unavailable → in-app only
    }

    return ReminderScheduleResult(
      reminderAt: reminderAt,
      osNotificationScheduled: osScheduled,
      inAppReminderSaved: true,
    );
  }

  /// Reschedules an existing reminder after a meal was moved (`MOD-04-05` + `MOD-04-06`).
  Future<ReminderScheduleResult?> rescheduleIfSet(Meal updatedMeal) async {
    final reminderAt = updatedMeal.reminderAt;
    if (reminderAt == null || !updatedMeal.isPlanned) return null;
    if (!reminderAt.isAfter(DateTime.now())) {
      await cancelMealReminder(
        userId: updatedMeal.userId,
        mealId: updatedMeal.id,
      );
      return null;
    }
    return scheduleMealReminder(meal: updatedMeal, reminderAt: reminderAt);
  }

  /// Cancels both the local OS notification and the `thong_bao` reminder record.
  Future<void> cancelMealReminder({
    required String userId,
    required String mealId,
  }) async {
    try {
      await _scheduler.cancel(notificationIntId(mealId));
    } catch (_) {}

    _memoryReminders.remove(_rowId(userId, mealId));
    if (!_isMockUser(userId)) {
      try {
        await _db
            .from(notificationsTable)
            .delete()
            .eq('id', _rowId(userId, mealId));
      } catch (_) {}
    }

    final meal =
        await _mealRepository.getMealById(userId: userId, mealId: mealId);
    if (meal != null && meal.isPlanned && meal.reminderAt != null) {
      await _mealRepository.updateMealReminder(
        userId: userId,
        mealId: mealId,
        reminderAt: null,
      );
    }
  }

  /// Streams unread in-app `MEAL_REMINDER` records whose trigger time has arrived.
  Stream<List<MealReminderNotification>> watchDueInAppReminders(String userId) {
    List<MealReminderNotification> due(Iterable<MealReminderNotification> all) {
      final now = DateTime.now();
      return all
          .where((n) => !n.isRead && !n.scheduledAt.isAfter(now))
          .toList();
    }

    if (_isMockUser(userId)) {
      return Stream.value(
        due(_memoryReminders.values.where((n) => n.userId == userId)),
      );
    }

    return _db
        .from(notificationsTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) => due(rows
            .where((r) => r['loai'] == 'MEAL_REMINDER')
            .map(_mapNotification)))
        .handleError((_) => <MealReminderNotification>[]);
  }

  /// Marks an in-app `MEAL_REMINDER` as read (`da_doc = true`).
  Future<void> markAsRead({
    required String userId,
    required String notificationId,
  }) async {
    final mem = _memoryReminders[notificationId];
    if (mem != null) {
      _memoryReminders[notificationId] = MealReminderNotification(
        id: mem.id,
        userId: mem.userId,
        mealId: mem.mealId,
        message: mem.message,
        scheduledAt: mem.scheduledAt,
        isRead: true,
      );
    }
    if (_isMockUser(userId)) return;

    try {
      await _db
          .from(notificationsTable)
          .update({'da_doc': true}).eq('id', notificationId);
    } catch (_) {}
  }

  Future<void> _upsertNotificationRecord({
    required String userId,
    required String mealId,
    required String message,
    required DateTime scheduledAt,
  }) async {
    final id = _rowId(userId, mealId);
    _memoryReminders[id] = MealReminderNotification(
      id: id,
      userId: userId,
      mealId: mealId,
      message: message,
      scheduledAt: scheduledAt,
      isRead: false,
    );
    if (_isMockUser(userId)) return;

    try {
      await _db.from(notificationsTable).upsert({
        'id': id,
        'user_id': userId,
        'meal_id': MealRepository.rowMealId(userId, mealId),
        'loai': 'MEAL_REMINDER',
        'noi_dung': message,
        'thoi_diem_gui': scheduledAt.toUtc().toIso8601String(),
        'da_doc': false,
      });
    } catch (_) {
      // Keep the in-memory reminder so the demo still works offline.
    }
  }

  static String _buildReminderMessage(Meal meal) {
    final d = meal.mealDate;
    final dateText =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return 'Đến giờ chuẩn bị bữa ${meal.slot.labelVi} ngày $dateText.';
  }

  static MealReminderNotification _mapNotification(Map<String, dynamic> data) {
    final userId = data['user_id'] as String? ?? '';
    final rawTime = data['thoi_diem_gui'];
    final scheduledAt = rawTime is String
        ? DateTime.parse(rawTime).toLocal()
        : DateTime.now();
    final rowMealId = data['meal_id'] as String? ?? '';

    return MealReminderNotification(
      id: data['id'] as String? ?? '',
      userId: userId,
      mealId: MealRepository.appMealId(userId, rowMealId),
      message: data['noi_dung'] as String? ?? '',
      scheduledAt: scheduledAt,
      isRead: data['da_doc'] as bool? ?? false,
    );
  }
}
