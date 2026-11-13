import 'package:flutter/foundation.dart';

/// Loại biến động kho theo quy chuẩn schema.sql
enum StockMovementType {
  inStock('IN', 'Nhập kho'),
  consume('CONSUME', 'Nấu ăn / Tiêu hao'),
  discard('DISCARD', 'Hỏng / Hủy bỏ'),
  adjust('ADJUST', 'Điều chỉnh');

  const StockMovementType(this.code, this.labelVi);
  final String code;
  final String labelVi;
}

/// Mô hình Biến động kho (bien_dong_kho)
@immutable
class StockMovement {
  const StockMovement({
    required this.id,
    required this.batchId,
    required this.foodName,
    required this.type,
    required this.inQuantity,
    required this.outQuantity,
    required this.timestamp,
    this.note,
  });

  final String id;
  final String batchId;
  final String foodName;
  final StockMovementType type;
  final double inQuantity;
  final double outQuantity;
  final DateTime timestamp;
  final String? note;

  Map<String, dynamic> toMap() {
    return {
      'ma_lo': batchId,
      'ten_thuc_pham': foodName,
      'loai_bien_dong': type.code,
      'so_luong_nhap': inQuantity,
      'so_luong_xuat': outQuantity,
      'thoi_diem': timestamp.toIso8601String(),
      'ghi_chu': note,
    };
  }

  factory StockMovement.fromMap(String id, Map<String, dynamic> map) {
    final typeCode = map['loai_bien_dong'] as String? ?? 'IN';
    final type = StockMovementType.values.firstWhere(
      (e) => e.code == typeCode,
      orElse: () => StockMovementType.inStock,
    );

    return StockMovement(
      id: id,
      batchId: map['ma_lo'] as String? ?? '',
      foodName: map['ten_thuc_pham'] as String? ?? '',
      type: type,
      inQuantity: (map['so_luong_nhap'] as num?)?.toDouble() ?? 0.0,
      outQuantity: (map['so_luong_xuat'] as num?)?.toDouble() ?? 0.0,
      timestamp: map['thoi_diem'] != null
          ? DateTime.tryParse(map['thoi_diem'] as String) ?? DateTime.now()
          : DateTime.now(),
      note: map['ghi_chu'] as String?,
    );
  }
}
