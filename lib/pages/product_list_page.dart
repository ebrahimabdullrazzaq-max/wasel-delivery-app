// pages/product_list_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:wasel/models/product.dart';
import 'package:wasel/models/store_category.dart';
import 'package:wasel/models/store.dart';
import 'package:wasel/pages/orders_page.dart';
import 'package:http/http.dart' as http;
import 'package:wasel/utils/cart_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProductListPage extends StatefulWidget {
  final int storeId;
  final String storeName;
   final int categoryType; 

  const ProductListPage({
    Key? key,
    required this.storeId,
    required this.storeName,
     this.categoryType=3,
  }) : super(key: key);

  @override
  _ProductListPageState createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _loading = true;
  Map<int, int> _quantities = {};
  List<StoreCategory> _categories = [];
  int? _selectedCategoryId;
  Set<int> _favoriteProductIds = {};
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Store? _store;

  // Special ID for Favorites tab
  static const int FAVORITES_CATEGORY_ID = -1;

  // Map category names to icon paths
  Map<String, String> _categoryIcons = {
    'Pizza': 'assets/icons/pizza_icon_unselected.png',
    'Prost': 'assets/icons/prost_icon_unselected.png',
    'Burgers': 'assets/icons/burger_unselected.png',
    'Appetizers': 'assets/icons/tteokbokki_unselected.png',
  };

  @override
  void initState() {
    super.initState();
    _loadStore();
    _loadProducts();
    _loadStoreCategories();
    _loadCartQuantities();
    _loadFavorites();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStore() async {
    try {
      print('Loading store data for ID: ${widget.storeId}');
      final response = await http.get(
        Uri.parse('http://192.168.43.181:8000/api/stores/${widget.storeId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Store data received: $data');
        setState(() {
          _store = Store.fromJson(data);
          print('Store loaded: ${_store?.name}, isOpen: ${_store?.isOpen}');
        });
      } else {
        print('Failed to load store. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading store: $e');
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString('favorite_product_ids');
    if (saved != null) {
      final List<dynamic> list = jsonDecode(saved);
      setState(() {
        _favoriteProductIds = list.map((id) => id as int).toSet();
      });
    }
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'favorite_product_ids',
      jsonEncode(_favoriteProductIds.toList()),
    );
  }

  Future<void> _loadCartQuantities() async {
    await CartManager.loadCart();
    final cart = CartManager.getCartItems();
    setState(() {
      _quantities = {
        for (var item in cart) item['product'].id: item['quantity']
      };
    });
  }

  Future<void> _loadStoreCategories() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.43.181:8000/api/products/store/${widget.storeId}/categories'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('categories')) {
          final List<dynamic> categoryData = data['categories'];
          setState(() {
            _categories = categoryData.map((json) => StoreCategory.fromJson(json)).toList();
          });
        }
      }
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _loadProducts() async {
    try {
      List<Product> fetchedProducts = [];

      if (_selectedCategoryId == FAVORITES_CATEGORY_ID) {
        final allProducts = await _fetchAllProducts();
        fetchedProducts = allProducts.where((product) {
          return _favoriteProductIds.contains(product.id);
        }).toList();
      } else {
        String url = 'http://192.168.43.181:8000/api/products/store/${widget.storeId}';
        if (_selectedCategoryId != null) {
          url += '?category_id=$_selectedCategoryId';
        }

        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data.containsKey('products')) {
            final List<dynamic> productData = data['products'];
            fetchedProducts = productData.map((json) => Product.fromJson(json)).toList();
          }
        }
      }

      setState(() {
        _products = fetchedProducts;
        _filteredProducts = _searchQuery.isEmpty
            ? _products
            : _products.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
        _loading = false;
      });
    } catch (e) {
      print('Error loading products: $e');
      setState(() => _loading = false);
    }
  }

  Future<List<Product>> _fetchAllProducts() async {
    final response = await http.get(
      Uri.parse('http://192.168.43.181:8000/api/products/store/${widget.storeId}'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data.containsKey('products')) {
        final List<dynamic> productData = data['products'];
        return productData.map((json) => Product.fromJson(json)).toList();
      }
    }
    return [];
  }

  String _getImageUrl(Product product) {
    if (product.image == null || product.image.isEmpty) {
      return 'assets/images/placeholder.png';
    }
    if (product.image.startsWith('http')) {
      return product.image;
    }
    return 'http://192.168.43.181:8000/storage/${product.image}';
  }

  Widget _getCategoryIcon(String categoryName, bool isSelected) {
    final unselectedIconPath = _categoryIcons[categoryName];
    final selectedIconPath = unselectedIconPath?.replaceFirst('_unselected', '_selected');

    return Image.asset(
      isSelected
          ? (selectedIconPath ?? unselectedIconPath ?? 'assets/icons/restaurant_icon_unselected.png')
          : (unselectedIconPath ?? 'assets/icons/restaurant_icon_unselected.png'),
      width: 30,
      height: 30,
    );
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() {
      _searchQuery = query;
    });
    _filterProducts(query);
  }

  void _filterProducts(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredProducts = _products;
      });
    } else {
      setState(() {
        _filteredProducts = _products.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).toList();
      });
    }
  }

  void _addToCart(Product product) {
    CartManager.addToCart(product);
    _loadCartQuantities();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name} added to cart')),
    );
  }

  void _increaseQuantity(Product product) {
    CartManager.increaseQuantity(product.id);
    _loadCartQuantities();
  }

  void _decreaseQuantity(Product product) {
    CartManager.decreaseQuantity(product.id);
    if ((_quantities[product.id] ?? 1) <= 1) {
      CartManager.removeFromCart(product.id);
    }
    _loadCartQuantities();
  }

  void _toggleFavorite(Product product) {
    setState(() {
      if (_favoriteProductIds.contains(product.id)) {
        _favoriteProductIds.remove(product.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed from favorites')),
        );
      } else {
        _favoriteProductIds.add(product.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added to favorites')),
        );
      }
    });

    _saveFavorites();

    if (_selectedCategoryId == FAVORITES_CATEGORY_ID) {
      _loadProducts();
    }
  }

  void _selectCategory(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _searchController.clear();
      _searchQuery = '';
    });
    _loadProducts();
  }

  // ✅ Show Product Detail Modal
  void _showProductDetail(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        contentPadding: EdgeInsets.all(0),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image
              Stack(
                children: [
                  Container(
                    height: 300,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      image: DecorationImage(
                        image: NetworkImage(_getImageUrl(product)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // Close Button
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: Icon(Icons.close, color: Colors.red),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              // Price Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              // Add to Cart Button
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _addToCart(product);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFC62828),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text(
                  'Add to Cart',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              SizedBox(height: 16),
              // Product Name
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  product.name,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.storeName),
        backgroundColor: Color(0xFF0D47A1), // Navy Blue
        centerTitle: true,
        actions: [
        IconButton(
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
  icon: Badge(
    label: Text(
      _quantities.values.fold(0, (sum, qty) => sum + qty).toString(),
      style: TextStyle(fontSize: 10, color: Colors.white),
    ),
    backgroundColor: Colors.red,
    child: Icon(Icons.shopping_cart, color: Colors.white),
  ),
),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
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
      body: _loading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
          : Column(
              children: [
                // ✅ Animated Banner (Fixed)
               // ✅ WORKING ANIMATED BANNER - NO ERRORS
// ✅ STATIC BANNER - NO ANIMATION, NO ERRORS
Container(
  margin: EdgeInsets.only(top: 8),
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      // Open Badge
      Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 10, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'Open',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      SizedBox(width: 20),
      // Delivery Time
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

                // Categories Filter Bar
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Favorites Button
                        GestureDetector(
                          onTap: () => _selectCategory(FAVORITES_CATEGORY_ID),
                          child: Container(
                            margin: EdgeInsets.only(right: 8),
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _selectedCategoryId == FAVORITES_CATEGORY_ID
                                  ? Color(0xFFC62828) // Red
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.favorite,
                                  size: 24,
                                  color: _selectedCategoryId == FAVORITES_CATEGORY_ID
                                      ? Colors.white
                                      : Colors.red,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Favorites',
                                  style: TextStyle(
                                    color: _selectedCategoryId == FAVORITES_CATEGORY_ID
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Store Categories
                        ..._categories.map((category) {
                          final isSelected = _selectedCategoryId == category.id;
                          return GestureDetector(
                            onTap: () => _selectCategory(category.id),
                            child: Container(
                              margin: EdgeInsets.only(right: 8),
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? Color(0xFF0D47A1) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _getCategoryIcon(category.name, isSelected),
                                  SizedBox(width: 8),
                                  Text(
                                    category.name,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),

                // Products List
                Expanded(
                  child: _filteredProducts.isEmpty
                      ? Center(child: Text('No products found'))
                      : ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            final qty = _quantities[product.id] ?? 0;
                            final isFavorite = _favoriteProductIds.contains(product.id);

                            return Card(
                              margin: EdgeInsets.zero,
                              elevation: 2,
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                child: InkWell(
                                  onTap: () => _showProductDetail(product), // ✅ Added: Open popup
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Image
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: _getImageUrl(product),
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            color: Colors.grey[200],
                                            child: Icon(Icons.fastfood, color: Colors.grey),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              Icon(Icons.fastfood, color: Colors.grey),
                                        ),
                                      ),
                                      SizedBox(width: 16),

                                      // Product Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.name,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              '\$${product.price.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Favorite + Quantity
                                      Column(
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              isFavorite ? Icons.favorite : Icons.favorite_border,
                                              color: isFavorite ? Color(0xFFC62828) : Colors.grey,
                                            ),
                                            onPressed: () => _toggleFavorite(product),
                                          ),
                                          if (qty > 0)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: Icon(Icons.remove, size: 18),
                                                  onPressed: () => _decreaseQuantity(product),
                                                ),
                                                Text('$qty'),
                                                IconButton(
                                                  icon: Icon(Icons.add, size: 18),
                                                  onPressed: () => _increaseQuantity(product),
                                                ),
                                              ],
                                            )
                                          else
                                            ElevatedButton(
                                              onPressed: () => _addToCart(product),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Color(0xFFC62828),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                              ),
                                              child: Text(
                                                'Add',
                                                style: TextStyle(color: Colors.white),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
} 