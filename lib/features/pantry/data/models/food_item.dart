import 'package:flutter/foundation.dart';

/// Trạng thái hạn sử dụng của một lô hoặc thực phẩm
enum ExpiryStatus {
  good('Còn hạn'),
  warning('Sắp hết hạn'),
  expired('Đã hết hạn');

  const ExpiryStatus(this.labelVi);
  final String labelVi;
}

/// Mô hình Thực phẩm (thuc_pham) trong kho
@immutable
class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.categoryName,
    required this.baseUnit,
    this.barcode,
    this.imageUrl,
    this.minimumStock = 1.0,
    this.totalStock = 0.0,
    this.closestExpiryDate,
  });

  final String id;
  final String name;
  final String categoryName; // Rau củ, Thịt cá, Gia vị, Đồ uống,...
  final String baseUnit;     // kg, g, quả, hộp, ml, lít,...
  final String? barcode;
  final String? imageUrl;
  final double minimumStock;
  final double totalStock;
  final DateTime? closestExpiryDate;

  /// Tính trạng thái hạn sử dụng dựa trên ngày hết hạn gần nhất
  ExpiryStatus get expiryStatus {
    if (closestExpiryDate == null) return ExpiryStatus.good;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(closestExpiryDate!.year, closestExpiryDate!.month, closestExpiryDate!.day);
    final difference = expiry.difference(today).inDays;

    if (difference < 0) return ExpiryStatus.expired;
    if (difference <= 3) return ExpiryStatus.warning;
    return ExpiryStatus.good;
  }

  /// Kiểm tra số lượng tồn có dưới ngưỡng cảnh báo không
  bool get isLowStock => totalStock <= minimumStock;

  FoodItem copyWith({
    String? id,
    String? name,
    String? categoryName,
    String? baseUnit,
    String? barcode,
    String? imageUrl,
    double? minimumStock,
    double? totalStock,
    DateTime? closestExpiryDate,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryName: categoryName ?? this.categoryName,
      baseUnit: baseUnit ?? this.baseUnit,
      barcode: barcode ?? this.barcode,
      imageUrl: imageUrl ?? this.imageUrl,
      minimumStock: minimumStock ?? this.minimumStock,
      totalStock: totalStock ?? this.totalStock,
      closestExpiryDate: closestExpiryDate ?? this.closestExpiryDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ten_thuc_pham': name,
      'ten_danh_muc': categoryName,
      'don_vi_co_so': baseUnit,
      'ma_vach': barcode,
      'hinh_anh': imageUrl,
      'nguong_sap_het': minimumStock,
      'so_luong_ton': totalStock,
      'han_su_dung_gan_nhat': closestExpiryDate?.toIso8601String(),
    };
  }

  factory FoodItem.fromMap(String id, Map<String, dynamic> map) {
    return FoodItem(
      id: id,
      name: map['ten_thuc_pham'] as String? ?? 'Chưa đặt tên',
      categoryName: map['ten_danh_muc'] as String? ?? 'Khác',
      baseUnit: map['don_vi_co_so'] as String? ?? 'phần',
      barcode: map['ma_vach'] as String?,
      imageUrl: map['hinh_anh'] as String?,
      minimumStock: (map['nguong_sap_het'] as num?)?.toDouble() ?? 1.0,
      totalStock: (map['so_luong_ton'] as num?)?.toDouble() ?? 0.0,
      closestExpiryDate: map['han_su_dung_gan_nhat'] != null
          ? DateTime.tryParse(map['han_su_dung_gan_nhat'] as String)
          : null,
    );
  }
}
