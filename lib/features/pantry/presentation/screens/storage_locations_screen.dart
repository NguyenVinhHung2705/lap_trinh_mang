import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../shared/pantry_colors.dart';
import '../providers/pantry_providers.dart';

/// Màn hình Quản lý Vị trí Lưu trữ (`vi_tri_luu_tru`, MOD-01-04 - Nguyễn Văn Định)
/// Đáp ứng FR-04: Thêm, sửa, xóa vị trí cá nhân; chặn xóa nếu vị trí còn chứa lô thực phẩm.
class StorageLocationsScreen extends ConsumerStatefulWidget {
  const StorageLocationsScreen({super.key});

  @override
  ConsumerState<StorageLocationsScreen> createState() =>
      _StorageLocationsScreenState();
}

class _StorageLocationsScreenState
    extends ConsumerState<StorageLocationsScreen> {
  void _showLocationFormDialog({
    required String userId,
    Map<String, dynamic>? existing,
  }) {
    final isEdit = existing != null;
    final oldName = existing?['ten_vi_tri'] as String? ?? '';
    final nameController = TextEditingController(text: oldName);
    final descController = TextEditingController(
      text: existing?['mo_ta'] as String? ?? '',
    );
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            isEdit ? 'Chỉnh sửa vị trí lưu trữ' : 'Thêm vị trí lưu trữ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Tên vị trí * (VD: Ngăn rau, Kệ phụ...)',
                  errorText: errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: 'Mô tả / Nhiệt độ bảo quản',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  setDialogState(
                    () => errorText = 'Tên vị trí không được để trống',
                  );
                  return;
                }
                try {
                  final repo = ref.read(pantryRepositoryProvider);
                  if (isEdit) {
                    await repo.updateStorageLocation(
                      userId: userId,
                      locationId: existing['id'].toString(),
                      oldName: oldName,
                      newName: name,
                      description: descController.text.trim(),
                    );
                  } else {
                    await repo.addStorageLocation(
                      userId,
                      name,
                      descController.text.trim(),
                    );
                  }
                  ref.invalidate(storageLocationsProvider);
                  ref.invalidate(expiringBatchesStreamProvider);
                  ref.invalidate(pantryFoodsStreamProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.primary,
                        content: Text(
                          isEdit
                              ? 'Đã cập nhật vị trí "$name"'
                              : 'Đã thêm vị trí lưu trữ "$name"',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  setDialogState(
                    () => errorText = e
                        .toString()
                        .replaceFirst('Bad state: ', '')
                        .replaceFirst('Invalid argument(s): ', ''),
                  );
                }
              },
              child: Text(isEdit ? 'Cập nhật' : 'Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteLocation({
    required String userId,
    required String locationId,
    required String locationName,
    required int activeBatchCount,
  }) async {
    if (activeBatchCount > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.statusWarning),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Không thể xóa vị trí',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'Vị trí "$locationName" đang có $activeBatchCount lô thực phẩm.\n\n'
            'Vui lòng chuyển các lô thực phẩm này sang vị trí khác trước khi xóa vị trí.',
            style: const TextStyle(height: 1.45),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Xóa vị trí lưu trữ?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('Bạn có chắc muốn xóa vị trí "$locationName" khỏi kho?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusDanger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(pantryRepositoryProvider).deleteStorageLocation(
            userId: userId,
            locationId: locationId,
            locationName: locationName,
          );
      ref.invalidate(storageLocationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa vị trí "$locationName"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.statusDanger,
            content: Text(e.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final locationsAsync = ref.watch(storageLocationsProvider);
    final activeBatches = ref.watch(expiringBatchesStreamProvider).value ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Vị trí lưu trữ trong kho',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text(
          'Thêm vị trí',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showLocationFormDialog(userId: userId),
      ),
      body: locationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Text(
            'Không tải được danh sách vị trí: $err',
            style: const TextStyle(color: AppColors.statusDanger),
          ),
        ),
        data: (locations) {
          if (locations.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có vị trí lưu trữ nào.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: locations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final loc = locations[index];
              final id = loc['id']?.toString() ?? '';
              final name = loc['ten_vi_tri'] as String? ?? 'Vị trí';
              final desc = loc['mo_ta'] as String? ?? '';

              final batchCount = activeBatches
                  .where(
                    (b) =>
                        b.quantity > 0 &&
                        b.locationName.trim().toLowerCase() ==
                            name.trim().toLowerCase(),
                  )
                  .length;

              IconData icon = Icons.kitchen;
              if (name.toLowerCase().contains('đông') ||
                  name.toLowerCase().contains('đá')) {
                icon = Icons.ac_unit;
              } else if (name.toLowerCase().contains('rau') ||
                  name.toLowerCase().contains('quả')) {
                icon = Icons.eco;
              } else if (name.toLowerCase().contains('gia vị') ||
                  name.toLowerCase().contains('khô') ||
                  name.toLowerCase().contains('kệ')) {
                icon = Icons.shelves;
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: batchCount > 0
                                      ? AppColors.primaryTint
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  batchCount > 0 ? '$batchCount lô' : 'Trống',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: batchCount > 0
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              desc,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      tooltip: 'Đổi tên / sửa mô tả',
                      onPressed: () => _showLocationFormDialog(
                        userId: userId,
                        existing: loc,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: batchCount > 0
                            ? AppColors.textMuted
                            : AppColors.statusDanger,
                        size: 20,
                      ),
                      tooltip: 'Xóa vị trí',
                      onPressed: () => _confirmDeleteLocation(
                        userId: userId,
                        locationId: id,
                        locationName: name,
                        activeBatchCount: batchCount,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
