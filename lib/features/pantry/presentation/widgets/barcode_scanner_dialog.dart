import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/pantry_repository.dart';
import '../../shared/pantry_colors.dart';
import '../providers/pantry_providers.dart';

/// Hộp thoại quét mã vạch / QR (MOD-01-02 / FR-02)
/// Ràng buộc nghiệp vụ: Kiểm tra định dạng mã, tra danh mục thực phẩm,
/// chỉ điền gợi ý vào biểu mẫu (không tự sinh HSD, không tự lưu lô kho).
class BarcodeScannerDialog extends ConsumerStatefulWidget {
  const BarcodeScannerDialog({
    super.key,
    required this.onScanned,
    this.onProductResolved,
  });

  final void Function(String barcode, String detectedFoodName) onScanned;
  final void Function(Map<String, String> product, bool isKnown)?
      onProductResolved;

  static Future<void> show(
    BuildContext context, {
    required void Function(String barcode, String detectedFoodName) onScanned,
    void Function(Map<String, String> product, bool isKnown)? onProductResolved,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => BarcodeScannerDialog(
        onScanned: onScanned,
        onProductResolved: onProductResolved,
      ),
    );
  }

  @override
  ConsumerState<BarcodeScannerDialog> createState() =>
      _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends ConsumerState<BarcodeScannerDialog>
    with SingleTickerProviderStateMixin {
  final _manualController = TextEditingController();
  late AnimationController _animController;
  String? _errorText;
  bool _isLookingUp = false;

  static final RegExp _validCodeRegex = RegExp(r'^[A-Za-z0-9\-_]{4,32}$');

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

  Future<void> _handleCodeLookup(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty) {
      setState(() => _errorText = 'Vui lòng nhập mã vạch hoặc chuỗi QR');
      return;
    }
    if (!_validCodeRegex.hasMatch(code)) {
      setState(
        () => _errorText = 'Định dạng mã không hợp lệ (4–32 ký tự chữ/số)',
      );
      return;
    }

    setState(() {
      _errorText = null;
      _isLookingUp = true;
    });

    try {
      final repo = ref.read(pantryRepositoryProvider);
      final userId = ref.read(pantryUserIdProvider);
      final found = await repo.lookupFoodByBarcode(userId, code);

      if (!mounted) return;
      if (found != null) {
        widget.onScanned(code, found['name']!);
        widget.onProductResolved?.call(found, true);
      } else {
        widget.onScanned(code, '');
        widget.onProductResolved?.call({'code': code, 'name': ''}, false);
      }
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isLookingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quét mã vạch / QR',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Khung ngắm camera mô phỏng
            Container(
              height: 165,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    size: 76,
                    color: Colors.white24,
                  ),
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return Positioned(
                        top: 18 + (_animController.value * 125),
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
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Đưa mã EAN-13 / QR vào khung hoặc nhập bên dưới',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Nhập mã thủ công
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualController,
                    onChanged: (_) {
                      if (_errorText != null) {
                        setState(() => _errorText = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Nhập mã EAN-13 hoặc QR...',
                      errorText: _errorText,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLookingUp
                        ? null
                        : () => _handleCodeLookup(_manualController.text),
                    child: _isLookingUp
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Tra mã'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              'Chạm nhanh mã sản phẩm mẫu (EAN-13):',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PantryRepository.sampleBarcodeCatalog.map((item) {
                final code = item['code']!;
                final name = item['name']!;
                return ActionChip(
                  avatar: const Icon(
                    Icons.qr_code,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  label: Text('$name (${code.substring(code.length - 4)})'),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                  backgroundColor: AppColors.primaryTint,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.transparent),
                  ),
                  onPressed: () {
                    widget.onScanned(code, name);
                    widget.onProductResolved?.call(
                      Map<String, String>.from(item),
                      true,
                    );
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
