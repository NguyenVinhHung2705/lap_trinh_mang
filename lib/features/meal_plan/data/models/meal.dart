/// Meal slot within a day (`khung_bua` in `bua_an`).
enum MealSlot {
  breakfast('BREAKFAST', 'Sáng'),
  lunch('LUNCH', 'Trưa'),
  dinner('DINNER', 'Tối'),
  snack('SNACK', 'Phụ');

  const MealSlot(this.value, this.labelVi);

  /// Canonical persistence value matching `bua_an.khung_bua`.
  final String value;

  /// Vietnamese label displayed in the UI.
  final String labelVi;

  /// Parses a persisted string into [MealSlot], throwing [ArgumentError] if unknown.
  static MealSlot fromValue(String raw) {
    final normalized = raw.trim().toUpperCase();
    for (final slot in MealSlot.values) {
      if (slot.value == normalized) return slot;
    }
    throw ArgumentError.value(raw, 'khung_bua', 'Unknown meal slot');
  }
}

/// Lifecycle state of a planned meal (`trang_thai` in `bua_an`).
enum MealStatus {
  planned('PLANNED', 'Đã lên lịch'),
  completed('COMPLETED', 'Đã hoàn thành'),
  cancelled('CANCELLED', 'Đã hủy');

  const MealStatus(this.value, this.labelVi);

  /// Canonical persistence value matching `bua_an.trang_thai`.
  final String value;

  /// Vietnamese label displayed in the UI.
  final String labelVi;

  /// Parses a persisted string into [MealStatus], throwing [ArgumentError] if unknown.
  static MealStatus fromValue(String raw) {
    final normalized = raw.trim().toUpperCase();
    for (final status in MealStatus.values) {
      if (status.value == normalized) return status;
    }
    throw ArgumentError.value(raw, 'trang_thai', 'Unknown meal status');
  }
}

/// Represents a user meal plan entry (`bua_an`) for a specific local date and slot.
class Meal {
  Meal({
    required this.id,
    required this.userId,
    required DateTime mealDate,
    required this.slot,
    this.reminderAt,
    this.status = MealStatus.planned,
    this.completedAt,
  }) : mealDate = normalizeLocalDate(mealDate) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Meal id must not be empty');
    }
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'User id must not be empty');
    }
    if (status == MealStatus.completed && completedAt == null) {
      throw ArgumentError(
        'completedAt must be provided when meal status is COMPLETED',
      );
    }
  }

  /// Firestore document ID (`ma_bua_an`).
  final String id;

  /// Owner Firebase Auth UID (`ma_tai_khoan`).
  final String userId;

  /// Local calendar date normalized to midnight (`ngay_an`).
  final DateTime mealDate;

  /// Meal slot within [mealDate] (`khung_bua`).
  final MealSlot slot;

  /// Optional scheduled reminder timestamp (`gio_nhac`).
  final DateTime? reminderAt;

  /// Current workflow status (`trang_thai`).
  final MealStatus status;

  /// Timestamp when stock deduction completed (`hoan_thanh_luc`).
  final DateTime? completedAt;

  bool get isPlanned => status == MealStatus.planned;
  bool get isCompleted => status == MealStatus.completed;
  bool get isCancelled => status == MealStatus.cancelled;

  /// Strips time components in local timezone so calendar grouping never shifts days across UTC.
  static DateTime normalizeLocalDate(DateTime date) {
    final local = date.isUtc ? date.toLocal() : date;
    return DateTime(local.year, local.month, local.day);
  }

  /// Formats a date as `YYYY-MM-DD` in local timezone for Firestore queries and doc keys.
  static String formatLocalDate(DateTime date) {
    final normalized = normalizeLocalDate(date);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Parses a `YYYY-MM-DD` string or ISO timestamp into a normalized local [DateTime].
  static DateTime parseLocalDate(Object raw) {
    if (raw is DateTime) return normalizeLocalDate(raw);
    if (raw is String) {
      final dateOnlyMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw.trim());
      if (dateOnlyMatch != null) {
        return DateTime(
          int.parse(dateOnlyMatch.group(1)!),
          int.parse(dateOnlyMatch.group(2)!),
          int.parse(dateOnlyMatch.group(3)!),
        );
      }
      return normalizeLocalDate(DateTime.parse(raw));
    }
    if (raw is int) {
      return normalizeLocalDate(DateTime.fromMillisecondsSinceEpoch(raw));
    }
    throw ArgumentError.value(raw, 'ngay_an', 'Unsupported date format');
  }

  /// Builds a deterministic document ID to enforce `UNIQUE(ma_tai_khoan, ngay_an, khung_bua)` in Firestore.
  static String buildDeterministicId(DateTime date, MealSlot slot) {
    return '${formatLocalDate(date)}_${slot.value}';
  }

  /// Serializes to a Firestore-compatible map using the project's canonical field names.
  Map<String, Object?> toMap() {
    return {
      'ma_tai_khoan': userId,
      'ngay_an': formatLocalDate(mealDate),
      'khung_bua': slot.value,
      'gio_nhac': reminderAt?.toIso8601String(),
      'trang_thai': status.value,
      'hoan_thanh_luc': completedAt?.toIso8601String(),
    };
  }

  /// Deserializes a map into [Meal]. Repository layer should convert Firestore `Timestamp` to `DateTime`/`String`.
  factory Meal.fromMap(Map<String, Object?> map, {required String id}) {
    final rawUserId = map['ma_tai_khoan'] as String?;
    final rawDate = map['ngay_an'];
    final rawSlot = map['khung_bua'] as String?;
    final rawStatus = map['trang_thai'] as String?;

    if (rawUserId == null || rawDate == null || rawSlot == null || rawStatus == null) {
      throw FormatException('Missing required fields in Meal map for id=$id');
    }

    return Meal(
      id: id,
      userId: rawUserId,
      mealDate: parseLocalDate(rawDate),
      slot: MealSlot.fromValue(rawSlot),
      reminderAt: _parseNullableDateTime(map['gio_nhac']),
      status: MealStatus.fromValue(rawStatus),
      completedAt: _parseNullableDateTime(map['hoan_thanh_luc']),
    );
  }

  static DateTime? _parseNullableDateTime(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.parse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    throw ArgumentError.value(raw, 'dateTime', 'Unsupported datetime format');
  }

  /// Creates a copy with updated fields. Pass [clearReminderAt] or [clearCompletedAt] to reset nullable timestamps.
  Meal copyWith({
    String? id,
    String? userId,
    DateTime? mealDate,
    MealSlot? slot,
    DateTime? reminderAt,
    bool clearReminderAt = false,
    MealStatus? status,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return Meal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mealDate: mealDate ?? this.mealDate,
      slot: slot ?? this.slot,
      reminderAt: clearReminderAt ? null : (reminderAt ?? this.reminderAt),
      status: status ?? this.status,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Meal &&
        other.id == id &&
        other.userId == userId &&
        other.mealDate == mealDate &&
        other.slot == slot &&
        other.reminderAt == reminderAt &&
        other.status == status &&
        other.completedAt == completedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        mealDate,
        slot,
        reminderAt,
        status,
        completedAt,
      );

  @override
  String toString() {
    return 'Meal(id: $id, userId: $userId, mealDate: ${formatLocalDate(mealDate)}, '
        'slot: ${slot.value}, status: ${status.value})';
  }
}

