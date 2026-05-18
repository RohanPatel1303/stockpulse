import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:stockpulse/core/theme.dart';
import 'package:stockpulse/models/item.dart';
import 'package:stockpulse/providers/auth_provider.dart';
import 'package:stockpulse/providers/inventory_provider.dart';

enum StockFilter { all, lowStock, outOfStock }

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  StockFilter _filter = StockFilter.all;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Item> _applyFilters(List<Item> items) {
    var filtered = items;

    // Apply stock filter
    switch (_filter) {
      case StockFilter.lowStock:
        filtered = filtered.where((i) => i.isLowStock && !i.isOutOfStock).toList();
        break;
      case StockFilter.outOfStock:
        filtered = filtered.where((i) => i.isOutOfStock).toList();
        break;
      case StockFilter.all:
        break;
    }

    // Apply search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((i) =>
      i.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (i.location?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (i.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
          .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final auth = context.watch<AuthProvider>();
    final filteredItems = _applyFilters(inventory.items);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () => context.push('/scanner'),
          ),
        ],
      ),
      floatingActionButton: auth.isAdmin
          ? FloatingActionButton.extended(
        onPressed: () => context.push('/inventory/add'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Item'),
      )
          : null,
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search items, locations...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
                    : null,
              ),
            ),
          ),

          // Filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All (${inventory.items.length})',
                  selected: _filter == StockFilter.all,
                  onTap: () => setState(() => _filter = StockFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Low Stock (${inventory.lowStockItems.length})',
                  selected: _filter == StockFilter.lowStock,
                  color: AppTheme.warning,
                  onTap: () => setState(() => _filter = StockFilter.lowStock),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Out (${inventory.outOfStockItems.length})',
                  selected: _filter == StockFilter.outOfStock,
                  color: AppTheme.danger,
                  onTap: () => setState(() => _filter = StockFilter.outOfStock),
                ),
              ],
            ),
          ),

          // Low Stock Alert Banner
          if (inventory.lowStockItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: AppTheme.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Low Stock: ${inventory.lowStockItems.map((i) => i.name).join(", ")}',
                        style: const TextStyle(
                          color: AppTheme.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Item count
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                Text(
                  '${filteredItems.length} items',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),

          // Items list
          Expanded(
            child: inventory.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredItems.isEmpty
                ? _EmptyState(
              hasSearch: _searchQuery.isNotEmpty,
              isAdmin: auth.isAdmin,
            )
                : RefreshIndicator(
              onRefresh: () => inventory.fetchItems(),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return _ItemCard(item: item);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Item item;

  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    Color statusColor = AppTheme.success;
    String statusLabel = 'In Stock';

    if (item.isOutOfStock) {
      statusColor = AppTheme.danger;
      statusLabel = 'Out of Stock';
    } else if (item.isLowStock) {
      statusColor = AppTheme.warning;
      statusLabel = 'Low Stock';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => context.push('/inventory/${item.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Item image or placeholder
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: item.imageUrl != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.inventory_2_rounded,
                      color: AppTheme.primary,
                    ),
                  ),
                )
                    : const Icon(
                  Icons.inventory_2_rounded,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 14),

              // Item info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.location != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 13, color: Colors.grey[500]),
                          const SizedBox(width: 2),
                          Text(
                            item.location!,
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Quantity
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.quantity}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                  Text(
                    'units',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),

              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color = AppTheme.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: selected ? color : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.grey[600],
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final bool isAdmin;

  const _EmptyState({required this.hasSearch, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasSearch ? Icons.search_off_rounded : Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch ? 'No items match your search' : 'No items yet',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? 'Try a different search term'
                : isAdmin
                ? 'Tap + Add Item to get started'
                : 'Ask an admin to add items',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}