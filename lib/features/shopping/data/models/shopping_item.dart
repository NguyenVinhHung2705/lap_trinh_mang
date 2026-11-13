/// Represents a single item to buy in a shopping list (`chi_tiet_mua`).
///
/// Implements business rules:
/// - Planned quantity (`so_luong_can_mua`) must be strictly > 0.
/// - Actual bought quantity (`so_luong_da_mua`) must be >= 0.
/// - Clear separation between planned quantity, bought status, and sync status.
/// - Requires valid expiry date and storage location before pantry sync.
class ShoppingItem {
  ShoppingItem({
    required this.id,
    required this.listId,
    required this.foodId,
    required this.foodName,
    required this.unitId,
    required this.unitName,
    this.categoryId,
    this.categoryName,
    required this.plannedQuantity,
    this.actualQuantity = 0.0,
    this.isBought = false,
    this.isSynced = false,
    this.expiryDate,
    this.locationId,
    this.locationName,
    this.importDate,
    DateTime? createdAt,
    this.syncedAt,
    this.note,
  }) : createdAt = createdAt ?? DateTime.now() {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'ShoppingItem id must not be empty');
    }
    if (listId.trim().isEmpty) {
      throw ArgumentError.value(listId, 'listId', 'Shopping list id must not be empty');
    }
    if (foodId.trim().isEmpty) {
      throw ArgumentError.value(foodId, 'foodId', 'Food id must not be empty');
    }
    if (foodName.trim().isEmpty) {
      throw ArgumentError.value(foodName, 'foodName', 'Food name must not be empty');
    }
    if (unitId.trim().isEmpty) {
      throw ArgumentError.value(unitId, 'unitId', 'Unit id must not be empty');
    }
    if (unitName.trim().isEmpty) {
      throw ArgumentError.value(unitName, 'unitName', 'Unit name must not be empty');
    }
    if (plannedQuantity <= 0 || plannedQuantity.isNaN || plannedQuantity.isInfinite) {
      throw ArgumentError.value(
        plannedQuantity,
        'so_luong_can_mua',
        'Planned quantity must be a finite number > 0',
      );
    }
    if (actualQuantity < 0 || actualQuantity.isNaN || actualQuantity.isInfinite) {
      throw ArgumentError.value(
        actualQuantity,
        'so_luong_da_mua',
        'Actual quantity must be a finite number >= 0',
      );
    }
  }

  /// Firestore document ID (`ma_chi_tiet_mua`).
  final String id;

  /// Foreign key to parent shopping list (`ma_danh_sach`).
  final String listId;

  /// Food ID (`ma_thuc_pham`).
  final String foodId;

  /// Food display name (`ten_thuc_pham`).
  final String foodName;

  /// Unit ID (`ma_don_vi`).
  final String unitId;

  /// Unit display name or symbol (`ten_don_vi` / `ky_hieu`).
  final String unitName;

  /// Food category ID for grouping by aisle (`ma_danh_muc`).
  final String? categoryId;

  /// Food category name (`ten_danh_muc`).
  final String? categoryName;

  /// Planned quantity needed (`so_luong_can_mua` > 0).
  final double plannedQuantity;

  /// Actual quantity purchased (`so_luong_da_mua` >= 0).
  final double actualQuantity;

  /// Whether user marked this item as bought during shopping mode.
  final bool isBought;

  /// Whether this item has been synchronized to pantry batch (`da_dong_bo_kho`).
  final bool isSynced;

  /// Expiration date for newly created batch (`han_su_dung`).
  final DateTime? expiryDate;

  /// Target storage location in pantry (`ma_vi_tri`).
  final String? locationId;

  /// Storage location display name (`ten_vi_tri`).
  final String? locationName;

  /// Date when food was bought/imported (`ngay_nhap`). Defaults to now when syncing.
  final DateTime? importDate;

  /// Item creation timestamp.
  final DateTime createdAt;

  /// Timestamp when item was synced to pantry.
  final DateTime? syncedAt;

  /// Optional item notes.
  final String? note;

  /// Returns whether this item has all required data for pantry stock synchronization (MOD-02-07 / MOD-02-08).
  bool get isReadyForSync {
    return isBought &&
        actualQuantity > 0 &&
        expiryDate != null &&
        locationId != null &&
        locationId!.trim().isNotEmpty &&
        !isSynced;
  }

  /// Lists missing required fields for synchronization preview.
  List<String> get missingSyncFields {
    final missing = <String>[];
    if (!isBought) missing.add('Chưa đánh dấu đã mua');
    if (actualQuantity <= 0) missing.add('Số lượng thực mua phải > 0');
    if (expiryDate == null) missing.add('Chưa nhập hạn sử dụng');
    if (locationId == null || locationId!.trim().isEmpty) {
      missing.add('Chưa chọn vị trí lưu trữ');
    }
    return missing;
  }

  /// Serializes to a Firestore-compatible map matching `schema.sql`.
  Map<String, Object?> toMap() {
    return {
      'ma_danh_sach': listId,
      'ma_thuc_pham': foodId,
      'ten_thuc_pham': foodName,
      'ma_don_vi': unitId,
      'ten_don_vi': unitName,
      'ma_danh_muc': categoryId,
      'ten_danh_muc': categoryName,
      'so_luong_can_mua': plannedQuantity,
      'so_luong_da_mua': actualQuantity,
      'da_mua': isBought,
      'da_dong_bo_kho': isSynced,
      'han_su_dung': expiryDate?.toIso8601String(),
      'ma_vi_tri': locationId,
      'ten_vi_tri': locationName,
      'ngay_nhap': importDate?.toIso8601String(),
      'ngay_tao': createdAt.toIso8601String(),
      'ngay_dong_bo': syncedAt?.toIso8601String(),
      'ghi_chu': note?.trim(),
    };
  }

  /// Deserializes a Firestore map into [ShoppingItem].
  factory ShoppingItem.fromMap(Map<String, Object?> map, {required String id}) {
    final rawListId = map['ma_danh_sach'] as String?;
    final rawFoodId = map['ma_thuc_pham'] as String?;
    final rawFoodName = map['ten_thuc_pham'] as String? ?? 'Thực phẩm';
    final rawUnitId = map['ma_don_vi'] as String?;
    final rawUnitName = map['ten_don_vi'] as String? ?? '';
    final rawPlannedQty = (map['so_luong_can_mua'] as num?)?.toDouble();

    if (rawListId == null || rawFoodId == null || rawUnitId == null || rawPlannedQty == null) {
      throw FormatException('Missing required fields in ShoppingItem map for id=$id');
    }

    return ShoppingItem(
      id: id,
      listId: rawListId,
      foodId: rawFoodId,
      foodName: rawFoodName,
      unitId: rawUnitId,
      unitName: rawUnitName.isNotEmpty ? rawUnitName : 'đơn vị',
      categoryId: map['ma_danh_muc'] as String?,
      categoryName: map['ten_danh_muc'] as String?,
      plannedQuantity: rawPlannedQty,
      actualQuantity: (map['so_luong_da_mua'] as num?)?.toDouble() ?? 0.0,
      isBought: map['da_mua'] as bool? ?? false,
      isSynced: map['da_dong_bo_kho'] as bool? ?? false,
      expiryDate: _parseDateTime(map['han_su_dung']),
      locationId: map['ma_vi_tri'] as String?,
      locationName: map['ten_vi_tri'] as String?,
      importDate: _parseDateTime(map['ngay_nhap']),
      createdAt: _parseDateTime(map['ngay_tao']) ?? DateTime.now(),
      syncedAt: _parseDateTime(map['ngay_dong_bo']),
      note: map['ghi_chu'] as String?,
    );
  }

  static DateTime? _parseDateTime(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) {
      final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw.trim());
      if (dateOnly != null) {
        return DateTime(
          int.parse(dateOnly.group(1)!),
          int.parse(dateOnly.group(2)!),
          int.parse(dateOnly.group(3)!),
        );
      }
      return DateTime.parse(raw);
    }
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    throw ArgumentError.value(raw, 'dateTime', 'Unsupported datetime format');
  }

  /// Creates a copy with updated fields.
  ShoppingItem copyWith({
    String? id,
    String? listId,
    String? foodId,
    String? foodName,
    String? unitId,
    String? unitName,
    String? categoryId,
    bool clearCategory = false,
    String? categoryName,
    double? plannedQuantity,
    double? actualQuantity,
    bool? isBought,
    bool? isSynced,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    String? locationId,
    bool clearLocation = false,
    String? locationName,
    DateTime? importDate,
    bool clearImportDate = false,
    DateTime? createdAt,
    DateTime? syncedAt,
    bool clearSyncedAt = false,
    String? note,
    bool clearNote = false,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      unitId: unitId ?? this.unitId,
      unitName: unitName ?? this.unitName,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      categoryName: clearCategory ? null : (categoryName ?? this.categoryName),
      plannedQuantity: plannedQuantity ?? this.plannedQuantity,
      actualQuantity: actualQuantity ?? this.actualQuantity,
      isBought: isBought ?? this.isBought,
      isSynced: isSynced ?? this.isSynced,
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
      locationId: clearLocation ? null : (locationId ?? this.locationId),
      locationName: clearLocation ? null : (locationName ?? this.locationName),
      importDate: clearImportDate ? null : (importDate ?? this.importDate),
      createdAt: createdAt ?? this.createdAt,
      syncedAt: clearSyncedAt ? null : (syncedAt ?? this.syncedAt),
      note: clearNote ? null : (note ?? this.note),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShoppingItem &&
        other.id == id &&
        other.listId == listId &&
        other.foodId == foodId &&
        other.foodName == foodName &&
        other.unitId == unitId &&
        other.unitName == unitName &&
        other.categoryId == categoryId &&
        other.plannedQuantity == plannedQuantity &&
        other.actualQuantity == actualQuantity &&
        other.isBought == isBought &&
        other.isSynced == isSynced &&
        other.expiryDate == expiryDate &&
        other.locationId == locationId;
  }

  @override
  int get hashCode => Object.hash(
        id,
        listId,
        foodId,
        foodName,
        unitId,
        unitName,
        categoryId,
        plannedQuantity,
        actualQuantity,
        isBought,
        isSynced,
        expiryDate,
        locationId,
      );

  @override
  String toString() {
    return 'ShoppingItem(id: $id, food: $foodName, planned: $plannedQuantity $unitName, '
        'bought: $actualQuantity $unitName (isBought: $isBought), synced: $isSynced)';
  }
}

