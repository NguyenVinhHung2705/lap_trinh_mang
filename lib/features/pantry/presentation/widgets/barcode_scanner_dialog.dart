import 'package:flutter/material.dart';
import '../../shared/pantry_colors.dart';

/// Hộp thoại quét mã vạch (Barcode Scanner) cho Kho & Mua sắm (MOD-01 / MOD-02)
/// Tích hợp giao diện camera scanner mô phỏng & nhập trực tiếp mã vạch EAN-13.
class BarcodeScannerDialog extends StatefulWidget {
  const BarcodeScannerDialog({
    super.key,
    required this.onScanned,
  });

  final void Function(String barcode, String detectedFoodName) onScanned;

  static Future<void> show(
    BuildContext context, {
    required void Function(String barcode, String detectedFoodName) onScanned,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => BarcodeScannerDialog(onScanned: onScanned),
    );
  }

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> with SingleTickerProviderStateMixin {
  final _manualController = TextEditingController();
  late AnimationController _animController;

  static const List<Map<String, String>> _sampleBarcodes = [
    {'code': '8934567890123', 'name': 'Sữa tươi thanh trùng'},
    {'code': '8935001234567', 'name': 'Thịt bò thăn Úc'},
    {'code': '8936009876543', 'name': 'Rau cải xanh Đà Lạt'},
    {'code': '8937001122334', 'name': 'Trứng gà ta'},
    {'code': '8938005544332', 'name': 'Sữa chua không đường'},
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _manualController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _triggerScan(String code, String name) {
    widget.onScanned(code, name);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quét mã vạch thực phẩm',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Camera Viewfinder Box
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner, size: 80, color: Colors.white24),
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return Positioned(
                        top: 20 + (_animController.value * 140),
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.8),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Căn chỉnh mã vạch vào khung quét',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Nhập thủ công
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Nhập mã EAN-13 thủ công...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final code = _manualController.text.trim();
                    if (code.isNotEmpty) {
                      final match = _sampleBarcodes.firstWhere(
                        (b) => b['code'] == code,
                        orElse: () => {'code': code, 'name': 'Thực phẩm mới ($code)'},
                      );
                      _triggerScan(code, match['name']!);
                    }
                  },
                  child: const Text('Tìm'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              'Mã vạch mẫu có sẵn trong kho:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),

            // Danh sách mã vạch mẫu
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sampleBarcodes.map((item) {
                return ActionChip(
                  avatar: const Icon(Icons.qr_code, size: 16, color: AppColors.primary),
                  label: Text('${item['name']} (${item['code']!.substring(item['code']!.length - 4)})'),
                  labelStyle: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  backgroundColor: AppColors.primaryTint,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.transparent),
                  ),
                  onPressed: () => _triggerScan(item['code']!, item['name']!),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
