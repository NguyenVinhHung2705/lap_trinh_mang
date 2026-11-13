import 'package:flutter/foundation.dart';
import 'food_item.dart';

/// Mô hình Lô thực phẩm (lo_thuc_pham) trong kho
@immutable
class FoodBatch {
  const FoodBatch({
    required this.id,
    required this.foodId,
    required this.foodName,
    required this.locationName,
    required this.importDate,
    required this.expiryDate,
    required this.quantity,
    required this.unit,
  });

  final String id;
  final String foodId;
  final String foodName;
  final String locationName; // Ngăn mát, Ngăn đông, Tủ gia vị, Kệ bếp
  final DateTime importDate;
  final DateTime expiryDate;
  final double quantity;     // Số lượng còn trong lô này
  final String unit;

  /// Trạng thái HSD của riêng lô này
  ExpiryStatus get status {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final diff = exp.difference(today).inDays;

    if (diff < 0) return ExpiryStatus.expired;
    if (diff <= 3) return ExpiryStatus.warning;
    return ExpiryStatus.good;
  }

  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return exp.difference(today).inDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'ma_thuc_pham': foodId,
      'ten_thuc_pham': foodName,
      'ten_vi_tri': locationName,
      'ngay_nhap': importDate.toIso8601String(),
      'han_su_dung': expiryDate.toIso8601String(),
      'so_luong': quantity,
      'don_vi': unit,
    };
  }

  factory FoodBatch.fromMap(String id, Map<String, dynamic> map) {
    return FoodBatch(
      id: id,
      foodId: map['ma_thuc_pham'] as String? ?? '',
      foodName: map['ten_thuc_pham'] as String? ?? '',
      locationName: map['ten_vi_tri'] as String? ?? 'Ngăn mát',
      importDate: map['ngay_nhap'] != null
          ? DateTime.tryParse(map['ngay_nhap'] as String) ?? DateTime.now()
          : DateTime.now(),
      expiryDate: map['han_su_dung'] != null
          ? DateTime.tryParse(map['han_su_dung'] as String) ?? DateTime.now()
          : DateTime.now(),
      quantity: (map['so_luong'] as num?)?.toDouble() ?? 0.0,
      unit: map['don_vi'] as String? ?? 'phần',
    );
  }
}
