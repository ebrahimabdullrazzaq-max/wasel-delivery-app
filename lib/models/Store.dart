// models/store.dart
import 'dart:math';

class Store {
  final int id;
  final String name;
  final String image;
  final String address;
  final double latitude;
  final double longitude;
  final double distance;
  final bool isFavorite;
  final bool isNew;
  final int categoryId;

  // Opening hours
  final int openingHour;
  final int openingMinute;
  final int closingHour;
  final int closingMinute;

  // Delivery time
  final int deliveryTimeMin;
  final int deliveryTimeMax;

  // Rating
  final double averageRating;
  final int ratingCount;

  // Store info
  final String phone;
  final bool isActive;

  static const int defaultCategoryId = 3;

  Store({
    required this.categoryId,
    required this.id,
    required this.name,
    required this.image,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.distance = 0.0,
    this.isFavorite = false,
    this.isNew = false,
    this.openingHour = 7,
    this.openingMinute = 30,
    this.closingHour = 23,
    this.closingMinute = 0,
    this.deliveryTimeMin = 30,
    this.deliveryTimeMax = 60,
    this.averageRating = 0.0,
    this.ratingCount = 0,
    required this.phone,
    required this.isActive,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    // Debug: Print raw JSON
    print('Raw store JSON: $json');

    return Store(
      categoryId: _parseInt(json['category_id']) ?? defaultCategoryId,
      id: _parseInt(json['id']) ?? -1,
      name: json['name'] as String? ?? 'Unknown Store',
      image: json['image'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      phone: json['phone'] as String? ?? '',
      isActive: _parseBool(json['is_active']) ?? true,
      isFavorite: _parseBool(json['is_favorite']) ?? false,
      isNew: _parseBool(json['is_new']) ?? false,
      openingHour: _parseInt(json['opening_hour']) ?? 7,
      openingMinute: _parseInt(json['opening_minute']) ?? 0,
      closingHour: _parseInt(json['closing_hour']) ?? 23,
      closingMinute: _parseInt(json['closing_minute']) ?? 0,
      deliveryTimeMin: _parseInt(json['delivery_time_min']) ?? 30,
      deliveryTimeMax: _parseInt(json['delivery_time_max']) ?? 60,
      averageRating: _parseDouble(json['average_rating']) ?? 0.0,
      ratingCount: _parseInt(json['rating_count']) ?? 0,
      distance: _parseDouble(json['distance']) ?? 0.0,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } on FormatException {
        return 0.0;
      }
    }
    return 0.0;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      try {
        return int.parse(value);
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  static bool? _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) {
      return ['true', '1', 'yes'].contains(value.toLowerCase());
    }
    if (value is int) return value == 1;
    return false;
  }

  Store copyWith({
    double? distance,
    bool? isFavorite,
    bool? isNew,
    double? averageRating,
    int? ratingCount,
    int? deliveryTimeMin,
    int? deliveryTimeMax,
    int? categoryId,
    String? phone,
    bool? isActive,
  }) {
    return Store(
      categoryId: categoryId ?? this.categoryId,
      id: id,
      name: name,
      image: image,
      address: address,
      latitude: latitude,
      longitude: longitude,
      distance: distance ?? this.distance,
      isFavorite: isFavorite ?? this.isFavorite,
      isNew: isNew ?? this.isNew,
      openingHour: openingHour,
      openingMinute: openingMinute,
      closingHour: closingHour,
      closingMinute: closingMinute,
      deliveryTimeMin: deliveryTimeMin ?? this.deliveryTimeMin,
      deliveryTimeMax: deliveryTimeMax ?? this.deliveryTimeMax,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
    );
  }

  bool get isOpen {
    final now = DateTime.now();
    final openTime = DateTime(now.year, now.month, now.day, openingHour, openingMinute);
    final closeTime = DateTime(now.year, now.month, now.day, closingHour, closingMinute);

    // Handle overnight stores (e.g., 11 PM to 2 AM)
    if (closeTime.isBefore(openTime)) {
      return now.isAfter(openTime) || now.isBefore(closeTime);
    }

    return now.isAfter(openTime) && now.isBefore(closeTime);
  }
}