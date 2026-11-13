import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/shopping_item.dart';
import 'models/shopping_list.dart';

/// Base exception for shopping module operations.
class ShoppingException implements Exception {
  const ShoppingException(this.message);

  final String message;

  @override
  String toString() => 'ShoppingException: $message';
}

/// Thrown when a shopping list or item document is not found.
class ShoppingNotFoundException extends ShoppingException {
  const ShoppingNotFoundException([
    super.message = 'Không tìm thấy danh sách mua hoặc mục cần mua.',
  ]);
}

/// Thrown when trying to modify or delete an item that has already been synchronized to pantry.
class ShoppingAlreadySyncedException extends ShoppingException {
  const ShoppingAlreadySyncedException([
    super.message = 'Mục mua đã đồng bộ vào kho thực phẩm, không thể chỉnh sửa hoặc xóa.',
  ]);
}

/// Thrown when user tries to access a list belonging to another user.
class ShoppingPermissionException extends ShoppingException {
  const ShoppingPermissionException([
    super.message = 'Bạn không có quyền truy cập hoặc chỉnh sửa danh sách mua sắm này.',
  ]);
}

/// Data access layer for shopping lists and items (`MOD-02`).
///
/// Firestore collections:
/// - `/users/{uid}/danh_sach_mua/{listId}`
/// - `/users/{uid}/danh_sach_mua/{listId}/chi_tiet_mua/{itemId}`
class ShoppingRepository {
  ShoppingRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _listsRef(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('danh_sach_mua');
  }

  DocumentReference<Map<String, dynamic>> _listDoc(
    String userId,
    String listId,
  ) {
    return _listsRef(userId).doc(listId);
  }

  CollectionReference<Map<String, dynamic>> _itemsRef(
    String userId,
    String listId,
  ) {
    return _listDoc(userId, listId).collection('chi_tiet_mua');
  }

  // ---------------------------------------------------------------------------
  // SHOPPING LIST OPERATIONS (MOD-02-01 / FR-09)
  // ---------------------------------------------------------------------------

  /// Creates a new shopping list document for [userId].
  Future<ShoppingList> createShoppingList({
    required String userId,
    required String name,
    String? note,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const ShoppingException('Tên danh sách mua sắm không được để trống.');
    }

    final docRef = _listsRef(userId).doc();
    final now = DateTime.now();

    final newList = ShoppingList(
      id: docRef.id,
      userId: userId,
      name: trimmedName,
      createdAt: now,
      status: ShoppingListStatus.open,
      note: note?.trim(),
      totalItems: 0,
      boughtItems: 0,
      syncedItems: 0,
    );

    await docRef.set(newList.toMap());
    return newList;
  }

  /// Fetches a single shopping list by ID.
  Future<ShoppingList?> getShoppingList({
    required String userId,
    required String listId,
  }) async {
    final docSnap = await _listDoc(userId, listId).get();
    if (!docSnap.exists || docSnap.data() == null) return null;
    return ShoppingList.fromMap(_normalizeMap(docSnap.data()!), id: docSnap.id);
  }

  /// Queries all shopping lists for [userId], optionally filtered by status.
  Future<List<ShoppingList>> getShoppingLists({
    required String userId,
    ShoppingListStatus? status,
  }) async {
    Query<Map<String, dynamic>> query =
        _listsRef(userId).orderBy('ngay_tao', descending: true);

    if (status != null) {
      query = query.where('trang_thai', isEqualTo: status.value);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((d) => ShoppingList.fromMap(_normalizeMap(d.data()), id: d.id))
        .toList();
  }

  /// Streams shopping lists for [userId].
  Stream<List<ShoppingList>> watchShoppingLists({
    required String userId,
    ShoppingListStatus? status,
  }) {
    Query<Map<String, dynamic>> query =
        _listsRef(userId).orderBy('ngay_tao', descending: true);

    if (status != null) {
      query = query.where('trang_thai', isEqualTo: status.value);
    }

    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map(
                (d) => ShoppingList.fromMap(
                  _normalizeMap(d.data()),
                  id: d.id,
                ),
              )
              .toList(),
        );
  }

  /// Updates shopping list metadata (e.g. name, status, notes).
  Future<ShoppingList> updateShoppingList({
    required String userId,
    required ShoppingList list,
  }) async {
    if (list.userId != userId) {
      throw const ShoppingPermissionException();
    }
    final docRef = _listDoc(userId, list.id);
    final snap = await docRef.get();
    if (!snap.exists) {
      throw const ShoppingNotFoundException('Danh sách mua sắm không tồn tại.');
    }

    await docRef.update(list.toMap());
    return list;
  }

  /// Deletes a shopping list.
  ///
  /// Business rule: Cannot delete a list that is already COMPLETED to prevent
  /// audit trail distortion. Unsynced lists can be deleted along with their items.
  Future<void> deleteShoppingList({
    required String userId,
    required String listId,
  }) async {
    final docRef = _listDoc(userId, listId);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) {
      throw const ShoppingNotFoundException();
    }

    final existing = ShoppingList.fromMap(
      _normalizeMap(snap.data()!),
      id: snap.id,
    );

    if (existing.isCompleted) {
      throw const ShoppingException(
        'Không thể xóa danh sách mua sắm đã hoàn tất.',
      );
    }

    // Delete subcollection items then list doc
    final itemsSnap = await _itemsRef(userId, listId).get();
    final batch = _firestore.batch();
    for (final doc in itemsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(docRef);
    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // SHOPPING ITEM OPERATIONS (MOD-02-02 / FR-10)
  // ---------------------------------------------------------------------------

  /// Adds a new item to [listId].
  Future<ShoppingItem> addItem({
    required String userId,
    required String listId,
    required ShoppingItem item,
  }) async {
    final listSnap = await _listDoc(userId, listId).get();
    if (!listSnap.exists || listSnap.data() == null) {
      throw const ShoppingNotFoundException('Danh sách mua sắm không tồn tại.');
    }

    final currentList = ShoppingList.fromMap(
      _normalizeMap(listSnap.data()!),
      id: listSnap.id,
    );

    if (currentList.isCompleted) {
      throw const ShoppingException(
        'Không thể thêm mục vào danh sách mua đã hoàn tất.',
      );
    }

    final itemRef = item.id.isNotEmpty
        ? _itemsRef(userId, listId).doc(item.id)
        : _itemsRef(userId, listId).doc();

    final itemToSave = item.id.isNotEmpty ? item : item.copyWith(id: itemRef.id);

    await itemRef.set(itemToSave.toMap());
    await recalculateCounters(userId: userId, listId: listId);
    return itemToSave;
  }

  /// Fetches a single item by ID.
  Future<ShoppingItem?> getItem({
    required String userId,
    required String listId,
    required String itemId,
  }) async {
    final snap = await _itemsRef(userId, listId).doc(itemId).get();
    if (!snap.exists || snap.data() == null) return null;
    return ShoppingItem.fromMap(_normalizeMap(snap.data()!), id: snap.id);
  }

  /// Fetches all items in [listId].
  Future<List<ShoppingItem>> getItems({
    required String userId,
    required String listId,
  }) async {
    final snapshot = await _itemsRef(userId, listId)
        .orderBy('ngay_tao', descending: false)
        .get();
    return snapshot.docs
        .map((d) => ShoppingItem.fromMap(_normalizeMap(d.data()), id: d.id))
        .toList();
  }

  /// Streams items in [listId] for real-time UI.
  Stream<List<ShoppingItem>> watchItems({
    required String userId,
    required String listId,
  }) {
    return _itemsRef(userId, listId)
        .orderBy('ngay_tao', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (d) => ShoppingItem.fromMap(
                  _normalizeMap(d.data()),
                  id: d.id,
                ),
              )
              .toList(),
        );
  }

  /// Updates an existing shopping item.
  ///
  /// Business rule: If already synced to pantry, mutation is prohibited.
  Future<ShoppingItem> updateItem({
    required String userId,
    required String listId,
    required ShoppingItem item,
  }) async {
    final itemRef = _itemsRef(userId, listId).doc(item.id);
    final snap = await itemRef.get();
    if (!snap.exists || snap.data() == null) {
      throw const ShoppingNotFoundException('Mục mua sắm không tồn tại.');
    }

    final existing = ShoppingItem.fromMap(
      _normalizeMap(snap.data()!),
      id: snap.id,
    );

    if (existing.isSynced) {
      throw const ShoppingAlreadySyncedException();
    }

    await itemRef.update(item.toMap());
    await recalculateCounters(userId: userId, listId: listId);
    return item;
  }

  /// Removes an item from the list.
  ///
  /// Business rule: Cannot remove an item that has already been synced to pantry.
  Future<void> removeItem({
    required String userId,
    required String listId,
    required String itemId,
  }) async {
    final itemRef = _itemsRef(userId, listId).doc(itemId);
    final snap = await itemRef.get();
    if (!snap.exists || snap.data() == null) {
      throw const ShoppingNotFoundException();
    }

    final existing = ShoppingItem.fromMap(
      _normalizeMap(snap.data()!),
      id: snap.id,
    );

    if (existing.isSynced) {
      throw const ShoppingAlreadySyncedException();
    }

    await itemRef.delete();
    await recalculateCounters(userId: userId, listId: listId);
  }

  /// Toggles bought status during shopping mode (MOD-02-05 / FR-13).
  ///
  /// Does NOT trigger pantry sync!
  Future<ShoppingItem> setItemBoughtStatus({
    required String userId,
    required String listId,
    required String itemId,
    required bool isBought,
    double? actualQuantity,
  }) async {
    final itemRef = _itemsRef(userId, listId).doc(itemId);
    final snap = await itemRef.get();
    if (!snap.exists || snap.data() == null) {
      throw const ShoppingNotFoundException();
    }

    final existing = ShoppingItem.fromMap(
      _normalizeMap(snap.data()!),
      id: snap.id,
    );

    if (existing.isSynced) {
      throw const ShoppingAlreadySyncedException();
    }

    final newActual = actualQuantity ??
        (isBought && existing.actualQuantity == 0.0
            ? existing.plannedQuantity
            : existing.actualQuantity);

    final updated = existing.copyWith(
      isBought: isBought,
      actualQuantity: isBought ? newActual : 0.0,
    );

    await itemRef.update({
      'da_mua': isBought,
      'so_luong_da_mua': updated.actualQuantity,
    });

    await recalculateCounters(userId: userId, listId: listId);
    return updated;
  }

  /// Updates actual bought quantity, expiry date, and storage location (MOD-02-06, MOD-02-07).
  Future<ShoppingItem> updateItemActualDetails({
    required String userId,
    required String listId,
    required String itemId,
    required double actualQuantity,
    DateTime? expiryDate,
    String? locationId,
    String? locationName,
  }) async {
    final itemRef = _itemsRef(userId, listId).doc(itemId);
    final snap = await itemRef.get();
    if (!snap.exists || snap.data() == null) {
      throw const ShoppingNotFoundException();
    }

    final existing = ShoppingItem.fromMap(
      _normalizeMap(snap.data()!),
      id: snap.id,
    );

    if (existing.isSynced) {
      throw const ShoppingAlreadySyncedException();
    }

    final updated = existing.copyWith(
      actualQuantity: actualQuantity,
      isBought: actualQuantity > 0,
      expiryDate: expiryDate,
      locationId: locationId,
      locationName: locationName,
    );

    await itemRef.update(updated.toMap());
    await recalculateCounters(userId: userId, listId: listId);
    return updated;
  }

  /// Recalculates cached statistics on the parent list document.
  Future<void> recalculateCounters({
    required String userId,
    required String listId,
  }) async {
    final listDocRef = _listDoc(userId, listId);
    final snap = await _itemsRef(userId, listId).get();

    final total = snap.docs.length;
    var bought = 0;
    var synced = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['da_mua'] == true || (data['so_luong_da_mua'] as num? ?? 0) > 0) {
        bought++;
      }
      if (data['da_dong_bo_kho'] == true) {
        synced++;
      }
    }

    await listDocRef.update({
      'so_luong_muc': total,
      'so_luong_da_mua_count': bought,
      'so_luong_da_dong_bo_count': synced,
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

