import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:stockpulse/providers/auth_provider.dart';
import 'package:stockpulse/providers/inventory_provider.dart';
import 'package:stockpulse/core/theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize inventory and start realtime subscription
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final inventory = context.watch<InventoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard'),
            Text(
              'Welcome, ${auth.profile?.fullName ?? ""}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await auth.signOut();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => inventory.fetchItems(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _StatCard(
                    label: 'Total Items',
                    value: inventory.items.fold<int>(0, (previous_value,element){
                      return previous_value+element.quantity;
                    }).toString(),
                    icon: Icons.inventory_2_rounded,
                    color: AppTheme.primary,
                  ),
                  _StatCard(
                    label: 'Total Stock',
                    value: '${inventory.items.length}',
                    icon: Icons.layers_rounded,
                    color: AppTheme.success,
                  ),
                  _StatCard(
                    label: 'Low Stock',
                    value: '${inventory.lowStockItems.length}',                    icon: Icons.warning_amber_rounded,
                    color: AppTheme.warning,
                  ),
                  _StatCard(
                    label: 'Out of Stock',
                    value: '${inventory.items.where((item)=>item.isOutOfStock).length}',
                    icon: Icons.remove_circle_outline_rounded,
                    color: AppTheme.danger,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Scan QR',
                      onTap: () => context.push('/scanner'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.list_alt_rounded,
                      label: 'Inventory',
                      onTap: () => context.push('/inventory'),
                    ),
                  ),
                  if (auth.isAdmin) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.add_box_rounded,
                        label: 'Add Item',
                        onTap: () => context.push('/inventory/add'),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 24),

              // Low stock alerts
              if (inventory.lowStockItems.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Low Stock Alerts',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    TextButton(
                      onPressed: () => context.push('/inventory'),
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...inventory.lowStockItems.take(3).map((item) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 8,
                      decoration: BoxDecoration(
                        color: item.isOutOfStock
                            ? AppTheme.danger
                            : AppTheme.warning,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                      ),
                    ),
                    title: Text(item.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(item.location ?? 'No location'),
                    trailing: Text(
                      '${item.quantity} left',
                      style: TextStyle(
                        color: item.isOutOfStock
                            ? AppTheme.danger
                            : AppTheme.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () => context.push('/inventory/${item.id}'),
                  ),
                )),
              ],

              const SizedBox(height: 24),

              // Recent Activity
              const Text(
                'Recent Activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (inventory.activityLogs.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No activity yet'),
                  ),
                )
              else
                ...inventory.activityLogs.take(5).map((log) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(Icons.history_rounded,
                        size: 20, color: AppTheme.primary),
                  ),
                  title: Text(log.itemId,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(log.actionDescription),
                  trailing: Text(
                    _timeAgo(log.createdAt),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                )),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}