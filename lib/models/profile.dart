class Profile {
  final String id;
  final String fullName;
  final String email;
  final bool isAdmin;
  final DateTime createdAt;

  Profile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.isAdmin,
    required this.createdAt,
  });
  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      fullName: json['full_name'],
      email: json['email'],
      isAdmin: json['is_admin'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class ActivityLog {
  final String id;
  final String itemId;
  final String action;
  final int? oldQuantity;
  final int? newQuantity;
  final String changedBy;
  final String changedByName;
  final DateTime createdAt;

  ActivityLog({
    required this.id,
    required this.itemId,
    required this.action,
    this.oldQuantity,
    this.newQuantity,
    required this.changedBy,
    required this.changedByName,
    required this.createdAt,
  });
  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'],
      itemId: json['item_id'],
      action: json['action'],
      oldQuantity: json['old_quantity'],
      newQuantity: json['new_quantity'],
      changedBy: json['changed_by'],
      changedByName: json['changed_by_name'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  String get actionDescription {
    switch (action) {
      case 'created':
        return '$changedByName added this item';
      case 'deleted':
        return '$changedByName deleted this item';
      case 'stock_changed':
        final diff = (newQuantity ?? 0) - (oldQuantity ?? 0);
        final direction = diff > 0 ? 'added $diff' : 'removed ${diff.abs()}';
        return '$changedByName $direction units';
      default:
        return '$changedByName updated this item';
    }
  }
}
