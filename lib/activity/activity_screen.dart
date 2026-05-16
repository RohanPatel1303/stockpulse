import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:stockpulse/core/theme.dart';
import 'package:stockpulse/models/profile.dart';
import 'package:stockpulse/providers/inventory_provider.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final logs = inventory.activityLogs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => inventory.fetchActivityLog(),
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No activity yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text('Changes to inventory will appear here'),
          ],
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: logs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 2),
        itemBuilder: (context, index) {
          final log = logs[index];

          // Show date header when day changes
          final showDateHeader = index == 0 ||
              !_isSameDay(
                  logs[index - 1].createdAt, log.createdAt);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showDateHeader) ...[
                if (index != 0) const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _formatDateHeader(log.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[500],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
              _ActivityCard(log: log),
            ],
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    if (_isSameDay(dt, now)) return 'TODAY';
    if (_isSameDay(dt, now.subtract(const Duration(days: 1)))) return 'YESTERDAY';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityLog log;

  const _ActivityCard({required this.log});

  IconData get _icon {
    switch (log.action) {
      case 'created':
        return Icons.add_circle_outline_rounded;
      case 'deleted':
        return Icons.delete_outline_rounded;
      case 'stock_changed':
        final increased = (log.newQuantity ?? 0) > (log.oldQuantity ?? 0);
        return increased
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded;
      default:
        return Icons.edit_outlined;
    }
  }

  Color get _color {
    switch (log.action) {
      case 'created':
        return AppTheme.success;
      case 'deleted':
        return AppTheme.danger;
      case 'stock_changed':
        final increased = (log.newQuantity ?? 0) > (log.oldQuantity ?? 0);
        return increased ? AppTheme.success : AppTheme.warning;
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: log.action != 'deleted'
            ? () => context.push('/inventory/${log.itemId}')
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Action icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, color: _color, size: 20),
              ),
              const SizedBox(width: 12),

              // Log details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.itemId,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      log.actionDescription,
                      style:
                      TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    // Stock change detail
                    if (log.action == 'stock_changed' &&
                        log.oldQuantity != null &&
                        log.newQuantity != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _QuantityBadge(
                              value: log.oldQuantity!, color: Colors.grey),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.arrow_forward_rounded,
                                size: 14, color: Colors.grey),
                          ),
                          _QuantityBadge(
                              value: log.newQuantity!, color: _color),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Time
              Text(
                _timeAgo(log.createdAt),
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
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

class _QuantityBadge extends StatelessWidget {
  final int value;
  final Color color;

  const _QuantityBadge({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$value units',
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}