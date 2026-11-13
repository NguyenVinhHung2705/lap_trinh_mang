import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
    await _initIfNeeded();
    await _plugin.cancel(id);
  }
}

/// Manages meal preparation reminders (`MOD-04-06`) across OS notifications and `thong_bao`.
class ReminderService {
  ReminderService({
    required MealRepository mealRepository,
    LocalNotificationScheduler? scheduler,
    FirebaseFirestore? firestore,
  })  : _mealRepository = mealRepository,
        _scheduler = scheduler ?? FlutterLocalNotificationScheduler(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final MealRepository _mealRepository;
  final LocalNotificationScheduler _scheduler;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _notificationsRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('notifications');
  }

  /// Deterministic document ID in `thong_bao` so rescheduling updates in place without duplicates.
  static String notificationDocId(String mealId) => 'meal_reminder_$mealId';

  /// Stable 31-bit integer ID for `flutter_local_notifications` derived deterministically from [mealId].
  static int notificationIntId(String mealId) {
    // Use FNV-1a instead of String.hashCode because Dart's hashCode is not guaranteed stable across restarts.
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
  /// permission is denied, gracefully falls back to in-app reminder only.
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
      throw const MealPlanException(
        'Thời gian nhắc phải ở tương lai.',
      );
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

    final hasPermission = await _scheduler.ensurePermission();
    if (hasPermission) {
      await _scheduler.schedule(
        id: notificationIntId(meal.id),
        title: 'Nhắc chuẩn bị bữa ${meal.slot.labelVi}',
        body: message,
        scheduledAt: reminderAt,
      );
    }

    return ReminderScheduleResult(
      reminderAt: reminderAt,
      osNotificationScheduled: hasPermission,
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
    await _scheduler.cancel(notificationIntId(mealId));
    await _notificationsRef(userId).doc(notificationDocId(mealId)).delete();

    final meal = await _mealRepository.getMealById(userId: userId, mealId: mealId);
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
    return _notificationsRef(userId)
        .where('loai', isEqualTo: 'MEAL_REMINDER')
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      return snapshot.docs
          .map((doc) => _mapNotification(doc.id, doc.data()))
          .where((n) => !n.isRead && !n.scheduledAt.isAfter(now))
          .toList();
    });
  }

  /// Marks an in-app `MEAL_REMINDER` as read (`da_doc = true`).
  Future<void> markAsRead({
    required String userId,
    required String notificationId,
  }) async {
    await _notificationsRef(userId).doc(notificationId).update({'da_doc': true});
  }

  Future<void> _upsertNotificationRecord({
    required String userId,
    required String mealId,
    required String message,
    required DateTime scheduledAt,
  }) async {
    await _notificationsRef(userId).doc(notificationDocId(mealId)).set({
      'ma_tai_khoan': userId,
      'ma_lo': null,
      'ma_bua_an': mealId,
      'loai': 'MEAL_REMINDER',
      'noi_dung': message,
      'thoi_diem_gui': scheduledAt.toIso8601String(),
      'da_doc': false,
    });
  }

  static String _buildReminderMessage(Meal meal) {
    final d = meal.mealDate;
    final dateText =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return 'Đến giờ chuẩn bị bữa ${meal.slot.labelVi} ngày $dateText.';
  }

  static MealReminderNotification _mapNotification(
    String id,
    Map<String, dynamic> data,
  ) {
    final rawTime = data['thoi_diem_gui'];
    final DateTime scheduledAt;
    if (rawTime is Timestamp) {
      scheduledAt = rawTime.toDate();
    } else if (rawTime is String) {
      scheduledAt = DateTime.parse(rawTime);
    } else {
      scheduledAt = DateTime.now();
    }

    return MealReminderNotification(
      id: id,
      userId: data['ma_tai_khoan'] as String? ?? '',
      mealId: data['ma_bua_an'] as String? ?? '',
      message: data['noi_dung'] as String? ?? '',
      scheduledAt: scheduledAt,
      isRead: data['da_doc'] as bool? ?? false,
    );
  }
}
