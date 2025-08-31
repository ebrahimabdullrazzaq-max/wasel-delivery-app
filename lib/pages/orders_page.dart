// pages/OrderPage.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wasel/models/product.dart';
import 'package:wasel/pages/OrderTrackingPage.dart';
import 'package:wasel/utils/cart_manager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:wasel/providers/auth_provider.dart';
import 'package:wasel/screens/location_picker_screen.dart';
import 'package:wasel/screens/login_page.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({
    Key? key,
    required this.allProducts,
    required this.onOrderCanceled,
  }) : super(key: key);

  final List<Product> allProducts;
  final VoidCallback onOrderCanceled;

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TextEditingController _phoneController = TextEditingController();
  TextEditingController _notesController = TextEditingController();
  late ConfettiController _confettiController;

  List<Map<String, dynamic>> cartItems = [];
  bool _isLoading = false;
  LatLng? _deliveryLocation;
  String? _deliveryAddress;
  String? _errorMessage;
  bool _locationPermissionChecked = false;

  // Payment & Delivery
  String _paymentMethod = 'cash_on_delivery';
  double _deliveryFee = 0.0;
  List<String> _savedAddresses = [];
  String? _selectedAddress;
  Map<int, String> _itemSpecialInstructions = {};

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _loadCart();
    _loadUserLocation();
    _checkLocationPermissions();
    _loadSavedAddresses();
    _phoneController.text = '+967 ';
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedAddresses = prefs.getStringList('saved_addresses') ?? [];
      if (_savedAddresses.isNotEmpty) {
        _selectedAddress = _savedAddresses.first;
      }
    });
  }

  Future<void> _saveAddress(String address) async {
    final prefs = await SharedPreferences.getInstance();
    if (!_savedAddresses.contains(address)) {
      _savedAddresses.add(address);
      await prefs.setStringList('saved_addresses', _savedAddresses);
    }
  }

  Future<void> _checkLocationPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    setState(() => _locationPermissionChecked = true);
  }

  Future<void> _showLocationServiceDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Services Disabled'),
          content: const Text('Please enable location services to select a delivery location'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openLocationSettings();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLocationPermissionDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text('This app needs location permissions to select delivery locations'),
          actions: <Widget>[
            TextButton(
              child: const Text('Deny'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Grant Permission'),
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadUserLocation() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated && authProvider.user != null) {
      final user = authProvider.user!;
      if (user['latitude'] != null && user['longitude'] != null) {
        setState(() {
          _deliveryLocation = LatLng(
            (user['latitude'] as num).toDouble(),
            (user['longitude'] as num).toDouble(),
          );
          _deliveryAddress = user['address'] as String?;
          if (_deliveryAddress != null) {
            _saveAddress(_deliveryAddress!);
          }
        });
      }
    }
  }

  Future<void> _loadCart() async {
    await CartManager.loadCart();
    setState(() {
      cartItems = CartManager.getCartItems();
    });
  }

  void _updateQuantity(int productId, bool increase) {
    if (increase) {
      CartManager.increaseQuantity(productId);
    } else {
      CartManager.decreaseQuantity(productId);
    }
    _loadCart();
    widget.onOrderCanceled();
  }

  void _clearCart() {
    CartManager.clearCart();
    _loadCart();
    widget.onOrderCanceled();
  }

  double getSubtotal() {
    return cartItems.fold(0, (total, item) {
      final product = item['product'] as Product;
      final quantity = item['quantity'] as int;
      return total + (product.price * quantity);
    });
  }

  double getTotal() {
    return getSubtotal() + _deliveryFee;
  }

  Future<void> _selectLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _showLocationServiceDialog();
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _showLocationPermissionDialog();
        return;
      }
      final location = await Navigator.push<LatLng?>(
        context,
        MaterialPageRoute(
          builder: (context) => LocationPickerScreen(
            initialLocation: _deliveryLocation,
            onLocationSelected: (location) {},
          ),
        ),
      );
      if (location != null) {
        await _updateLocationInfo(location);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to select location: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location error: ${e.toString()}')),
      );
    }
  }

  Future<void> _updateLocationInfo(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      String address = 'Location: ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        address = [
          place.street,
          place.locality,
          place.postalCode,
        ].where((part) => part != null && part.isNotEmpty).join(', ');
      }
      setState(() {
        _deliveryLocation = location;
        _deliveryAddress = address;
        _selectedAddress = address;
        _saveAddress(address);
      });

      // ✅ Update delivery fee based on distance
      await _updateDeliveryFee();
    } catch (e) {
      setState(() {
        _deliveryLocation = location;
        _deliveryAddress = 'Location: ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
        _selectedAddress = _deliveryAddress;
        _saveAddress(_deliveryAddress!);
      });
    }
  }

  Future<void> _updateDeliveryFee() async {
    if (cartItems.isEmpty || _deliveryLocation == null) return;

    final firstProduct = cartItems.first['product'] as Product;
    final int? storeId = firstProduct.storeId;
    if (storeId == null) return;

    final storeLocation = await _fetchStoreLocation(storeId);
    if (storeLocation == null) return;

    final distance = _calculateDistance(
      _deliveryLocation!.latitude,
      _deliveryLocation!.longitude,
      storeLocation['latitude'] as double,
      storeLocation['longitude'] as double,
    );

    setState(() {
      // Example distance fee logic: base 5 + 0.5 per km
      _deliveryFee = 0 + distance * 0.4;
      if (_deliveryFee > 20) _deliveryFee = 20; // Max delivery fee cap
    });
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (pi / 180);

  // ✅ Fetch store location from API
  Future<Map<String, dynamic>?> _fetchStoreLocation(int storeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('http://192.168.43.181:8000/api/stores/$storeId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final double? lat = double.tryParse(data['latitude'].toString());
        final double? lng = double.tryParse(data['longitude'].toString());
        if (lat == null || lng == null) return null;
        return {'latitude': lat, 'longitude': lng};
      }
    } catch (e) {
      print('Exception in _fetchStoreLocation: $e');
    }
    return null;
  }

  // Rest of your methods remain unchanged: _showOrderConfirmation, confirmOrder, build widgets, etc.
  // Ensure you call _updateDeliveryFee() after selecting location or loading user location.



  Future<void> confirmOrder(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must login to confirm your order')),
      );
      await Future.delayed(const Duration(seconds: 1));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
      return;
    }

    if (_deliveryLocation == null || _deliveryAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery location')),
      );
      return;
    }

    final cartItems = CartManager.getCartItems();
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty')),
      );
      return;
    }

    // ✅ Get storeId from first product in cart
    final firstProduct = cartItems.first['product'] as Product;
    final int? storeId = firstProduct.storeId;

    if (storeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot place order: product store information is missing.')),
      );
      return;
    }

    // ✅ Fetch store location
    final storeLocation = await _fetchStoreLocation(storeId);
    if (storeLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get restaurant location. Try again later.')),
      );
      return;
    }

    // ✅ Calculate distance
    final userLat = _deliveryLocation!.latitude;
    final userLon = _deliveryLocation!.longitude;
    final storeLat = storeLocation['latitude'] as double;
    final storeLon = storeLocation['longitude'] as double;

    final distance = _calculateDistance(userLat, userLon, storeLat, storeLon);

    if (distance > 18.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This restaurant is too far. Delivery is only available within 18 km.\nDistance: ${distance.toStringAsFixed(1)} km',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ All checks passed — proceed with order
  final List<Map<String, dynamic>> items = cartItems.map((item) {
  final product = item['product'] as Product;
  return {
    'product_id': product.id > 0 ? product.id : null,
    'custom_name': product.id <= 0 ? product.name : null,
    'quantity': item['quantity'],
    'special_instructions': _itemSpecialInstructions[product.id],
    'price': product.price,
  };
}).toList();
    final response = await http.post(
      Uri.parse('http://192.168.43.181:8000/api/customer/orders'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'address': _selectedAddress ?? _deliveryAddress!,
        'latitude': _deliveryLocation!.latitude,
        'longitude': _deliveryLocation!.longitude,
        'items': items,
        'notes': _notesController.text,
        'payment_method': _paymentMethod,
        'delivery_fee': _deliveryFee,
        'phone': _phoneController.text.trim(),
        'store_id': storeId,
        'subtotal': getSubtotal(),
        'total': getTotal(),
      }),
    );

   if (response.statusCode == 200 || response.statusCode == 201) {
  final responseData = jsonDecode(response.body);
  final orderId = responseData['order']?['id'] ?? responseData['id'];

  if (orderId != null) {
    // ✅ Save last order ID
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_order_id', orderId);
    await prefs.setString('token', token);

    // ✅ Clear cart
    CartManager.clearCart();
    _confettiController.play();

    // ✅ Show success
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Order submitted successfully!')),
    );

    await Future.delayed(const Duration(seconds: 1));

    // ✅ Go to tracking
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OrderTrackingPage(orderId: orderId, token: token),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('❌ Unexpected server response.')),
    );
  }
} else {
  final errorData = jsonDecode(response.body);
  final message = errorData['message'] ?? 'Failed to submit order';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('❌ Error: $message')),
  );
}
  }

  Widget _buildDeliverySection() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Delivery Address', Icons.location_on),
              const SizedBox(height: 16),
              if (_savedAddresses.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedAddress,
                  items: _savedAddresses.map((address) => DropdownMenuItem(
                    value: address,
                    child: Text(address, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedAddress = value),
                  decoration: _inputDecoration('Select saved address'),
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                )
              else
                Text(
                  _deliveryAddress ?? 'No address selected',
                  style: TextStyle(
                    fontSize: 14,
                    color: _deliveryLocation == null ? Colors.red : Colors.grey[600],
                  ),
                ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.edit_location_alt, size: 18),
                  label: const Text('Change Location', style: TextStyle(fontSize: 13)),
                  onPressed: _selectLocation,
                  style: TextButton.styleFrom(
                    foregroundColor: Color(0xFF0D47A1),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Phone Number
              TextFormField(
                controller: _phoneController,
                decoration: _inputDecoration(
                  'Phone Number',
                  prefixIcon: Icons.phone,
                  hintText: '+967 771 234 567',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Phone number is required';
                  if (!value.startsWith('+967')) return 'Must start with +967';
                  final digits = value.replaceAll(RegExp(r'[^\d]'), '');
                  if (digits.length < 9) return 'Enter a valid Yemeni number';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Color(0xFF0D47A1), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D47A1),
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label,
      {IconData? prefixIcon, String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 18, color: Color(0xFF0D47A1))
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Color(0xFF0D47A1), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _buildOrderNotesSection() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Order Notes', Icons.note),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: _inputDecoration(
                'Special instructions (e.g., no onions)',
                hintText: 'Any special requests...',
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Payment Method', Icons.payment),
            const SizedBox(height: 16),
            RadioListTile(
              value: 'cash_on_delivery',
              groupValue: _paymentMethod,
              title: const Text('Cash on Delivery'),
              subtitle: const Text('Pay when delivered'),
              onChanged: (value) => setState(() => _paymentMethod = value.toString()),
            ),
            RadioListTile(
              value: 'balance_payment',
              groupValue: _paymentMethod,
              title: const Text('Pay from Balance'),
              onChanged: (value) => setState(() => _paymentMethod = value.toString()),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('Electronic Wallets'),
              children: [
                _walletOption('Jib Wallet', 'assets/icons/jib.png', 'jib_wallet'),
                _walletOption('Jawaly', 'assets/icons/jawaly.png', 'jawaly'),
                _walletOption('Al-Karami Bank', 'assets/icons/islamic_bank.png', 'islamic_bank'),
                _walletOption('ONE Kash', 'assets/icons/one_kash.png', 'one_kash'),
                _walletOption('Kash Pay', 'assets/icons/kash_pay.png', 'kash_pay'),
                _walletOption('Flousak', 'assets/icons/flousak.png', 'flousak'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _walletOption(String name, String iconPath, String value) {
    return RadioListTile(
      value: value,
      groupValue: _paymentMethod,
      title: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Image.asset(
              iconPath,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.warning, color: Colors.red, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Text(name),
        ],
      ),
      onChanged: (v) => setState(() => _paymentMethod = v.toString()),
    );
  }

  Widget _buildOrderItemsSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Items',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF0D47A1),
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 12),
            ...cartItems.map((item) {
              final product = item['product'] as Product;
              final quantity = item['quantity'] as int;
              final imageUrl = product.image.startsWith('http')
                  ? product.image
                  : 'http://192.168.43.181:8000/storage/${product.image}';
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) => Container(color: Colors.grey[200]),
                    errorWidget: (ctx, url, err) => const Icon(Icons.fastfood),
                  ),
                ),
                title: Text(product.name),
                subtitle: Text('\$${product.price.toStringAsFixed(2)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: () => _updateQuantity(product.id, false),
                    ),
                    Text(quantity.toString()),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: () => _updateQuantity(product.id, true),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummarySection() {
    final subtotal = getSubtotal();
    final total = getTotal();
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            _buildSummaryRow('Subtotal', subtotal),
            const SizedBox(height: 8),
            _buildSummaryRow('Delivery Fee', _deliveryFee),
            const Divider(height: 24, thickness: 1),
            _buildSummaryRow('Total', total, isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Colors.black : Colors.grey[700],
              fontFamily: 'Cairo',
            ),
          ),
          const Spacer(),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Color(0xFFC62828) : Colors.black,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Color(0xFF0D47A1),
                side: BorderSide(color: Color(0xFF0D47A1), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Edit Cart', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _showOrderConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0D47A1),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              child: const Text('Place Order', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCancelDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Cancel Order',
          style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              _clearCart();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order canceled')),
              );
            },
            child: Text('Yes', style: TextStyle(color: Color(0xFFC62828))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Checkout',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        backgroundColor: Color(0xFF0D47A1), // Navy Blue
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        centerTitle: true,
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.white),
              onPressed: () => _showCancelDialog(),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (!_locationPermissionChecked)
            const Center(child: CircularProgressIndicator())
          else if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (cartItems.isEmpty)
            const Center(child: Text('Your cart is empty'))
          else
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildDeliverySection(),
                        _buildOrderNotesSection(),
                        _buildPaymentSection(),
                        const SizedBox(height: 12),
                        _buildOrderItemsSection(),
                        const SizedBox(height: 12),
                        _buildOrderSummarySection(),
                      ],
                    ),
                  ),
                ),
                _buildActionButtons(),
              ],
            ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Color(0xFF0D47A1), Colors.white, Color(0xFFC62828)],
            ),
          ),
        ],
      ),
    );
  }

Future<void> _showOrderConfirmation() async {
  if (!_formKey.currentState!.validate()) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please fix the errors before placing the order.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        'Confirm Order',
        style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Please review your order:'),
          const SizedBox(height: 10),
          Text('Delivery to: ${_selectedAddress ?? _deliveryAddress}'),
          Text('Phone: ${_phoneController.text.trim()}'),
          Text('Payment method: $_paymentMethod'),
          const SizedBox(height: 10),
          Text('Total: \$${getTotal().toStringAsFixed(2)}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF0D47A1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Confirm', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await confirmOrder(context);
  }
}

  
}