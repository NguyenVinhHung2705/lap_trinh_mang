import 'package:cloud_firestore/cloud_firestore.dart';

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

/// Domain service implementing atomic pantry synchronization (`MOD-02-08` / FR-16).
///
/// Invariants:
/// 1. Only imports items with confirmed actual bought quantity (`so_luong_da_mua > 0`).
/// 2. Requires non-null expiry date and valid user-owned storage location.
/// 3. Executes atomic Firestore transaction to create `lo_thuc_pham` and ledger
///    movement `bien_dong_kho` (`loai_bien_dong = 'IN'`, `so_luong_nhap > 0`, `so_luong_xuat = 0`).
/// 4. Idempotency (TC-M02-08): Re-syncing an already-synced item never creates duplicate IN records.
/// 5. Preservation: Unbought items are retained without losing future demand.
class ShoppingSyncService {
  ShoppingSyncService({
    required ShoppingRepository shoppingRepository,
    PantryReader? pantryReader,
    PantrySyncWriter? pantrySyncWriter,
    FirebaseFirestore? firestore,
  })  : _repository = shoppingRepository,
        _pantryReader = pantryReader ?? FirestorePantryAdapter(),
        _pantrySyncWriter = pantrySyncWriter ?? FirestorePantryAdapter(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final ShoppingRepository _repository;
  final PantryReader _pantryReader;
  final PantrySyncWriter _pantrySyncWriter;
  final FirebaseFirestore _firestore;

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

  /// Executes atomic synchronization to pantry in a single Firestore Transaction.
  Future<ShoppingSyncResult> completeAndSyncAtomic({
    required String userId,
    required String listId,
    bool completeListIfUnboughtRemain = false,
  }) async {
    final listRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('danh_sach_mua')
        .doc(listId);
    final itemsCollRef = listRef.collection('chi_tiet_mua');

    return _firestore.runTransaction<ShoppingSyncResult>((txn) async {
      // 1. Re-read list document on server inside transaction (Anti-conflict)
      final listSnap = await txn.get(listRef);
      if (!listSnap.exists || listSnap.data() == null) {
        throw const ShoppingNotFoundException('Danh sách mua sắm không tồn tại.');
      }

      final currentList = ShoppingList.fromMap(
        _normalizeMap(listSnap.data()!),
        id: listSnap.id,
      );

      // 2. Fetch all items on server
      final itemsSnap = await itemsCollRef.get();
      final items = itemsSnap.docs
          .map((d) => ShoppingItem.fromMap(_normalizeMap(d.data()), id: d.id))
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
      final today = DateTime.now();
      final batchPayloads = <NewPantryBatchPayload>[];
      final verifiedItems = <ShoppingItem>[];

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
      await _pantrySyncWriter.importBatchesInTransaction(
        userId: userId,
        transaction: txn,
        batches: batchPayloads,
      );

      // 6. Update item sync status on Firestore
      final now = DateTime.now();
      for (final item in verifiedItems) {
        final itemRef = itemsCollRef.doc(item.id);
        txn.update(itemRef, {
          'da_dong_bo_kho': true,
          'ngay_dong_bo': now.toIso8601String(),
        });
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
        completedAt: shouldCompleteList ? now : currentList.completedAt,
        syncedItems: totalSyncedNow,
      );

      txn.update(listRef, {
        'trang_thai': updatedList.status.value,
        'ngay_hoan_tat': updatedList.completedAt?.toIso8601String(),
        'so_luong_da_dong_bo_count': totalSyncedNow,
      });

      return ShoppingSyncResult(
        listId: listId,
        syncedCount: verifiedItems.length,
        retainedCount: unboughtCount,
        isListCompleted: shouldCompleteList,
        syncedItems: verifiedItems,
        message: 'Đã đồng bộ thành công ${verifiedItems.length} mục vào kho.',
      );
    });
  }

  Map<String, Object?> _normalizeMap(Map<String, dynamic> raw) {
    return raw.map((key, value) {
      if (value is Timestamp) {
        return MapEntry(key, value.toDate());
      }
      return MapEntry(key, value);
    });
  }
}

