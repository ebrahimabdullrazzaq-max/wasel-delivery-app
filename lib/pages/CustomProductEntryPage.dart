// pages/custom_product_entry_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:wasel/models/product.dart';
import 'package:wasel/pages/orders_page.dart';
import 'package:wasel/utils/cart_manager.dart';
import 'package:http/http.dart' as http;

class CustomProductEntryPage extends StatefulWidget {
  final int storeId;
  final String storeName;

  const CustomProductEntryPage({
    Key? key,
    required this.storeId,
    required this.storeName,
  }) : super(key: key);

  @override
  _CustomProductEntryPageState createState() => _CustomProductEntryPageState();
}

class _CustomProductEntryPageState extends State<CustomProductEntryPage> {
  TextEditingController _nameController = TextEditingController();
  TextEditingController _descriptionController = TextEditingController();
  int _quantity = 1;
  bool _isLoading = false;
  String? _error;
  
Future<void> _addToCart() async {
  
  if (_nameController.text.isEmpty) {
    setState(() {
      _error = 'Please enter product name';
    });
    return;
  }

  setState(() {
    _isLoading = true;
    _error = null;
  });

  // ✅ Create a fake product with storeId
  final groceryProduct = Product(
    id: -1 * DateTime.now().millisecondsSinceEpoch,
    name: _nameController.text,
    price: 0.0,
    image: '',
    categoryId: 5,
    storeId: widget.storeId, // ✅ Attach storeId from the store page
  );

  // ✅ Add to cart
  CartManager.addToCart(groceryProduct);
  CartManager.addSpecialInstructions(groceryProduct.id, _descriptionController.text);

  if (mounted) {
    setState(() {
      _isLoading = false;
    });
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Added to cart')),
  );

  _nameController.clear();
  _descriptionController.clear();
  _quantity = 1;
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.storeName),
        backgroundColor: Color(0xFF0D47A1), // Navy Blue
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderPage(
                    allProducts: [],
                    onOrderCanceled: () {},
                  ),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: Icon(Icons.search, color: Colors.white),
                filled: true,
                fillColor: Color(0xFF0D47A1).withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                hintStyle: TextStyle(color: Colors.white70),
              ),
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Store Open & Delivery Time Banner
            Container(
              margin: EdgeInsets.only(top: 8, bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.orange.shade200, width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      'Open',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Delivery takes 40 - 60 minutes',
                          style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.access_time_filled, size: 22, color: Colors.orange),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Product Entry Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error Message
                    if (_error != null)
                      Container(
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Color(0xFFC62828).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Color(0xFFC62828), width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Color(0xFFC62828), size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(color: Color(0xFFC62828), fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Quantity Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove, color: Color(0xFFC62828)),
                          onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text('$_quantity', style: TextStyle(fontSize: 16)),
                        ),
                        IconButton(
                          icon: Icon(Icons.add, color: Color(0xFFC62828)),
                          onPressed: () => setState(() => _quantity++),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // Product Name Field
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Enter product name or description...',
                        hintText: 'e.g., Rice, Sugar, Beans...',
                        labelStyle: TextStyle(color: Color(0xFF0D47A1)),
                        prefixIcon: Icon(Icons.fastfood, color: Color(0xFF0D47A1)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                      maxLines: 1,
                    ),
                    SizedBox(height: 16),

                    // Description Field (Optional)
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Additional description (optional)',
                        hintText: 'e.g., Organic, no preservatives...',
                        labelStyle: TextStyle(color: Color(0xFF0D47A1)),
                        prefixIcon: Icon(Icons.description, color: Color(0xFF0D47A1)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                      maxLines: 2,
                    ),
                    SizedBox(height: 24),

                    // Add to Cart Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _addToCart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFC62828), // Red
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Add to Cart',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // View Invoice Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderPage(
                        allProducts: [],
                        onOrderCanceled: () {},
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0D47A1), // Navy Blue
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'View Invoice',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}