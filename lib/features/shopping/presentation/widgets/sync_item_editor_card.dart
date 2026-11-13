import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../data/adapters/pantry_adapter.dart';
import '../../data/models/shopping_item.dart';

/// Card used in the sync preparation view to input and review expiry date and storage location (MOD-02-07).
class SyncItemEditorCard extends StatelessWidget {
  const SyncItemEditorCard({
    super.key,
    required this.item,
    required this.locations,
    required this.onExpiryDateChanged,
    required this.onLocationChanged,
    required this.onActualQuantityChanged,
  });

  final ShoppingItem item;
  final List<StorageLocationInfo> locations;
  final ValueChanged<DateTime> onExpiryDateChanged;
  final ValueChanged<StorageLocationInfo> onLocationChanged;
  final ValueChanged<double> onActualQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final isReady = item.isReadyForSync;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        side: BorderSide(
          color: isReady ? AppColors.statusSuccess : AppColors.statusWarning,
          width: 1.5,
        ),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Food Name & Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isReady
                        ? AppColors.statusSuccessTint
                        : AppColors.statusWarningTint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isReady ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: isReady
                        ? AppColors.statusSuccess
                        : AppColors.statusWarning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.foodName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Số lượng: ${item.actualQuantity > 0 ? item.actualQuantity : item.plannedQuantity} ${item.unitName}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Form inputs: Expiry Date & Storage Location
            Row(
              children: [
                // Expiry Date Picker Button
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppColors.radiusInput),
                      ),
                      side: BorderSide(
                        color: item.expiryDate != null
                            ? AppColors.border
                            : AppColors.statusWarning,
                      ),
                    ),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      item.expiryDate != null
                          ? '${item.expiryDate!.day}/${item.expiryDate!.month}/${item.expiryDate!.year}'
                          : 'Chọn HSD *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: item.expiryDate != null
                            ? AppColors.textPrimary
                            : AppColors.statusWarning,
                      ),
                    ),
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: item.expiryDate ??
                            now.add(const Duration(days: 7)),
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 365 * 3)),
                      );
                      if (picked != null) {
                        onExpiryDateChanged(picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Location Dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: item.locationId != null &&
                            locations.any((l) => l.id == item.locationId)
                        ? item.locationId
                        : null,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppColors.radiusInput),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      hintText: 'Chọn vị trí *',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.statusWarning,
                      ),
                    ),
                    items: locations.map((loc) {
                      return DropdownMenuItem<String>(
                        value: loc.id,
                        child: Text(
                          loc.name,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (locId) {
                      if (locId != null) {
                        final matched =
                            locations.firstWhere((l) => l.id == locId);
                        onLocationChanged(matched);
                      }
                    },
                  ),
                ),
              ],
            ),

            if (!isReady) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: AppColors.statusWarning),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.missingSyncFields.join(', '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.statusWarning,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

