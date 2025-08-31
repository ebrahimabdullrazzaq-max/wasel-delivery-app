// pages/customer_home_page.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wasel/pages/CustomProductEntryPage.dart';
import 'package:wasel/pages/star_rating.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../models/store.dart';
import '../utils/cart_manager.dart';
import 'edit_account_page.dart';
import 'orders_page.dart';
import 'ordertrackingpage.dart';
import 'product_list_page.dart';
import '../providers/auth_provider.dart';
import 'account_management_page.dart';

class CustomerHomePage extends StatefulWidget {
  @override
  _CustomerHomePageState createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  List<Category> _categories = [];
  List<Product> _products = [];
  List<Store> _stores = [];
  List<Store> _filteredStores = [];
  List<Store> _favoriteStores = [];
  List<Store> _newStores = [];
  List<Store> _nearestStores = [];
  int? _selectedCategoryId;
  String _selectedCity = 'Dhamar';
  List<String> availableCities = ['Dhamar', 'Sana\'a', 'Taiz', 'Aden', 'Hodeidah'];
  final String baseUrl = 'http://192.168.43.181:8000';
  Map<int, int> _productQuantities = {};
  int _cartItemCount = 0;
  bool _isLoading = true;
  String _errorMessage = '';
  String _searchQuery = '';
  Position? _userPosition;
  Set<int> _favoriteStoreIds = {};

  Map<String, String> _categoryIcons = {
    'Restaurants': 'assets/icons/restaurant_icon_unselected.png',
    'Groceries': 'assets/icons/grocery_icon_unselected.png',
    'Pharmacies': 'assets/icons/pharmacy_icon_unselected.png',
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _loadFavorites();
    _getCurrentLocation();
  }

  Future<void> _loadInitialData() async {
    try {
      await Future.wait([
        fetchCategories(),
        fetchProducts(),
        _loadCartQuantities(),
      ]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load data';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('favoriteStoreIds');
    if (ids != null) {
      setState(() {
        _favoriteStoreIds = ids.map((id) => int.parse(id)).toSet();
      });
    }
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'favoriteStoreIds',
      _favoriteStoreIds.map((id) => id.toString()).toList(),
    );
  }

  Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _errorMessage = 'Location permission denied';
        });
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _errorMessage = 'Location permission permanently denied';
      });
      return false;
    }

    return true;
  }

  Future<void> _getCurrentLocation() async {
    bool hasPermission = await _checkLocationPermission();
    if (!hasPermission) return;

    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _userPosition = position;
        });
      }

      if (_selectedCategoryId != null) {
        await fetchStores(_selectedCategoryId!);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to get location';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> fetchCategories() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/categories'));
      final List<dynamic> data = json.decode(response.body);
      if (mounted) {
        setState(() {
          _categories = data.map((json) => Category.fromJson(json)).toList();
        });
      }
    } catch (e) {
      print('Error fetching categories: $e');
    }
  }

  Future<void> fetchProducts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/products'));
      final responseData = json.decode(response.body);
      final List<dynamic> data = responseData['products'];
      if (mounted) {
        setState(() {
          _products = data.map((json) => Product.fromJson(json)).toList();
        });
      }
    } catch (e) {
      print('Error fetching products: $e');
    }
  }

  Future<void> _loadCartQuantities() async {
    await CartManager.loadCart();
    final cart = CartManager.getCartItems();
    if (mounted) {
      setState(() {
        _productQuantities = {
          for (var item in cart) item['product'].id: item['quantity']
        };
        _cartItemCount = _productQuantities.values.fold(0, (a, b) => a + b);
      });
    }
  }

  Future<void> fetchStores(int categoryId) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _filteredStores = [];
      _favoriteStores = [];
      _newStores = [];
      _nearestStores = [];
    });

    double userLat = _userPosition?.latitude ?? 15.3694;
    double userLon = _userPosition?.longitude ?? 44.1910;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/stores/category/$categoryId'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(response.body);
        final List<dynamic> data = responseBody['stores'];

        final List<Store> allStores = data
            .where((json) {
              final address = json['address']?.toString().toLowerCase() ?? '';
              return address.contains(_selectedCity.toLowerCase());
            })
            .map((json) {
              final store = Store.fromJson(json);
              final distance = _calculateDistance(
                userLat, userLon,
                store.latitude, store.longitude,
              );
              return store.copyWith(distance: distance);
            })
            .toList();

        // ✅ Sort by rating first, then distance
        final sortedStores = List<Store>.from(allStores)
          ..sort((a, b) {
            if (b.averageRating != a.averageRating) {
              return b.averageRating.compareTo(a.averageRating);
            }
            return a.distance.compareTo(b.distance);
          });

        final nearestStores = sortedStores.where((s) => s.distance <= 30).toList();

        if (mounted) {
          setState(() {
            _stores = sortedStores;
            _filteredStores = sortedStores;
            _favoriteStores = sortedStores.where((s) => _favoriteStoreIds.contains(s.id)).toList();
            _newStores = sortedStores.where((s) => s.isNew).toList();
            _nearestStores = nearestStores;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load stores';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network error';
        });
      }
      print('Error fetching stores: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _selectCategory(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _stores.clear();
      _filteredStores.clear();
      _favoriteStores.clear();
      _newStores.clear();
      _nearestStores.clear();
      _errorMessage = '';
      _searchQuery = '';
    });

    if (categoryId != null) {
      fetchStores(categoryId);
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  void _trackLastOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final orderId = prefs.getInt('last_order_id');
    final token = prefs.getString('token');
    if (orderId != null && token != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderTrackingPage(orderId: orderId, token: token),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recent order found')),
      );
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      if (value.isEmpty) {
        _filteredStores = _stores;
      } else {
        final query = value.toLowerCase();
        _filteredStores = _stores.where((store) {
          final name = store.name.toLowerCase();
          final address = store.address.toLowerCase();
          return name.contains(query) || address.contains(query);
        }).toList();
      }
    });
  }

  Widget _getCategoryIcon(String categoryName, bool isSelected) {
    final unselectedIconPath = _categoryIcons[categoryName];
    final selectedIconPath = unselectedIconPath?.replaceFirst('_unselected', '_selected');
    return Image.asset(
      isSelected
          ? (selectedIconPath ?? unselectedIconPath ?? 'assets/icons/default.png')
          : (unselectedIconPath ?? 'assets/icons/default.png'),
      width: 30,
      height: 30,
    );
  }

  void toggleFavorite(Store store) {
    setState(() {
      if (_favoriteStoreIds.contains(store.id)) {
        _favoriteStoreIds.remove(store.id);
      } else {
        _favoriteStoreIds.add(store.id);
      }
    });
    _saveFavorites();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await fetchCategories();
      if (_selectedCategoryId != null) {
        await fetchStores(_selectedCategoryId!);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to refresh data';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _logout(AuthProvider authProvider) async {
    await authProvider.logout();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _openEditAccount() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => EditAccountPage(user: user)),
      ).then((_) {
        if (_selectedCategoryId != null) {
          fetchStores(_selectedCategoryId!);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final bool isLoggedIn = authProvider.isAuthenticated;

    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: Row(
          children: [
            Image.asset(
              'assets/icons/order_tracking_icon.png',
              width: 28,
              height: 28,
            ),
            SizedBox(width: 8),
            Text(
              "Wasel",
              style: TextStyle(
                color: Color(0xFF0D47A1),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Color(0xFF0D47A1)),
            onPressed: _getCurrentLocation,
          ),
          IconButton(
            icon: Image.asset(
              'assets/icons/order_tracking_icon.png',
              width: 24,
              height: 24,
            ),
            onPressed: _trackLastOrder,
          ),
          Stack(
            children: [
              if (_cartItemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Color(0xFFC62828),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _cartItemCount.toString(),
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
          GestureDetector(
            onTap: () {
              if (!isLoggedIn) {
                Navigator.pushNamed(context, '/login');
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AccountManagementPage(
                      initialCity: _selectedCity,
                      onCityChanged: (newCity) {
                        setState(() {
                          _selectedCity = newCity;
                        });
                        if (_selectedCategoryId != null) {
                          fetchStores(_selectedCategoryId!);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Location updated to $newCity')),
                        );
                      },
                    ),
                  ),
                );
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: CircleAvatar(
                backgroundColor: Color(0xFF0D47A1),
                radius: 16,
                child: Icon(Icons.person, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
            : Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: Color(0xFF0D47A1)),
                        SizedBox(width: 8),
                        Text('City:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedCity,
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Search stores...",
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF0D47A1), width: 2),
                        ),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  Container(
                    height: 60,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = _selectedCategoryId == category.id;
                        return Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () => _selectCategory(isSelected ? null : category.id),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? Color(0xFF0D47A1) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? Color(0xFF0D47A1) : Colors.grey,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  _getCategoryIcon(category.name, isSelected),
                                  SizedBox(width: 8),
                                  Text(
                                    category.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isSelected ? Colors.white : Colors.black,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: _selectedCategoryId == null
                        ? Center(child: Text('Select a category'))
                        : _errorMessage.isNotEmpty
                            ? Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red)))
                            : _filteredStores.isEmpty
                                ? Center(child: Text('No stores found'))
                                : DefaultTabController(
                                    length: 4,
                                    child: Column(
                                      children: [
                                        TabBar(
                                          tabs: [
                                            Tab(text: 'Favorites'),
                                            Tab(text: 'New'),
                                            Tab(text: 'Nearest'),
                                            Tab(text: 'All'),
                                          ],
                                          labelColor: Color(0xFFC62828),
                                          unselectedLabelColor: Colors.grey,
                                          indicatorColor: Color(0xFFC62828),
                                        ),
                                        Expanded(
                                          child: TabBarView(
                                            children: [
                                              _buildStoreList(_favoriteStores),
                                              _buildStoreList(_newStores),
                                              _buildStoreList(_nearestStores),
                                              _buildStoreList(_filteredStores),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStoreList(List<Store> stores) {
    if (stores.isEmpty) {
      return Center(child: Text('No stores'));
    }

    return ListView.builder(
      itemCount: stores.length,
      itemBuilder: (context, index) {
        final store = stores[index];
        return _buildStoreCard(store);
      },
    );
  }

  Widget _buildStoreCard(Store store) {
    final isFavorite = _favoriteStoreIds.contains(store.id);
    final isTopRated = store.averageRating >= 4.5 && store.ratingCount >= 3;

    return GestureDetector(
      onTap: () {
        if (store.isOpen) {
          if (store.categoryId == 5) {
            // ✅ Grocery Store
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CustomProductEntryPage(
                  storeId: store.id,
                  storeName: store.name,
                ),
              ),
            );
          } else {
            // ✅ Normal Store
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductListPage(
                  storeId: store.id,
                  storeName: store.name,
                ),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Store is closed'),
            ),
          );
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16, left: 16, right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
          border: isTopRated ? Border.all(color: Colors.amber, width: 2.0) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: store.isOpen ? Colors.green.shade100 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            store.isOpen ? 'Open' : 'Closed',
                            style: TextStyle(
                              color: store.isOpen ? Colors.green.shade800 : Colors.grey.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 20,
                            color: isFavorite ? Color(0xFFC62828) : Color(0xFF757575),
                          ),
                          onPressed: () => toggleFavorite(store),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          store.address,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.grey),
                            SizedBox(width: 4),
                            Text(
                              '${store.distance.toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontSize: 12,
                                color: store.distance <= 30 ? Colors.green : Colors.grey,
                                fontWeight: store.distance <= 30 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: store.image.startsWith('http')
                              ? store.image
                              : '$baseUrl/storage/${store.image}',
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.grey[200]),
                          errorWidget: (context, url, error) => Icon(Icons.store, size: 40, color: Colors.grey),
                        ),
                      ),
                      SizedBox(height: 4),
                      StarRating(
                        rating: store.averageRating ?? 0.0,
                        filledColor: Colors.amber,
                        emptyColor: Colors.grey,
                        size: 14,
                      ),
                    ],
                  ),
                ],
              ),
              if (isTopRated)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.star, size: 12, color: Colors.white),
                        Text(
                          'Top',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}