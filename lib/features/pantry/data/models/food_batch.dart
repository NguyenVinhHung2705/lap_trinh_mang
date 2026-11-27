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
  final double quantity; // Số lượng còn trong lô này
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
      'thuc_pham_id': foodId,
      'ma_thuc_pham': foodId,
      'ten_thuc_pham': foodName,
      'vi_tri': locationName,
      'ten_vi_tri': locationName,
      'created_at': importDate.toUtc().toIso8601String(),
      'ngay_nhap': importDate.toIso8601String(),
      'ngay_het_han': expiryDate.toIso8601String().substring(0, 10),
      'han_su_dung': expiryDate.toIso8601String(),
      'so_luong': quantity,
      'don_vi': unit,
    };
  }

  factory FoodBatch.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseLocalDate(Object? raw, DateTime fallback) {
      if (raw is DateTime) return raw.toLocal();
      if (raw is String && raw.trim().isNotEmpty) {
        return DateTime.tryParse(raw.trim())?.toLocal() ?? fallback;
      }
      return fallback;
    }

    final rawLoc =
        (map['vi_tri'] ?? map['ten_vi_tri'])?.toString().trim() ?? '';
    final rawUnit = map['don_vi']?.toString().trim() ?? '';

    return FoodBatch(
      id: id,
      foodId: (map['thuc_pham_id'] ?? map['ma_thuc_pham'])?.toString() ?? '',
      foodName: map['ten_thuc_pham']?.toString() ?? '',
      locationName: rawLoc.isNotEmpty ? rawLoc : 'Ngăn mát',
      importDate: parseLocalDate(
        map['ngay_nhap'] ?? map['created_at'],
        DateTime.now(),
      ),
      expiryDate: parseLocalDate(
        map['ngay_het_han'] ?? map['han_su_dung'],
        DateTime.now(),
      ),
      quantity: (map['so_luong'] as num?)?.toDouble() ??
          (map['so_luong_ton'] as num?)?.toDouble() ??
          0.0,
      unit: rawUnit.isNotEmpty ? rawUnit : 'phần',
    );
  }
}
