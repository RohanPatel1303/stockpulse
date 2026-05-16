class Item{
  final String id;
  final String name;
  final String? description;
  final int quantity;
  final int lowStockThreshold;
  final String? location;
  final String? imageUrl;
  final String qrcode;
  final DateTime createdAt;
  final DateTime updatedAt;

  Item({
    required this.id,
    required this.name,
    this.description,
    required this.quantity,
    required this.lowStockThreshold,
    this.location,
    this.imageUrl,
    required this.qrcode,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock=>quantity<=lowStockThreshold;
  bool get isOutOfStock=>quantity==0;

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      quantity: json['quantity'],
      lowStockThreshold: json['low_stock_threshold'],
      location: json['location'],
      imageUrl: json['image_url'],
      qrcode: json['qrcode']??'',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String,dynamic> toJson(){
    return{
      'name':name,
      'description':description,
      'quantity':quantity,
      'low_stock_threshold':lowStockThreshold,
      'location':location,
      'image_url':imageUrl,
      'qrcode':qrcode,
    };
  }
  Item copyWith({
    String? name,
    String? description,
    int? quantity,
    int? lowStockThreshold,
    String? location,
    String? imageUrl,
  }){
    return Item(
      id: id,
      name: name??this.name,
      description: description??this.description,
      quantity: quantity??this.quantity,
      lowStockThreshold: lowStockThreshold??this.lowStockThreshold,
      location: location??this.location,
      imageUrl: imageUrl??this.imageUrl,
      qrcode: qrcode,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}