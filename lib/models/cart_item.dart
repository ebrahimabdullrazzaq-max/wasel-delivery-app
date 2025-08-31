import 'product.dart';

class CartItem {
  final int id;
  final String name;
  final String image; // just the file path like "products/xyz.png"
  final double price;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.image,
    required this.price,
    this.quantity = 1,
  });

  // Return full image URL
  String get fullImageUrl =>
      image.startsWith('http') ? image : 'http://192.168.43.181:8000/storage/$image';

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      name: json['name'],
      image: json['image'],
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] ?? 1,
    );
  }
  

  get product => null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'image': image,
        'price': price,
        'quantity': quantity,
      };
}
