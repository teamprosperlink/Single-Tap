import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/catalog_item.dart';

/// Reusable bottom sheet for catalog item actions (Edit, Toggle availability, Delete).
///
/// Used by both [BusinessHubScreen] and [CatalogManagementScreen] to avoid
/// duplicating the same options sheet code.
class ItemOptionsSheet {
  /// Shows a modal bottom sheet with Edit, Toggle Availability, and Delete
  /// options for the given [item].
  ///
  /// [unavailableLabel] controls the text shown when the item is currently
  /// available (e.g. "Mark Unavailable" or "Mark Sold Out").
  /// [availableLabel] controls the text shown when the item is currently
  /// unavailable.
  static void show(
    BuildContext context, {
    required CatalogItem item,
    required VoidCallback onEdit,
    required Future<void> Function() onToggleAvailability,
    required Future<void> Function() onDelete,
    String unavailableLabel = 'Mark Unavailable',
    String availableLabel = 'Mark Available',
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final textColor = AppTheme.textPrimary(isDark);

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),

              // Edit
              ListTile(
                leading: Icon(Icons.edit_outlined, color: textColor),
                title: Text('Edit', style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(ctx);
                  onEdit();
                },
              ),

              // Toggle availability
              ListTile(
                leading: Icon(
                  item.isAvailable
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: textColor,
                ),
                title: Text(
                  item.isAvailable ? unavailableLabel : availableLabel,
                  style: TextStyle(color: textColor),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await onToggleAvailability();
                },
              ),

              // Delete (with confirmation)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppTheme.errorStatus,
                ),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: AppTheme.errorStatus),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dlgCtx) {
                      final dlgTextColor = AppTheme.textPrimary(isDark);
                      return AlertDialog(
                        backgroundColor: AppTheme.cardColor(isDark),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Text(
                          'Delete Item',
                          style: TextStyle(color: dlgTextColor),
                        ),
                        content: Text(
                          'Delete "${item.name}"?',
                          style: TextStyle(
                            color: dlgTextColor.withValues(alpha: 0.7),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dlgCtx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dlgCtx, true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: AppTheme.errorStatus),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                  if (confirm == true) {
                    await onDelete();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
