import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/adapters/pantry_adapter.dart';
import '../data/models/shopping_item.dart';
import '../data/models/shopping_list.dart';
import '../data/shopping_repository.dart';

/// Synchronization preview data for UI verification before committing.
class ShoppingSyncPreview {
  const ShoppingSyncPreview({
    required this.list,
    required this.readyItems,
    required this.incompleteItems,
    required this.unboughtItems,
    required this.alreadySyncedItems,
  });

  final ShoppingList list;
  final List<ShoppingItem> readyItems;
  final List<ShoppingItem> incompleteItems;
  final List<ShoppingItem> unboughtItems;
  final List<ShoppingItem> alreadySyncedItems;

  bool get hasItemsToSync => readyItems.isNotEmpty;
  bool get hasIncompleteItems => incompleteItems.isNotEmpty;
  int get totalEligible => readyItems.length;
}

/// Result summary returned after completing synchronization.
class ShoppingSyncResult {
  const ShoppingSyncResult({
    required this.listId,
    required this.syncedCount,
    required this.retainedCount,
    required this.isListCompleted,
    required this.syncedItems,
    this.message,
  });

  final String listId;
  final int syncedCount;
  final int retainedCount;
  final bool isListCompleted;
  final List<ShoppingItem> syncedItems;
  final String? message;
}

/// Domain service implementing pantry synchronization (`MOD-02-08` / FR-16).
///
/// Invariants:
/// 1. Only imports items with confirmed actual bought quantity (`so_luong_da_mua > 0`).
/// 2. Requires non-null expiry date and valid user-owned storage location.
/// 3. Creates `lo_thuc_pham` and ledger movement `bien_dong_kho`
///    (`loai_bien_dong = 'IN'`, `so_luong_nhap > 0`, `so_luong_xuat = 0`).
/// 4. Idempotency (TC-M02-08): Re-syncing an already-synced item never creates duplicate IN records.
/// 5. Preservation: Unbought items are retained without losing future demand.
class ShoppingSyncService {
  ShoppingSyncService({
    required ShoppingRepository shoppingRepository,
    PantryReader? pantryReader,
    PantrySyncWriter? pantrySyncWriter,
    SupabaseClient? supabase,
  })  : _repository = shoppingRepository,
        _pantryReader = pantryReader ?? SupabasePantryAdapter(),
        _pantrySyncWriter = pantrySyncWriter ?? SupabasePantryAdapter(),
        _customSupabase = supabase;

  final ShoppingRepository _repository;
  final PantryReader _pantryReader;
  final PantrySyncWriter _pantrySyncWriter;
  final SupabaseClient? _customSupabase;
  SupabaseClient get _supabase =>
      _customSupabase ?? Supabase.instance.client;

  /// Generates preview of items before executing sync (`MOD-02-07` / `MOD-02-08`).
  Future<ShoppingSyncPreview> previewSync({
    required String userId,
    required String listId,
  }) async {
    final list = await _repository.getShoppingList(
      userId: userId,
      listId: listId,
    );
    if (list == null) throw const ShoppingNotFoundException();

    final allItems = await _repository.getItems(
      userId: userId,
      listId: listId,
    );

    final readyItems = <ShoppingItem>[];
    final incompleteItems = <ShoppingItem>[];
    final unboughtItems = <ShoppingItem>[];
    final alreadySyncedItems = <ShoppingItem>[];

    for (final item in allItems) {
      if (item.isSynced) {
        alreadySyncedItems.add(item);
      } else if (!item.isBought) {
        unboughtItems.add(item);
      } else if (item.isReadyForSync) {
        readyItems.add(item);
      } else {
        incompleteItems.add(item);
      }
    }

    return ShoppingSyncPreview(
      list: list,
      readyItems: readyItems,
      incompleteItems: incompleteItems,
      unboughtItems: unboughtItems,
      alreadySyncedItems: alreadySyncedItems,
    );
  }

  /// Executes synchronization to pantry using sequential Supabase operations.
  Future<ShoppingSyncResult> completeAndSyncAtomic({
    required String userId,
    required String listId,
    bool completeListIfUnboughtRemain = false,
  }) async {
    if (userId.startsWith('mock_') || userId.startsWith('guest_')) {
      final currentList = await _repository.getShoppingList(
        userId: userId,
        listId: listId,
      );
      if (currentList == null) {
        throw const ShoppingNotFoundException('Danh sách mua sắm không tồn tại.');
      }
      final items = await _repository.getItems(
        userId: userId,
        listId: listId,
      );
      final candidates = items
          .where((it) => it.isBought && !it.isSynced && it.actualQuantity > 0)
          .toList();
      final now = DateTime.now();
      for (final item in candidates) {
        await _repository.updateItem(
          userId: userId,
          listId: listId,
          item: item.copyWith(isSynced: true),
        );
      }
      final unboughtCount =
          items.where((it) => !it.isBought && !it.isSynced).length;
      final totalSyncedNow =
          items.where((it) => it.isSynced).length + candidates.length;
      final shouldComplete =
          unboughtCount == 0 || completeListIfUnboughtRemain;

      await _repository.updateShoppingList(
        userId: userId,
        list: currentList.copyWith(
          status: shouldComplete
              ? ShoppingListStatus.completed
              : ShoppingListStatus.open,
          completedAt: shouldComplete ? now : currentList.completedAt,
          syncedItems: totalSyncedNow,
        ),
      );

      return ShoppingSyncResult(
        listId: listId,
        syncedCount: candidates.length,
        retainedCount: unboughtCount,
        isListCompleted: shouldComplete,
        syncedItems: candidates,
        message: 'Đã đồng bộ thành công ${candidates.length} mục vào kho.',
      );
    }

    // --- Real Supabase path: sequential read + writes ---

    // 1. Read list
    final listRow = await _supabase
        .from('danh_sach_mua')
        .select()
        .eq('id', listId)
        .eq('user_id', userId)
        .maybeSingle();

    if (listRow == null) {
      throw const ShoppingNotFoundException('Danh sách mua sắm không tồn tại.');
    }

    final currentList = ShoppingList.fromMap(
      _normalizeMap(listRow),
      id: listRow['id'] as String,
    );

    // 2. Fetch all items
    final itemRows = await _supabase
        .from('chi_tiet_mua')
        .select()
        .eq('danh_sach_id', listId)
        .eq('user_id', userId);

    final items = (itemRows as List)
        .map((row) => ShoppingItem.fromMap(
              _normalizeMap(row as Map<String, dynamic>),
              id: row['id'] as String,
            ))
        .toList();

    // 3. Filter candidates for sync
    final candidates = items
        .where((it) => it.isBought && !it.isSynced && it.actualQuantity > 0)
        .toList();

    // Idempotency check: If all bought items are already synced
    if (candidates.isEmpty) {
      final alreadySynced = items.where((it) => it.isSynced).toList();
      return ShoppingSyncResult(
        listId: listId,
        syncedCount: 0,
        retainedCount: items.where((it) => !it.isSynced).length,
        isListCompleted: currentList.isCompleted,
        syncedItems: alreadySynced,
        message: 'Tất cả các mục mua đã được đồng bộ trước đó (chống lặp).',
      );
    }

    // 4. Validate each candidate item
    final batchPayloads = <NewPantryBatchPayload>[];
    final verifiedItems = <ShoppingItem>[];
    final today = DateTime.now();

    for (final item in candidates) {
      if (item.actualQuantity <= 0) {
        throw ShoppingException(
          'Mục "${item.foodName}" có số lượng thực mua không hợp lệ (phải > 0).',
        );
      }
      if (item.expiryDate == null) {
        throw ShoppingException(
          'Mục "${item.foodName}" chưa có hạn sử dụng bắt buộc.',
        );
      }
      if (item.locationId == null || item.locationId!.trim().isEmpty) {
        throw ShoppingException(
          'Mục "${item.foodName}" chưa chọn vị trí lưu trữ trong kho.',
        );
      }

      final importDate = item.importDate ?? today;
      batchPayloads.add(
        NewPantryBatchPayload(
          foodId: item.foodId,
          locationId: item.locationId!,
          importDate: importDate,
          expiryDate: item.expiryDate!,
          quantity: item.actualQuantity,
          shoppingItemId: item.id,
          shoppingListName: currentList.name,
        ),
      );
      verifiedItems.add(item);
    }

    // 5. Delegate batch & movement creation to pantry writer contract
    await _pantrySyncWriter.importBatches(
      userId: userId,
      batches: batchPayloads,
    );

    // 6. Update item sync status on Supabase
    final now = DateTime.now().toUtc().toIso8601String();
    for (final item in verifiedItems) {
      await _supabase
          .from('chi_tiet_mua')
          .update({
            'da_dong_bo_kho': true,
            'ngay_dong_bo': now,
          })
          .eq('id', item.id)
          .eq('user_id', userId);
    }

    // 7. Check unbought items retention
    final unboughtCount =
        items.where((it) => !it.isBought && !it.isSynced).length;
    final totalSyncedNow =
        items.where((it) => it.isSynced).length + verifiedItems.length;
    final shouldCompleteList =
        unboughtCount == 0 || completeListIfUnboughtRemain;

    final updatedList = currentList.copyWith(
      status: shouldCompleteList
          ? ShoppingListStatus.completed
          : ShoppingListStatus.open,
      completedAt: shouldCompleteList ? DateTime.now() : currentList.completedAt,
      syncedItems: totalSyncedNow,
    );

    await _supabase
        .from('danh_sach_mua')
        .update({
          'trang_thai': updatedList.status.value,
          'ngay_hoan_tat': updatedList.completedAt?.toIso8601String(),
          'so_luong_da_dong_bo_count': totalSyncedNow,
        })
        .eq('id', listId)
        .eq('user_id', userId);

    return ShoppingSyncResult(
      listId: listId,
      syncedCount: verifiedItems.length,
      retainedCount: unboughtCount,
      isListCompleted: shouldCompleteList,
      syncedItems: verifiedItems,
      message: 'Đã đồng bộ thành công ${verifiedItems.length} mục vào kho.',
    );
  }

  Map<String, Object?> _normalizeMap(Map<String, dynamic> raw) {
    return raw.map((key, value) {
      if (value is String) {
        final dt = DateTime.tryParse(value);
        if (dt != null &&
            (key.contains('created_at') ||
                key.contains('updated_at') ||
                key.contains('ngay_tao') ||
                key.contains('ngay_hoan_tat') ||
                key.contains('ngay_dong_bo') ||
                key.contains('han_su_dung') ||
                key.contains('ngay_nhap'))) {
          return MapEntry(key, dt);
        }
      }
      return MapEntry(key, value);
    });
  }
}
