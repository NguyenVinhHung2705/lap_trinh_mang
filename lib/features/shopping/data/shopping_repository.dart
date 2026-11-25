import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/shopping_item.dart';
import 'models/shopping_list.dart';
import 'shopping_mock_data.dart';

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
/// Supabase tables:
/// - `danh_sach_mua` (id UUID PK, user_id, ten, ghi_chu, trang_thai, created_at, updated_at)
/// - `chi_tiet_mua` (id UUID PK, danh_sach_id UUID FK, user_id, thuc_pham_id, ten_thuc_pham, so_luong_can, so_luong_da_mua, don_vi, da_mua, ghi_chu, created_at)
class ShoppingRepository {
  ShoppingRepository({SupabaseClient? supabase})
      : _customSupabase = supabase;

  final SupabaseClient? _customSupabase;
  SupabaseClient get _supabase =>
      _customSupabase ?? Supabase.instance.client;

  bool _isMockUser(String userId) =>
      userId.isEmpty || userId.startsWith('mock_') || userId == 'test_user_id';

  final List<ShoppingList> _memoryLists =
      List<ShoppingList>.from(ShoppingMockData.initialLists);
  final Map<String, List<ShoppingItem>> _memoryItems =
      Map<String, List<ShoppingItem>>.from(ShoppingMockData.initialItems);

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

    if (_isMockUser(userId)) {
      final id = 'shop_list_${DateTime.now().millisecondsSinceEpoch}';
      final newList = ShoppingList(
        id: id,
        userId: userId,
        name: trimmedName,
        createdAt: DateTime.now(),
        status: ShoppingListStatus.open,
        note: note?.trim(),
      );
      _memoryLists.insert(0, newList);
      _memoryItems[id] = [];
      return newList;
    }

    final now = DateTime.now().toUtc().toIso8601String();

    final data = {
      'user_id': userId,
      'ten': trimmedName,
      'ghi_chu': note?.trim(),
      'trang_thai': 'OPEN',
      'created_at': now,
      'updated_at': now,
    };

    final result = await _supabase
        .from('danh_sach_mua')
        .insert(data)
        .select()
        .single();

    return ShoppingList.fromMap(_normalizeMap(result), id: result['id'] as String);
  }

  /// Fetches a single shopping list by ID.
  Future<ShoppingList?> getShoppingList({
    required String userId,
    required String listId,
  }) async {
    if (_isMockUser(userId)) {
      return _memoryLists.cast<ShoppingList?>().firstWhere(
            (l) => l?.id == listId,
            orElse: () => null,
          );
    }
    final result = await _supabase
        .from('danh_sach_mua')
        .select()
        .eq('id', listId)
        .eq('user_id', userId)
        .maybeSingle();

    if (result == null) return null;
    return ShoppingList.fromMap(_normalizeMap(result), id: result['id'] as String);
  }

  /// Queries all shopping lists for [userId], optionally filtered by status.
  Future<List<ShoppingList>> getShoppingLists({
    required String userId,
    ShoppingListStatus? status,
  }) async {
    if (_isMockUser(userId)) {
      var lists = List<ShoppingList>.from(_memoryLists);
      if (status != null) {
        lists = lists.where((l) => l.status == status).toList();
      }
      return lists;
    }

    var query = _supabase
        .from('danh_sach_mua')
        .select()
        .eq('user_id', userId);

    if (status != null) {
      query = query.eq('trang_thai', status.value);
    }

    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((row) => ShoppingList.fromMap(
              _normalizeMap(row as Map<String, dynamic>),
              id: row['id'] as String,
            ))
        .toList();
  }

  /// Streams shopping lists for [userId].
  Stream<List<ShoppingList>> watchShoppingLists({
    required String userId,
    ShoppingListStatus? status,
  }) {
    if (_isMockUser(userId)) {
      var lists = List<ShoppingList>.from(_memoryLists);
      if (status != null) {
        lists = lists.where((l) => l.status == status).toList();
      }
      return Stream.value(lists);
    }

    final stream = _supabase
        .from('danh_sach_mua')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId);

    return stream.map((rows) {
      var filtered = rows.map((row) {
        return ShoppingList.fromMap(
          _normalizeMap(row),
          id: row['id'] as String,
        );
      }).toList();

      if (status != null) {
        filtered = filtered.where((l) => l.status == status).toList();
      }

      // Sort by createdAt descending
      filtered.sort((a, b) => (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000)));

      return filtered;
    });
  }

  /// Updates shopping list metadata (e.g. name, status, notes).
  Future<ShoppingList> updateShoppingList({
    required String userId,
    required ShoppingList list,
  }) async {
    if (list.userId != userId) {
      throw const ShoppingPermissionException();
    }
    if (_isMockUser(userId)) {
      final idx = _memoryLists.indexWhere((l) => l.id == list.id);
      if (idx != -1) {
        _memoryLists[idx] = list;
      }
      return list;
    }

    // Check existence
    final existing = await _supabase
        .from('danh_sach_mua')
        .select('id')
        .eq('id', list.id)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing == null) {
      throw const ShoppingNotFoundException('Danh sách mua sắm không tồn tại.');
    }

    await _supabase
        .from('danh_sach_mua')
        .update(list.toMap())
        .eq('id', list.id)
        .eq('user_id', userId);

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
    if (_isMockUser(userId)) {
      _memoryLists.removeWhere((l) => l.id == listId);
      _memoryItems.remove(listId);
      return;
    }

    final result = await _supabase
        .from('danh_sach_mua')
        .select()
        .eq('id', listId)
        .eq('user_id', userId)
        .maybeSingle();

    if (result == null) {
      throw const ShoppingNotFoundException();
    }

    final existing = ShoppingList.fromMap(
      _normalizeMap(result),
      id: result['id'] as String,
    );

    if (existing.isCompleted) {
      throw const ShoppingException(
        'Không thể xóa danh sách mua sắm đã hoàn tất.',
      );
    }

    // Delete child items first, then the list
    await _supabase
        .from('chi_tiet_mua')
        .delete()
        .eq('danh_sach_id', listId)
        .eq('user_id', userId);

    await _supabase
        .from('danh_sach_mua')
        .delete()
        .eq('id', listId)
        .eq('user_id', userId);
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
    if (_isMockUser(userId)) {
      final itemId = item.id.isNotEmpty
          ? item.id
          : 'shop_item_${DateTime.now().millisecondsSinceEpoch}';
      final itemToSave = item.copyWith(id: itemId);
      _memoryItems.putIfAbsent(listId, () => []).add(itemToSave);
      await recalculateCounters(userId: userId, listId: listId);
      return itemToSave;
    }

    // Check list exists and is not completed
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

    if (currentList.isCompleted) {
      throw const ShoppingException(
        'Không thể thêm mục vào danh sách mua đã hoàn tất.',
      );
    }

    final itemData = item.toMap();
    itemData['danh_sach_id'] = listId;
    itemData['user_id'] = userId;
    // Remove the id if empty so the DB generates a UUID
    if (item.id.isEmpty) {
      itemData.remove('id');
    }

    final result = await _supabase
        .from('chi_tiet_mua')
        .insert(itemData)
        .select()
        .single();

    final savedItem = ShoppingItem.fromMap(
      _normalizeMap(result),
      id: result['id'] as String,
    );

    await recalculateCounters(userId: userId, listId: listId);
    return savedItem;
  }

  /// Fetches a single item by ID.
  Future<ShoppingItem?> getItem({
    required String userId,
    required String listId,
    required String itemId,
  }) async {
    if (_isMockUser(userId)) {
      final items = _memoryItems[listId] ?? [];
      return items.cast<ShoppingItem?>().firstWhere(
            (i) => i?.id == itemId,
            orElse: () => null,
          );
    }
    final result = await _supabase
        .from('chi_tiet_mua')
        .select()
        .eq('id', itemId)
        .eq('danh_sach_id', listId)
        .eq('user_id', userId)
        .maybeSingle();

    if (result == null) return null;
    return ShoppingItem.fromMap(_normalizeMap(result), id: result['id'] as String);
  }

  /// Fetches all items in [listId].
  Future<List<ShoppingItem>> getItems({
    required String userId,
    required String listId,
  }) async {
    if (_isMockUser(userId)) {
      return List<ShoppingItem>.from(_memoryItems[listId] ?? []);
    }
    final rows = await _supabase
        .from('chi_tiet_mua')
        .select()
        .eq('danh_sach_id', listId)
        .eq('user_id', userId)
        .order('created_at', ascending: true);

    return (rows as List)
        .map((row) => ShoppingItem.fromMap(
              _normalizeMap(row as Map<String, dynamic>),
              id: row['id'] as String,
            ))
        .toList();
  }

  /// Streams items in [listId] for real-time UI.
  Stream<List<ShoppingItem>> watchItems({
    required String userId,
    required String listId,
  }) {
    if (_isMockUser(userId)) {
      return Stream.value(List<ShoppingItem>.from(_memoryItems[listId] ?? []));
    }

    return _supabase
        .from('chi_tiet_mua')
        .stream(primaryKey: ['id'])
        .eq('danh_sach_id', listId)
        .map((rows) {
      final items = rows
          .where((row) => row['user_id'] == userId)
          .map((row) => ShoppingItem.fromMap(
                _normalizeMap(row),
                id: row['id'] as String,
              ))
          .toList();
      // Sort by created_at ascending
      items.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(2000);
        final bDate = b.createdAt ?? DateTime(2000);
        return aDate.compareTo(bDate);
      });
      return items;
    });
  }

  /// Updates an existing shopping item.
  ///
  /// Business rule: If already synced to pantry, mutation is prohibited.
  Future<ShoppingItem> updateItem({
    required String userId,
    required String listId,
    required ShoppingItem item,
  }) async {
    if (_isMockUser(userId)) {
      final items = _memoryItems[listId] ?? [];
      final idx = items.indexWhere((i) => i.id == item.id);
      if (idx != -1) {
        items[idx] = item;
      }
      await recalculateCounters(userId: userId, listId: listId);
      return item;
    }

    final existingRow = await _supabase
        .from('chi_tiet_mua')
        .select()
        .eq('id', item.id)
        .eq('danh_sach_id', listId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existingRow == null) {
      throw const ShoppingNotFoundException('Mục mua sắm không tồn tại.');
    }

    final existing = ShoppingItem.fromMap(
      _normalizeMap(existingRow),
      id: existingRow['id'] as String,
    );

    if (existing.isSynced) {
      throw const ShoppingAlreadySyncedException();
    }

    await _supabase
        .from('chi_tiet_mua')
        .update(item.toMap())
        .eq('id', item.id)
        .eq('user_id', userId);

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
    if (_isMockUser(userId)) {
      _memoryItems[listId]?.removeWhere((i) => i.id == itemId);
      await recalculateCounters(userId: userId, listId: listId);
      return;
    }

    final existingRow = await _supabase
        .from('chi_tiet_mua')
        .select()
        .eq('id', itemId)
        .eq('danh_sach_id', listId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existingRow == null) {
      throw const ShoppingNotFoundException();
    }

    final existing = ShoppingItem.fromMap(
      _normalizeMap(existingRow),
      id: existingRow['id'] as String,
    );

    if (existing.isSynced) {
      throw const ShoppingAlreadySyncedException();
    }

    await _supabase
        .from('chi_tiet_mua')
        .delete()
        .eq('id', itemId)
        .eq('user_id', userId);

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
    if (_isMockUser(userId)) {
      final items = _memoryItems[listId] ?? [];
      final idx = items.indexWhere((i) => i.id == itemId);
      if (idx != -1) {
        final existing = items[idx];
        final newActual = actualQuantity ??
            (isBought && existing.actualQuantity == 0.0
                ? existing.plannedQuantity
                : existing.actualQuantity);
        final updated = existing.copyWith(
          isBought: isBought,
          actualQuantity: isBought ? newActual : 0.0,
        );
        items[idx] = updated;
        await recalculateCounters(userId: userId, listId: listId);
        return updated;
      }
    }

    final existingRow = await _supabase
        .from('chi_tiet_mua')
        .select()
        .eq('id', itemId)
        .eq('danh_sach_id', listId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existingRow == null) {
      throw const ShoppingNotFoundException();
    }

    final existing = ShoppingItem.fromMap(
      _normalizeMap(existingRow),
      id: existingRow['id'] as String,
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

    await _supabase
        .from('chi_tiet_mua')
        .update({
          'da_mua': isBought,
          'so_luong_da_mua': updated.actualQuantity,
        })
        .eq('id', itemId)
        .eq('user_id', userId);

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
    if (_isMockUser(userId)) {
      final items = _memoryItems[listId] ?? [];
      final idx = items.indexWhere((i) => i.id == itemId);
      if (idx != -1) {
        final existing = items[idx];
        final updated = existing.copyWith(
          actualQuantity: actualQuantity,
          isBought: actualQuantity > 0,
          expiryDate: expiryDate,
          locationId: locationId,
          locationName: locationName,
        );
        items[idx] = updated;
        await recalculateCounters(userId: userId, listId: listId);
        return updated;
      }
    }

    final existingRow = await _supabase
        .from('chi_tiet_mua')
        .select()
        .eq('id', itemId)
        .eq('danh_sach_id', listId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existingRow == null) {
      throw const ShoppingNotFoundException();
    }

    final existing = ShoppingItem.fromMap(
      _normalizeMap(existingRow),
      id: existingRow['id'] as String,
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

    await _supabase
        .from('chi_tiet_mua')
        .update(updated.toMap())
        .eq('id', itemId)
        .eq('user_id', userId);

    await recalculateCounters(userId: userId, listId: listId);
    return updated;
  }

  /// Recalculates cached statistics on the parent list row.
  Future<void> recalculateCounters({
    required String userId,
    required String listId,
  }) async {
    if (_isMockUser(userId)) {
      final items = _memoryItems[listId] ?? [];
      final total = items.length;
      var bought = 0;
      var synced = 0;
      for (final it in items) {
        if (it.isBought || it.actualQuantity > 0) bought++;
        if (it.isSynced) synced++;
      }
      final idx = _memoryLists.indexWhere((l) => l.id == listId);
      if (idx != -1) {
        _memoryLists[idx] = _memoryLists[idx].copyWith(
          totalItems: total,
          boughtItems: bought,
          syncedItems: synced,
        );
      }
      return;
    }

    final rows = await _supabase
        .from('chi_tiet_mua')
        .select()
        .eq('danh_sach_id', listId)
        .eq('user_id', userId);

    final total = (rows as List).length;
    var bought = 0;
    var synced = 0;

    for (final row in rows) {
      final data = row as Map<String, dynamic>;
      if (data['da_mua'] == true || (data['so_luong_da_mua'] as num? ?? 0) > 0) {
        bought++;
      }
      if (data['da_dong_bo_kho'] == true) {
        synced++;
      }
    }

    await _supabase
        .from('danh_sach_mua')
        .update({
          'so_luong_muc': total,
          'so_luong_da_mua_count': bought,
          'so_luong_da_dong_bo_count': synced,
        })
        .eq('id', listId)
        .eq('user_id', userId);
  }

  Map<String, Object?> _normalizeMap(Map<String, dynamic> raw) {
    return raw.map((key, value) {
      if (value is String) {
        // Try to parse ISO 8601 date strings from Supabase TIMESTAMPTZ columns
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
