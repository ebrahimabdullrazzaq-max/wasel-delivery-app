// models/store_category.dart
class StoreCategory {
  final int id;
  final String name;
  final String? image;
  final bool isActive;

  StoreCategory({
    required this.id,
    required this.name,
    this.image,
    this.isActive = true,
  });

  factory StoreCategory.fromJson(Map<String, dynamic> json) {
    return StoreCategory(
      id: json['id'],
      name: json['name'],
      image: json['image']?.toString(),
      isActive: json['is_active'] ?? true,
    );
  }
}