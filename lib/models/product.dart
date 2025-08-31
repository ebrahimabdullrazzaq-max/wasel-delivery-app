class Product {
  final int id;
  final String name;
  final String image;
  final double price;
  final String? description;
  final int ? categoryId;
  final int? storeId;
  

  Product({
    required this.id,
    required this.name,
    required this.image,
    required this.price,
    this.description,
    this.categoryId,
    this.storeId,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
  id: json['id'],
  name: json['name'],
  price: double.parse(json['price'].toString()),
 image: json['image_url'] ?? json['image'] ?? '',
  description: json['description'],
categoryId: json['category_id'] as int?,
  storeId: json['store_id'] as int?,
);

Map<String, dynamic> toJson() {
  return {
    'id': id,
    'name': name,
    'price': price,
    'image': image,
    'description': description,
    'category_id': categoryId,
    
  };
}
}
