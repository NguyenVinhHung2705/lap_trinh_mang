import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/food_item.dart';
import '../../data/models/food_batch.dart';
import '../providers/pantry_providers.dart';
import '../../shared/pantry_colors.dart';
import '../widgets/batch_item_tile.dart';
import 'add_batch_screen.dart';

class FoodDetailScreen extends ConsumerWidget {
  const FoodDetailScreen({
    super.key,
    required this.food,
  });

  final FoodItem food;

  void _refreshAll(WidgetRef ref) {
    ref.invalidate(pantryFoodsStreamProvider);
    ref.invalidate(expiringBatchesStreamProvider);
    ref.invalidate(stockMovementsStreamProvider);
  }

  void _openAddAnotherBatch(BuildContext context, FoodItem currentFood) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddBatchScreen(
          initialFoodName: currentFood.name,
          initialCategory: currentFood.categoryName,
          initialUnit: currentFood.baseUnit,
          initialBarcode: currentFood.barcode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(pantryRepositoryProvider);
    final userId = ref.watch(currentUserIdProvider);
    final latestFoods = ref.watch(pantryFoodsStreamProvider).value ?? [];
    final currentFood = latestFoods.cast<FoodItem?>().firstWhere(
          (f) => f?.id == food.id,
          orElse: () => food,
        )!;

    Color statusColor;
    Color statusTint;
    String statusLabel;
    switch (currentFood.expiryStatus) {
      case ExpiryStatus.expired:
        statusColor = AppColors.statusDanger;
        statusTint = AppColors.statusDangerTint;
        statusLabel = 'Có lô đã hết hạn';
        break;
      case ExpiryStatus.warning:
        statusColor = AppColors.statusWarning;
        statusTint = AppColors.statusWarningTint;
        statusLabel = 'Sắp hết hạn';
        break;
      case ExpiryStatus.good:
        statusColor = AppColors.statusSuccess;
        statusTint = AppColors.statusSuccessTint;
        statusLabel = 'Còn hạn tốt';
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          currentFood.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: StreamBuilder<List<FoodBatch>>(
        stream: repo.watchBatchesForFood(userId, currentFood.id),
        builder: (context, snapshot) {
          final batches = snapshot.data ?? [];
          final displayStock = snapshot.hasData
              ? batches.fold<double>(0.0, (sum, b) => sum + b.quantity)
              : currentFood.totalStock;
          final minTarget =
              currentFood.minimumStock > 0 ? currentFood.minimumStock : 1.0;
          final stockRatio = (displayStock / (minTarget * 2)).clamp(0.0, 1.0);
          final isLowStock = displayStock <= currentFood.minimumStock;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HERO SUMMARY CARD (Chuyển sắc xanh ngọc dịu + Thanh mức tồn kho)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFEAF7F0),
                        Color(0xFFFFFFFF),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.22),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.18),
                              ),
                            ),
                            child: Icon(
                              AppColors.categoryIcon(currentFood.categoryName),
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: Text(
                                        currentFood.categoryName,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusTint,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    const Text(
                                      'Tổng tồn: ',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      '$displayStock ${currentFood.baseUnit}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Thanh hiển thị mức tồn so với ngưỡng cảnh báo
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: stockRatio,
                          minHeight: 7,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isLowStock
                                ? AppColors.statusWarning
                                : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 2 ô thông số phụ cân đối bên dưới
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _showEditThresholdDialog(
                                context,
                                ref,
                                userId,
                                currentFood,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Ngưỡng báo sắp hết',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${currentFood.minimumStock} ${currentFood.baseUnit}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: isLowStock
                                                  ? AppColors.statusWarning
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Số đợt mua lưu kho',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${batches.length} lô riêng biệt',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 2. TIÊU ĐỀ DANH SÁCH CÁC LÔ
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Danh sách các lô hiện có',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tự động xếp lô có hạn dùng gần nhất lên trên',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${batches.length} lô',
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (batches.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: Text(
                        'Hiện không còn lô nào trong kho',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  ...batches.map(
                    (batch) => BatchItemTile(
                      batch: batch,
                      onMoveLocation: () => _showMoveLocationDialog(
                        context,
                        ref,
                        userId,
                        batch,
                      ),
                      onAdjustQuantity: () => _showAdjustQuantityDialog(
                        context,
                        ref,
                        userId,
                        batch,
                      ),
                      onDiscard: () => _showDiscardConfirmDialog(
                        context,
                        ref,
                        userId,
                        batch,
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // 3. THẺ NHẬP THÊM ĐỢT MUA MỚI (Giải thích rõ chỗ nối tiếp lô mới + thao tác 1 chạm)
                InkWell(
                  onTap: () => _openAddAnotherBatch(context, currentFood),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.30),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.add_box_outlined,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nhập thêm lô "${currentFood.name}" mới',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Đợt mua mới khác hạn dùng sẽ hiển thị thành lô riêng ngay tại đây',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showMoveLocationDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
    FoodBatch batch,
  ) async {
    final repo = ref.read(pantryRepositoryProvider);
    final locations = await repo.getStorageLocations(userId);
    if (!context.mounted) return;

    final locNames = <String>{
      batch.locationName,
      ...locations
          .map((l) => (l['ten_vi_tri'] as String? ?? '').trim())
          .where((s) => s.isNotEmpty),
    }.toList();

    String selected = batch.locationName;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Chuyển vị trí lưu trữ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lô: ${batch.quantity} ${batch.unit} ${batch.foodName}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: selected,
                decoration: InputDecoration(
                  labelText: 'Chọn vị trí lưu trữ mới',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: locNames
                    .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selected = val);
                },
              ),
              const SizedBox(height: 10),
              const Text(
                'Số lượng và hạn sử dụng của lô sẽ được giữ nguyên.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
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
                if (selected == batch.locationName) {
                  Navigator.pop(ctx);
                  return;
                }
                await repo.moveBatchLocation(
                  userId: userId,
                  batchId: batch.id,
                  newLocationName: selected,
                );
                _refreshAll(ref);
                ref.invalidate(storageLocationsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.primary,
                      content: Text('Đã chuyển lô sang "$selected"'),
                    ),
                  );
                }
              },
              child: const Text('Chuyển vị trí'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdjustQuantityDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
    FoodBatch batch,
  ) {
    final qtyController = TextEditingController(
      text: batch.quantity.toString(),
    );
    final reasonController = TextEditingController(text: 'Kiểm kê thực tế kho');
    String? errorMessage;

    const presetReasons = [
      'Kiểm kê thực tế kho',
      'Hao hụt sơ chế',
      'Cân đo lại định lượng',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final parsed = double.tryParse(qtyController.text.trim());
          final delta = parsed != null ? (parsed - batch.quantity) : 0.0;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Điều chỉnh số lượng lô',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tồn hiện tại của lô: ${batch.quantity} ${batch.unit}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setDialogState(() => errorMessage = null),
                    decoration: InputDecoration(
                      labelText: 'Số lượng thực tế còn lại (>= 0) *',
                      suffixText: batch.unit,
                      errorText: errorMessage,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (parsed != null && parsed >= 0 && delta.abs() >= 1e-9) ...[
                    const SizedBox(height: 8),
                    Text(
                      delta > 0
                          ? 'Chênh lệch: Tăng +${delta.toStringAsFixed(delta.truncateToDouble() == delta ? 0 : 2)} ${batch.unit}'
                          : 'Chênh lệch: Giảm ${delta.toStringAsFixed(delta.truncateToDouble() == delta ? 0 : 2)} ${batch.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: delta > 0
                            ? AppColors.statusSuccess
                            : AppColors.statusWarning,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      labelText: 'Lý do điều chỉnh *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: presetReasons
                        .map(
                          (r) => ActionChip(
                            label: Text(
                              r,
                              style: const TextStyle(fontSize: 11),
                            ),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: AppColors.background,
                            onPressed: () {
                              reasonController.text = r;
                              setDialogState(() {});
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
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
                  final newQty = double.tryParse(qtyController.text.trim());
                  if (newQty == null || newQty < 0) {
                    setDialogState(
                      () => errorMessage = 'Số lượng tồn không được âm!',
                    );
                    return;
                  }
                  if ((newQty - batch.quantity).abs() < 1e-9) {
                    setDialogState(
                      () => errorMessage =
                          'Số lượng mới trùng với số lượng hiện tại!',
                    );
                    return;
                  }
                  if (reasonController.text.trim().isEmpty) {
                    setDialogState(
                      () => errorMessage = 'Vui lòng nhập lý do điều chỉnh!',
                    );
                    return;
                  }

                  try {
                    await ref
                        .read(pantryRepositoryProvider)
                        .adjustBatchQuantity(
                          userId: userId,
                          batchId: batch.id,
                          newQuantity: newQty,
                          reason: reasonController.text.trim(),
                        );
                    _refreshAll(ref);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.primary,
                          content: Text(
                            'Đã ghi nhận điều chỉnh tồn lô thành $newQty ${batch.unit}',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    setDialogState(
                      () => errorMessage = e
                          .toString()
                          .replaceFirst('Bad state: ', '')
                          .replaceFirst('Invalid argument(s): ', ''),
                    );
                  }
                },
                child: const Text('Xác nhận'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDiscardConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
    FoodBatch batch,
  ) {
    final isBatchExpired = batch.daysRemaining < 0;
    final reasonController = TextEditingController(
      text: isBatchExpired
          ? 'Tiêu hủy thực phẩm đã quá hạn sử dụng'
          : 'Thực phẩm hư hỏng / loại bỏ khỏi kho',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isBatchExpired ? 'Tiêu hủy lô quá hạn?' : 'Loại bỏ lô thực phẩm?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lô ${batch.quantity} ${batch.unit} tại "${batch.locationName}" sẽ được loại bỏ khỏi kho và lưu lại vào lịch sử biến động.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Ghi chú lý do',
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
              backgroundColor: AppColors.statusDanger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              await ref.read(pantryRepositoryProvider).discardBatch(
                    userId: userId,
                    batchId: batch.id,
                    reason: reasonController.text.trim(),
                    isExpired: isBatchExpired,
                  );
              _refreshAll(ref);
              ref.invalidate(storageLocationsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Đã loại bỏ lô ${batch.quantity} ${batch.unit}',
                    ),
                  ),
                );
              }
            },
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );
  }

  void _showEditThresholdDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
    FoodItem currentFood,
  ) {
    final controller = TextEditingController(
      text: currentFood.minimumStock.toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cấu hình tồn tối thiểu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nhập ngưỡng tồn kho tối thiểu cho "${currentFood.name}":',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixText: currentFood.baseUnit,
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
              final val = double.tryParse(controller.text.trim());
              if (val != null && val >= 0) {
                await ref
                    .read(pantryRepositoryProvider)
                    .updateFoodMinimumStock(userId, currentFood.id, val);
                ref.invalidate(pantryFoodsStreamProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Đã cập nhật ngưỡng tồn kho: $val ${currentFood.baseUnit}',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
