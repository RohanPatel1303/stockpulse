import 'package:flutter/material.dart';
import 'package:stockpulse/main.dart';
import 'package:stockpulse/models/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/item.dart';

class InventoryProvider extends ChangeNotifier {
  List<Item> _items = [];
  List<ActivityLog> _activityLog = [];
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _itemChannel;
  RealtimeChannel? _activityChannel;

  List<Item> get items => _items;
  List<Item> get lowStockItems => _items.where((i) => i.isLowStock).toList();
  List<ActivityLog> get activityLogs => _activityLog;
  bool get isLoading => _isLoading;
  String? get error => _error;

  //Call this after user logs in
  Future<void> initialize() async {
    await fetchItems();
    await fetchActivityLog();
    _suscribeToRealtime();
  }

  //Fetch all items from the database
  Future<void> fetchItems() async {
    try {
      _isLoading = true;
      notifyListeners();
      final data = await supabase
          .from('items')
          .select()
          .order('created_at', ascending: false);
      print("the data received from supabase is: $data");
      _items=data.map((element)=>Item.fromJson(element)).toList();
      // _items = data.map<Item>((json) => Item.fromJson(json)).toList();
      print(_items.toString());
      _error = null;
    } catch (e) {
      print("something went wrong fetching items: $e");
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  //fetch activity logs
  Future<void> fetchActivityLog() async {
    try {
      final data = await supabase
          .from('activity_log')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      _activityLog = (data as List)
          .map((json) => ActivityLog.fromJson(json))
          .toList();
      notifyListeners();
    } catch (e) {
      //Activity log failures is non critical
      debugPrint('Activity log fetch error: $e');
    }
  }

  //Suscribe to realtime changes - This is the magic feature.
  void _suscribeToRealtime() {
    //Listen to items table changes
    _itemChannel = supabase
        .channel('items-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'items',
          callback: (payload) {
            final newItem = Item.fromJson(payload.newRecord);
            _items.insert(0, newItem);
            notifyListeners();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'items',
          callback: (payload) {
            final updatedItem = Item.fromJson(payload.newRecord);
            final index = _items.indexWhere((i) => i.id == updatedItem.id);
            if (index != -1) {
              _items[index] = updatedItem;
              notifyListeners();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'items',
          callback: (payload) {
            final updatedItem = Item.fromJson(payload.newRecord);
            final index = _items.indexWhere((i) => i.id == updatedItem.id);
            if (index != -1) {
              _items.removeAt(index);
              notifyListeners();
            }
          },
        )
        .subscribe();

    //Listen to activity log changes
    _activityChannel = supabase
        .channel('activity-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'activity_log',
          callback: (payload) {
            final newLog = ActivityLog.fromJson(payload.newRecord);
            _activityLog.insert(0, newLog);
            if (_activityLog.length > 50) _activityLog.removeLast();
            notifyListeners();
          },
        )
        .subscribe();
  }
  //Add new item (Admin only)
Future<String?> addItem({
    required String name,
  String? description,
  required int quantity,
  required int lowStockThreshold,
  String? location,
  String? imageUrl,
  required Profile currentUser,
})async{
    try{
      final qrcode=const Uuid().v4();//Unique QR code for the item
      final data = await supabase.from('items').insert({
        'name': name,
        'description': description,
        'quantity': quantity,
        'low_stock_threshold': lowStockThreshold,
        'location': location,
        'image_url': imageUrl,
        'qr_code': qrcode,
        'created_by':currentUser.id,
      }).select().single();

      //Log the activity
      await _logActivity(
        itemId: data['id'],
        itemName:name,
        action: 'created',
        newQuantity: quantity,
        currentUser:currentUser,
      );
      return null; //null== success
    }catch(e){
      return e.toString();
  }
}
//Update item quantity (both Admin and Staff can do this)
Future<String?> updateQuantity({
    required Item item,
  required int newQuantity,
  required Profile currentUser,
})async{
    try{
      await supabase.from('items').update({
        'quantity': newQuantity,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', item.id);

      await _logActivity(
        itemId: item.id,
        itemName:item.name,
        action: 'stock_changed',
        oldQuantity: item.quantity,
        newQuantity: newQuantity,
        currentUser:currentUser,
      );
      return null;
    }catch(e){
      return e.toString();
    }
}
//Update item details (Admin only)
Future<String?> updateItem({
    required Item item,
  required Map<String,dynamic> updates,
  required Profile currentUser,
})async{
    try{
      await supabase.from('items').update(updates).eq('id', item.id);

      await _logActivity(
        itemId: item.id,
        itemName:item.name,
        action: 'updated',
        currentUser:currentUser,
      );

      return null;

    }catch(e){
      return e.toString();

    }
}

//Delete item (Admin only)
Future<String?> deleteItem({
    required Item item,
  required Profile currentUser,})async {
  try {
    //log before deleting since cascade will remove the item
    await _logActivity(
      itemId: item.id,
      itemName: item.name,
      action: 'deleted',
      currentUser: currentUser,
    );

    await supabase.from('items').delete().eq('id', item.id);
    return null;
  } catch (e) {
    return e.toString();
  }
}
//find item by QR code
Item? findByQrCode(String qrCode){
    try{
      return _items.firstWhere((i)=>i.qrcode==qrCode);
    }catch(_){
      return null;
    }
}
Future<void> _logActivity({
    required String itemId,
  required String itemName,
  required String action,
  int? oldQuantity,
  int? newQuantity,
  required Profile currentUser,
})async{
    await supabase.from('activity_log').insert({
      'item_id':itemId,
      'item_name':itemName,
      'action':action,
      'old_quantity':oldQuantity,
      'new_quantity':newQuantity,
      'changed_by':currentUser.id,
      'changed_by_name':currentUser.fullName,
    });
}

void dispose(){
    _itemChannel?.unsubscribe();
    _activityChannel?.unsubscribe();
    super.dispose();
}
}
