import 'dart:convert';
import 'package:wasel/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, required this.quantity});

  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        'quantity': quantity,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(json['product']),
      quantity: json['quantity'] ?? 1,
    );
  }
}

class CartService {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final Map<int, CartItem> _cart = {}; // productId -> CartItem

  List<CartItem> get cartItems => _cart.values.toList();

  void addToCart(Product product, [int quantity = 1]) {
    if (_cart.containsKey(product.id)) {
      _cart[product.id]!.quantity += quantity;
    } else {
      _cart[product.id] = CartItem(product: product, quantity: quantity);
    }
    saveCart();
  }

  void removeFromCart(Product product) {
    _cart.remove(product.id);
    saveCart();
  }

  void clearCart() {
    _cart.clear();
    saveCart();
  }

  bool isInCart(Product product) {
    return _cart.containsKey(product.id);
  }

  int getQuantity(Product product) {
    return _cart[product.id]?.quantity ?? 0;
  }

  Future<void> saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = _cart.map((key, item) => MapEntry(
          key.toString(),
          item.toJson(),
        ));
    prefs.setString('cart', jsonEncode(cartJson));
  }

  Future<void> loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cartString = prefs.getString('cart');
    if (cartString != null) {
      final Map<String, dynamic> decoded = jsonDecode(cartString);
      _cart.clear();
      decoded.forEach((key, value) {
        _cart[int.parse(key)] = CartItem.fromJson(value);
      });
    }
  }

  void updateQuantity(int id, int i) {}
}
