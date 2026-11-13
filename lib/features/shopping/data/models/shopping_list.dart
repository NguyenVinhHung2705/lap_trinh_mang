/// Lifecycle state of a shopping list (`trang_thai` in `danh_sach_mua`).
enum ShoppingListStatus {
  open('OPEN', 'Đang mở'),
  completed('COMPLETED', 'Đã hoàn tất'),
  cancelled('CANCELLED', 'Đã hủy');

  const ShoppingListStatus(this.value, this.labelVi);

  /// Canonical persistence value matching `danh_sach_mua.trang_thai`.
  final String value;

  /// Vietnamese label displayed in the UI.
  final String labelVi;

  /// Parses a persisted string into [ShoppingListStatus], throwing [ArgumentError] if unknown.
  static ShoppingListStatus fromValue(String raw) {
    final normalized = raw.trim().toUpperCase();
    for (final status in ShoppingListStatus.values) {
      if (status.value == normalized) return status;
    }
    throw ArgumentError.value(raw, 'trang_thai', 'Unknown shopping list status');
  }
}

/// Represents a shopping list (`danh_sach_mua`) owned by a user (`ma_tai_khoan = uid`).
class ShoppingList {
  ShoppingList({
    required this.id,
    required this.userId,
    required this.name,
    DateTime? createdAt,
    this.status = ShoppingListStatus.open,
    this.completedAt,
    this.note,
    this.totalItems = 0,
    this.boughtItems = 0,
    this.syncedItems = 0,
  }) : createdAt = createdAt ?? DateTime.now() {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'ShoppingList id must not be empty');
    }
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'User id must not be empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'ShoppingList name must not be empty');
    }
    if (status == ShoppingListStatus.completed && completedAt == null) {
      throw ArgumentError(
        'completedAt must be provided when shopping list is COMPLETED',
      );
    }
    if (totalItems < 0 || boughtItems < 0 || syncedItems < 0) {
      throw ArgumentError('Item counts must be non-negative integers');
    }
  }

  /// Firestore document ID (`ma_danh_sach`).
  final String id;

  /// Owner Firebase Auth UID (`ma_tai_khoan`).
  final String userId;

  /// List display name (`ten_danh_sach`).
  final String name;

  /// Creation timestamp (`ngay_tao`).
  final DateTime createdAt;

  /// Current workflow status (`trang_thai`).
  final ShoppingListStatus status;

  /// Completion timestamp when shopping sync finishes (`ngay_hoan_tat`).
  final DateTime? completedAt;

  /// Optional user notes.
  final String? note;

  /// Cached item statistics for quick card rendering.
  final int totalItems;
  final int boughtItems;
  final int syncedItems;

  bool get isOpen => status == ShoppingListStatus.open;
  bool get isCompleted => status == ShoppingListStatus.completed;
  bool get isCancelled => status == ShoppingListStatus.cancelled;

  /// Progress ratio from 0.0 to 1.0 based on bought items.
  double get progressRatio =>
      totalItems > 0 ? (boughtItems / totalItems).clamp(0.0, 1.0) : 0.0;

  /// Formatted percentage integer (0-100).
  int get progressPercent => (progressRatio * 100).round();

  /// Whether all items have been bought and synced to pantry.
  bool get isFullySynced => totalItems > 0 && syncedItems >= totalItems;

  /// Serializes to a Firestore-compatible map matching `schema.sql`.
  Map<String, Object?> toMap() {
    return {
      'ma_tai_khoan': userId,
      'ten_danh_sach': name.trim(),
      'ngay_tao': createdAt.toIso8601String(),
      'trang_thai': status.value,
      'ngay_hoan_tat': completedAt?.toIso8601String(),
      'ghi_chu': note?.trim(),
      'so_luong_muc': totalItems,
      'so_luong_da_mua_count': boughtItems,
      'so_luong_da_dong_bo_count': syncedItems,
    };
  }

  /// Deserializes a Firestore map into [ShoppingList].
  factory ShoppingList.fromMap(Map<String, Object?> map, {required String id}) {
    final rawUserId = map['ma_tai_khoan'] as String?;
    final rawName = map['ten_danh_sach'] as String?;
    final rawStatus = map['trang_thai'] as String?;

    if (rawUserId == null || rawName == null || rawStatus == null) {
      throw FormatException('Missing required fields in ShoppingList map for id=$id');
    }

    return ShoppingList(
      id: id,
      userId: rawUserId,
      name: rawName,
      createdAt: _parseDateTime(map['ngay_tao']) ?? DateTime.now(),
      status: ShoppingListStatus.fromValue(rawStatus),
      completedAt: _parseDateTime(map['ngay_hoan_tat']),
      note: map['ghi_chu'] as String?,
      totalItems: (map['so_luong_muc'] as num?)?.toInt() ?? 0,
      boughtItems: (map['so_luong_da_mua_count'] as num?)?.toInt() ?? 0,
      syncedItems: (map['so_luong_da_dong_bo_count'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime? _parseDateTime(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.parse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    throw ArgumentError.value(raw, 'dateTime', 'Unsupported datetime format');
  }

  /// Creates a copy with optional updated fields.
  ShoppingList copyWith({
    String? id,
    String? userId,
    String? name,
    DateTime? createdAt,
    ShoppingListStatus? status,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? note,
    bool clearNote = false,
    int? totalItems,
    int? boughtItems,
    int? syncedItems,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      note: clearNote ? null : (note ?? this.note),
      totalItems: totalItems ?? this.totalItems,
      boughtItems: boughtItems ?? this.boughtItems,
      syncedItems: syncedItems ?? this.syncedItems,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShoppingList &&
        other.id == id &&
        other.userId == userId &&
        other.name == name &&
        other.createdAt == createdAt &&
        other.status == status &&
        other.completedAt == completedAt &&
        other.note == note &&
        other.totalItems == totalItems &&
        other.boughtItems == boughtItems &&
        other.syncedItems == syncedItems;
  }

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        name,
        createdAt,
        status,
        completedAt,
        note,
        totalItems,
        boughtItems,
        syncedItems,
      );

  @override
  String toString() {
    return 'ShoppingList(id: $id, userId: $userId, name: $name, '
        'status: ${status.value}, items: $boughtItems/$totalItems, synced: $syncedItems)';
  }
}

