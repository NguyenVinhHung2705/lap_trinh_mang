import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/adapters/pantry_adapter.dart';
import '../../data/models/shopping_item.dart';
import '../../domain/shopping_sync_service.dart';
import '../providers/shopping_providers.dart';
import '../widgets/sync_item_editor_card.dart';

/// Screen for reviewing, completing, and synchronizing bought items into pantry stock (MOD-02-07 & MOD-02-08 / FR-15, FR-16).
class ShoppingSyncScreen extends ConsumerStatefulWidget {
  const ShoppingSyncScreen({
    super.key,
    required this.userId,
    required this.listId,
  });

  final String userId;
  final String listId;

  @override
  ConsumerState<ShoppingSyncScreen> createState() => _ShoppingSyncScreenState();
}

class _ShoppingSyncScreenState extends ConsumerState<ShoppingSyncScreen> {
  ShoppingSyncPreview? _preview;
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final syncService = ref.read(shoppingSyncServiceProvider);
      final preview = await syncService.previewSync(
        userId: widget.userId,
        listId: widget.listId,
      );

      if (mounted) {
        setState(() {
          _preview = preview;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(storageLocationsProvider(widget.userId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Hoàn tất & Nhập kho',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _buildBody(locationsAsync),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody(AsyncValue<List<StorageLocationInfo>> locationsAsync) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Lỗi: $_error',
                  style: const TextStyle(color: AppColors.statusDanger)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadPreview,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final preview = _preview;
    if (preview == null) return const SizedBox.shrink();

    final allBoughtCandidates = [
      ...preview.readyItems,
      ...preview.incompleteItems,
    ];

    return locationsAsync.when(
      data: (locations) {
        if (allBoughtCandidates.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline,
                      size: 56, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có mục nào được đánh dấu đã mua',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vui lòng vào chế độ đi mua để đánh dấu các thực phẩm đã mua trước khi đồng bộ kho.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text('Quay lại',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status Banner Card
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: preview.hasIncompleteItems
                    ? AppColors.statusWarningTint
                    : AppColors.statusSuccessTint,
                borderRadius: BorderRadius.circular(AppColors.radiusCard),
                border: Border.all(
                  color: preview.hasIncompleteItems
                      ? AppColors.statusWarning
                      : AppColors.statusSuccess,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        preview.hasIncompleteItems
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle,
                        color: preview.hasIncompleteItems
                            ? AppColors.statusWarning
                            : AppColors.statusSuccess,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        preview.hasIncompleteItems
                            ? 'Cần bổ sung thông tin nhập kho'
                            : 'Đủ điều kiện nhập kho nguyên tử',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: preview.hasIncompleteItems
                              ? AppColors.statusWarning
                              : AppColors.statusSuccess,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    preview.hasIncompleteItems
                        ? 'Có ${preview.incompleteItems.length} mục chưa có HSD hoặc vị trí lưu trữ. Chỉ những mục đủ thông tin mới được nhập kho.'
                        : 'Toàn bộ ${preview.readyItems.length} mục đã có đủ số lượng thực tế, HSD và vị trí lưu trữ.',
                    style: TextStyle(
                      fontSize: 13,
                      color: preview.hasIncompleteItems
                          ? AppColors.textPrimary
                          : AppColors.primaryDark,
                    ),
                  ),
                  if (preview.unboughtItems.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Lưu ý: ${preview.unboughtItems.length} mục chưa mua sẽ được giữ nguyên trong danh sách (không làm mất nhu cầu).',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Text(
              'Danh sách thực phẩm đã mua:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // Item cards
            ...allBoughtCandidates.map((item) {
              return SyncItemEditorCard(
                item: item,
                locations: locations,
                onExpiryDateChanged: (exp) async {
                  await ref
                      .read(shoppingRepositoryProvider)
                      .updateItemActualDetails(
                        userId: widget.userId,
                        listId: widget.listId,
                        itemId: item.id,
                        actualQuantity: item.actualQuantity > 0
                            ? item.actualQuantity
                            : item.plannedQuantity,
                        expiryDate: exp,
                        locationId: item.locationId,
                        locationName: item.locationName,
                      );
                  await _loadPreview();
                },
                onLocationChanged: (loc) async {
                  await ref
                      .read(shoppingRepositoryProvider)
                      .updateItemActualDetails(
                        userId: widget.userId,
                        listId: widget.listId,
                        itemId: item.id,
                        actualQuantity: item.actualQuantity > 0
                            ? item.actualQuantity
                            : item.plannedQuantity,
                        expiryDate: item.expiryDate,
                        locationId: loc.id,
                        locationName: loc.name,
                      );
                  await _loadPreview();
                },
                onActualQuantityChanged: (qty) async {
                  await ref
                      .read(shoppingRepositoryProvider)
                      .updateItemActualDetails(
                        userId: widget.userId,
                        listId: widget.listId,
                        itemId: item.id,
                        actualQuantity: qty,
                        expiryDate: item.expiryDate,
                        locationId: item.locationId,
                        locationName: item.locationName,
                      );
                  await _loadPreview();
                },
              );
            }),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(child: Text('Lỗi tải vị trí: $e')),
    );
  }

  Widget _buildBottomBar() {
    final preview = _preview;
    final readyCount = preview?.readyItems.length ?? 0;
    final canSync = readyCount > 0 && !_isSyncing;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: ElevatedButton.icon(
        onPressed: canSync ? _showConfirmSyncDialog : null,
        icon: _isSyncing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.cloud_upload_outlined, color: Colors.white),
        label: Text(
          _isSyncing ? 'Đang nhập kho...' : 'Xác nhận Nhập kho ($readyCount mục)',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.border,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusInput),
          ),
        ),
      ),
    );
  }

  void _showConfirmSyncDialog() {
    final preview = _preview;
    if (preview == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusModal),
        ),
        title: const Text(
          'Xác nhận Đồng bộ Kho',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hệ thống sẽ thực hiện giao dịch nguyên tử (Firestore Transaction):',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Text('• Tạo ${preview.readyItems.length} lô thực phẩm mới (lo_thuc_pham).'),
            Text('• Ghi ${preview.readyItems.length} biến động nhập kho IN (bien_dong_kho).'),
            Text('• Đánh dấu đã đồng bộ (da_dong_bo_kho = true).'),
            if (preview.unboughtItems.isNotEmpty)
              Text(
                '• Giữ lại ${preview.unboughtItems.length} mục chưa mua trong danh sách.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _executeSync();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Đồng ý', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeSync() async {
    setState(() => _isSyncing = true);

    try {
      final syncService = ref.read(shoppingSyncServiceProvider);
      final result = await syncService.completeAndSyncAtomic(
        userId: widget.userId,
        listId: widget.listId,
      );

      if (mounted) {
        setState(() => _isSyncing = false);
        _showSuccessDialog(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đồng bộ: $e'),
            backgroundColor: AppColors.statusDanger,
          ),
        );
      }
    }
  }

  void _showSuccessDialog(ShoppingSyncResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusModal),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.statusSuccess, size: 28),
            SizedBox(width: 8),
            Text('Nhập kho Thành công!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.message ??
                  'Đã nhập thành công ${result.syncedCount} mục vào kho thực phẩm.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (result.retainedCount > 0)
              Text(
                'Giữ lại ${result.retainedCount} mục chưa mua trong danh sách để tiếp tục theo dõi.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            if (result.isListCompleted)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Danh sách mua sắm đã hoàn tất.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // Back to detail
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Xong', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

