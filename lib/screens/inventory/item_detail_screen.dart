import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:stockpulse/core/theme.dart';
import 'package:stockpulse/models/item.dart';
import 'package:stockpulse/providers/auth_provider.dart';
import 'package:stockpulse/providers/inventory_provider.dart';

class ItemDetailScreen extends StatefulWidget {
  final String itemId;

  const ItemDetailScreen({super.key, required this.itemId});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late int _tempQuantity;
  bool _quantityChanged = false;
  bool _isSaving = false;

  Item? get _item {
    final inventory = context.read<InventoryProvider>();
    try {
      return inventory.items.firstWhere((i) => i.id == widget.itemId);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _tempQuantity = _item?.quantity ?? 0;
  }

  void _adjustQuantity(int delta) {
    final newQty = _tempQuantity + delta;
    if (newQty < 0) return;
    setState(() {
      _tempQuantity = newQty;
      _quantityChanged = newQty != (_item?.quantity ?? 0);
    });
  }

  Future<void> _saveQuantity() async {
    final item = _item;
    if (item == null) return;

    final auth = context.read<AuthProvider>();
    final inventory = context.read<InventoryProvider>();

    if (auth.profile == null) return;

    setState(() => _isSaving = true);

    final error = await inventory.updateQuantity(
      item: item,
      newQuantity: _tempQuantity,
      currentUser: auth.profile!,
    );

    setState(() {
      _isSaving = false;
      _quantityChanged = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Stock updated successfully'),
          backgroundColor: error != null ? Colors.red : AppTheme.success,
        ),
      );
    }
  }

  Future<void> _deleteItem(Item item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text(
            'Are you sure you want to delete "${item.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final inventory = context.read<InventoryProvider>();

    if (auth.profile == null) return;

    final error = await inventory.deleteItem(
      item: item,
      currentUser: auth.profile!,
    );

    if (mounted) {
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      } else {
        context.pop();
      }
    }
  }

  void _showQrDialog(Item item) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              QrImageView(
                data: item.qrcode,
                version: QrVersions.auto,
                size: 220,
              ),
              const SizedBox(height: 12),
              Text(
                'Scan to find this item instantly',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch inventory so UI updates in realtime
    final inventory = context.watch<InventoryProvider>();
    final auth = context.watch<AuthProvider>();

    final item = inventory.items.where((i) => i.id == widget.itemId).firstOrNull;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Item not found')),
      );
    }

    // Sync temp quantity if realtime update comes in and user hasn't changed it
    if (!_quantityChanged && _tempQuantity != item.quantity) {
      _tempQuantity = item.quantity;
    }

    Color statusColor = AppTheme.success;
    String statusLabel = 'In Stock';
    if (item.isOutOfStock) {
      statusColor = AppTheme.danger;
      statusLabel = 'Out of Stock';
    } else if (item.isLowStock) {
      statusColor = AppTheme.warning;
      statusLabel = 'Low Stock';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        actions: [
          // QR code button
          IconButton(
            icon: const Icon(Icons.qr_code_rounded),
            onPressed: () => _showQrDialog(item),
          ),
          // Admin-only edit/delete
          if (auth.isAdmin)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  context.push('/inventory/add', extra: item);
                } else if (value == 'delete') {
                  _deleteItem(item);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Edit Item'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: AppTheme.danger)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item image
            if (item.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  item.imageUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),

            const SizedBox(height: 16),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                    color: statusColor, fontWeight: FontWeight.w700),
              ),
            ),

            const SizedBox(height: 16),

            // Info cards
            _InfoRow(icon: Icons.label_outline, label: 'Name', value: item.name),
            if (item.description != null)
              _InfoRow(
                  icon: Icons.notes_rounded,
                  label: 'Description',
                  value: item.description!),
            if (item.location != null)
              _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: item.location!),
            _InfoRow(
              icon: Icons.warning_amber_rounded,
              label: 'Low Stock Alert',
              value: 'Below ${item.lowStockThreshold} units',
            ),

            const SizedBox(height: 24),

            // Quantity adjuster
            const Text(
              'Update Stock',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Decrease button
                        _QuantityButton(
                          icon: Icons.remove_rounded,
                          color: AppTheme.danger,
                          onTap: () => _adjustQuantity(-1),
                        ),
                        const SizedBox(width: 24),
                        // Quantity display
                        Column(
                          children: [
                            Text(
                              '$_tempQuantity',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                            Text(
                              'units',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        // Increase button
                        _QuantityButton(
                          icon: Icons.add_rounded,
                          color: AppTheme.success,
                          onTap: () => _adjustQuantity(1),
                        ),
                      ],
                    ),

                    // Quick adjust buttons
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [-10, -5, 5, 10].map((delta) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: OutlinedButton(
                            onPressed: () => _adjustQuantity(delta),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                            ),
                            child: Text(
                              delta > 0 ? '+$delta' : '$delta',
                              style: TextStyle(
                                color: delta > 0
                                    ? AppTheme.success
                                    : AppTheme.danger,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // Save button
                    if (_quantityChanged) ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveQuantity,
                        child: _isSaving
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                            : Text(
                          'Save (${_tempQuantity - item.quantity > 0 ? "+" : ""}${_tempQuantity - item.quantity} units)',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Timestamps
            Text(
              'Added ${_formatDate(item.createdAt)} · Updated ${_formatDate(item.updatedAt)}',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuantityButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}