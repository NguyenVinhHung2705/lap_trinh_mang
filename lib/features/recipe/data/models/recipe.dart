/// Origin source of a recipe (`nguon` in `cong_thuc`).
enum RecipeSource {
  user('USER', 'Tự tạo'),
  system('SYSTEM', 'Hệ thống'),
  community('COMMUNITY', 'Cộng đồng');

  const RecipeSource(this.value, this.labelVi);

  final String value;
  final String labelVi;

  static RecipeSource fromValue(String raw) {
    final normalized = raw.trim().toUpperCase();
    for (final source in RecipeSource.values) {
      if (source.value == normalized) return source;
    }
    return RecipeSource.user;
  }
}

/// Access scope of a recipe (`pham_vi_hien_thi` in `cong_thuc`).
enum RecipeVisibility {
  public('PUBLIC', 'Công khai'),
  private('PRIVATE', 'Riêng tư'),
  system('SYSTEM', 'Hệ thống');

  const RecipeVisibility(this.value, this.labelVi);

  final String value;
  final String labelVi;

  static RecipeVisibility fromValue(String raw) {
    final normalized = raw.trim().toUpperCase();
    for (final vis in RecipeVisibility.values) {
      if (vis.value == normalized) return vis;
    }
    return RecipeVisibility.private;
  }
}

/// Represents a cooking recipe entity (`cong_thuc`).
///
/// Fully compatible with Cloud Firestore schema and `MOD-04` integration contract.
class Recipe {
  Recipe({
    required this.id,
    required this.authorId,
    required this.name,
    this.description,
    required this.instructions,
    this.imageUrl,
    required this.baseServings,
    required this.cookingMinutes,
    this.source = RecipeSource.user,
    this.visibility = RecipeVisibility.private,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now() {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Recipe id must not be empty');
    }
    if (authorId.trim().isEmpty) {
      throw ArgumentError.value(authorId, 'authorId', 'Author id must not be empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Recipe name must not be empty');
    }
    if (baseServings <= 0 || baseServings.isNaN || baseServings.isInfinite) {
      throw ArgumentError.value(
        baseServings,
        'khau_phan',
        'Base servings must be a finite number > 0',
      );
    }
    if (cookingMinutes < 0) {
      throw ArgumentError.value(
        cookingMinutes,
        'thoi_gian_nau',
        'Cooking minutes must be >= 0',
      );
    }
  }

  /// Firestore document ID (`ma_cong_thuc`).
  final String id;

  /// Author user UID (`ma_tac_gia`).
  final String authorId;

  /// Recipe title (`ten_mon`).
  final String name;

  /// Optional description (`mo_ta`).
  final String? description;

  /// Step-by-step cooking instructions (`cach_lam`).
  final String instructions;

  /// Optional cover image URL (`hinh_anh`).
  final String? imageUrl;

  /// Base serving size, e.g. 2 or 4 (`khau_phan`, > 0).
  final double baseServings;

  /// Cooking time in minutes (`thoi_gian_nau`, >= 0).
  final int cookingMinutes;

  /// Recipe source category (`nguon`).
  final RecipeSource source;

  /// Visibility scope (`pham_vi_hien_thi`).
  final RecipeVisibility visibility;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last modification timestamp.
  final DateTime updatedAt;

  /// Checks if [userId] is allowed to view this recipe (Public, System, or Owner).
  bool canUserAccess(String userId) {
    if (visibility == RecipeVisibility.public ||
        visibility == RecipeVisibility.system ||
        source == RecipeSource.system) {
      return true;
    }
    return authorId == userId;
  }

  /// Checks if [userId] is the author/owner who can edit or delete this recipe.
  bool isAuthor(String userId) => authorId == userId;

  /// Serializes to a Firestore map using canonical schema keys.
  Map<String, Object?> toMap() {
    return {
      'ma_tac_gia': authorId,
      'ten_mon': name,
      'mo_ta': description,
      'cach_lam': instructions,
      'hinh_anh': imageUrl,
      'khau_phan': baseServings,
      'thoi_gian_nau': cookingMinutes,
      'nguon': source.value,
      'pham_vi_hien_thi': visibility.value,
      'ngay_tao': createdAt.toIso8601String(),
      'ngay_cap_nhat': updatedAt.toIso8601String(),
    };
  }

  /// Deserializes a Firestore map into [Recipe].
  factory Recipe.fromMap(Map<String, Object?> map, {required String id}) {
    final rawAuthorId = map['ma_tac_gia'] as String?;
    final rawName = map['ten_mon'] as String?;
    final rawInstructions = map['cach_lam'] as String? ?? '';
    final rawServings = (map['khau_phan'] as num?)?.toDouble();
    final rawCookingTime = (map['thoi_gian_nau'] as num?)?.toInt();

    if (rawAuthorId == null || rawName == null || rawServings == null) {
      throw FormatException('Missing required fields in Recipe map for id=$id');
    }

    return Recipe(
      id: id,
      authorId: rawAuthorId,
      name: rawName,
      description: map['mo_ta'] as String?,
      instructions: rawInstructions,
      imageUrl: map['hinh_anh'] as String?,
      baseServings: rawServings,
      cookingMinutes: rawCookingTime ?? 0,
      source: RecipeSource.fromValue(map['nguon'] as String? ?? 'USER'),
      visibility: RecipeVisibility.fromValue(map['pham_vi_hien_thi'] as String? ?? 'PRIVATE'),
      createdAt: _parseNullableDateTime(map['ngay_tao']),
      updatedAt: _parseNullableDateTime(map['ngay_cap_nhat']),
    );
  }

  static DateTime? _parseNullableDateTime(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }

  Recipe copyWith({
    String? id,
    String? authorId,
    String? name,
    String? description,
    String? instructions,
    String? imageUrl,
    double? baseServings,
    int? cookingMinutes,
    RecipeSource? source,
    RecipeVisibility? visibility,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Recipe(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      name: name ?? this.name,
      description: description ?? this.description,
      instructions: instructions ?? this.instructions,
      imageUrl: imageUrl ?? this.imageUrl,
      baseServings: baseServings ?? this.baseServings,
      cookingMinutes: cookingMinutes ?? this.cookingMinutes,
      source: source ?? this.source,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Recipe &&
        other.id == id &&
        other.authorId == authorId &&
        other.name == name &&
        other.description == description &&
        other.instructions == instructions &&
        other.imageUrl == imageUrl &&
        other.baseServings == baseServings &&
        other.cookingMinutes == cookingMinutes &&
        other.source == source &&
        other.visibility == visibility;
  }

  @override
  int get hashCode => Object.hash(
        id,
        authorId,
        name,
        description,
        instructions,
        imageUrl,
        baseServings,
        cookingMinutes,
        source,
        visibility,
      );

  @override
  String toString() {
    return 'Recipe(id: $id, name: $name, authorId: $authorId, baseServings: $baseServings, cookingMinutes: $cookingMinutes)';
  }
}
