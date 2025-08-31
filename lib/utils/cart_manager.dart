import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

class CartManager {
  static List<Map<String, dynamic>> _cart = [];

  /// Add product to cart (per city)
  static Future<void> addToCart(Product product) async {
    final prefs = await SharedPreferences.getInstance();
    final currentCity = prefs.getString('selected_city') ?? 'Dhamar';

    // Load all carts (per city map)
    final allCarts = await _loadAllCarts();

    List<Map<String, dynamic>> cityCart =
        (allCarts[currentCity] as List<dynamic>? ?? [])
            .map<Map<String, dynamic>>((item) {
      final prod = Product.fromJson(item['product']);
      return {
        'product': prod,
        'quantity': item['quantity'],
        'city': currentCity,
      };
    }).toList();

    int index = cityCart.indexWhere((item) => item['product'].id == product.id);
    if (index != -1) {
      cityCart[index]['quantity'] += 1;
    } else {
      cityCart.add({
        'product': product,
        'quantity': 1,
        'city': currentCity,
      });
    }

    // Save back
    allCarts[currentCity] = _encodeCityCart(cityCart);
    await prefs.setString('carts', jsonEncode(allCarts));

    _cart = cityCart;
  }

  static Future<void> increaseQuantity(int productId) async {
    final item = getCartItem(productId);
    if (item != null) {
      item['quantity'] += 1;
      await _saveCurrentCityCart();
    }
  }

  static Future<void> decreaseQuantity(int productId) async {
    final item = getCartItem(productId);
    if (item != null) {
      if (item['quantity'] > 1) {
        item['quantity'] -= 1;
      } else {
        _cart.removeWhere((x) => x['product'].id == productId);
      }
      await _saveCurrentCityCart();
    }
  }

  static Future<void> removeFromCart(int productId) async {
    _cart.removeWhere((item) => item['product'].id == productId);
    await _saveCurrentCityCart();
  }

  static List<Map<String, dynamic>> getCartItems() {
    return List<Map<String, dynamic>>.from(_cart);
  }

  static Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCity = prefs.getString('selected_city') ?? 'Dhamar';

    final allCarts = await _loadAllCarts();
    allCarts[currentCity] = [];
    await prefs.setString('carts', jsonEncode(allCarts));

    _cart.clear();
  }

  static int getTotalItems() {
    return _cart.fold(0, (sum, item) => sum + (item['quantity'] as int));
  }

  static double getTotalPrice() {
    return _cart.fold(0.0, (double sum, item) {
      final product = item['product'] as Product;
      final quantity = item['quantity'] as int;
      return sum + (product.price * quantity);
    });
  }

  static Future<void> loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCity = prefs.getString('selected_city') ?? 'Dhamar';

    final allCarts = await _loadAllCarts();
    final cityCart = allCarts[currentCity] as List<dynamic>? ?? [];

    _cart = cityCart.map<Map<String, dynamic>>((item) {
      final prod = Product.fromJson(item['product']);
      return {
        'product': prod,
        'quantity': item['quantity'],
        'city': currentCity,
      };
    }).toList();
  }

  static Map<String, dynamic>? getCartItem(int productId) {
    try {
      return _cart.firstWhere(
        (item) => item['product'] != null && item['product'].id == productId,
      );
    } catch (e) {
      return null;
    }
  }

  static int getQuantity(int productId) {
    final item = getCartItem(productId);
    return item?['quantity'] ?? 0;
  }

  // ---------------- Helpers ----------------

  static Future<Map<String, dynamic>> _loadAllCarts() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('carts');
    if (data != null) {
      try {
        return jsonDecode(data);
      } catch (e) {
        debugPrint("Error decoding carts: $e");
      }
    }
    return {};
  }

  static Future<void> _saveCurrentCityCart() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCity = prefs.getString('selected_city') ?? 'Dhamar';
    final allCarts = await _loadAllCarts();
    allCarts[currentCity] = _encodeCityCart(_cart);
    await prefs.setString('carts', jsonEncode(allCarts));
  }

  static List<Map<String, dynamic>> _encodeCityCart(
      List<Map<String, dynamic>> cart) {
    return cart.map((item) {
      final Product product = item['product'];
      return {
        'product': {
          'id': product.id,
          'name': product.name,
          'price': product.price,
          'image': product.image,
          'description': product.description,
          'category_id': product.categoryId,
          'store_id': product.storeId,
        },
        'quantity': item['quantity'],
      };
    }).toList();
  }

  static void addSpecialInstructions(int id, String text) {}
}
