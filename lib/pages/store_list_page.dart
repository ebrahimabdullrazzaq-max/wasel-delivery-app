import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:wasel/pages/product_list_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Store Model
class Store {
  final int id;
  final String name;
  final String image;
  final String address;
  final double latitude;
  final double longitude;

  Store({
    required this.id,
    required this.name,
    required this.image,
    required this.address,
    required this.latitude,
    required this.longitude, required phone,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'],
      name: json['name'],
      image: json['image'].startsWith('http')
          ? json['image']
          : 'http://192.168.43.181:8000/storage/${json['image']}',
      address: json['address'],
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      phone: json['phone'],
    );
  }
}

class StoreListPage extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const StoreListPage({
    Key? key,
    required this.categoryId,
    required this.categoryName,
  }) : super(key: key);

  @override
  _StoreListPageState createState() => _StoreListPageState();
}

class _StoreListPageState extends State<StoreListPage> {
  List<Store> _stores = [];
  bool _loading = true;
  String? _errorMessage;
  
  final String baseUrl = 'http://192.168.43.181:8000'; // ✅ Fixed: Add base URL

  @override
  void initState() {
    super.initState();
    fetchStores();
  }

  Future<void> fetchStores() async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/stores/category/${widget.categoryId}'),
    );

    if (response.statusCode == 200) {
      // ✅ Decode as Map first
      final Map<String, dynamic> responseBody = json.decode(response.body);

      // ✅ Extract the 'stores' list
      final List<dynamic> storesData = responseBody['stores'];

      setState(() {
        _stores = storesData.map((json) => Store.fromJson(json)).toList();
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
        _errorMessage = 'Failed to load stores: ${response.statusCode}';
      });
    }
  } catch (e) {
    setState(() {
      _loading = false;
      _errorMessage = 'Error: $e';
    });
    print('Error fetching stores: $e');
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        backgroundColor: Colors.green.shade700,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _stores.isEmpty
                  ? Center(child: Text('No stores available in this category'))
                  : GridView.builder(
                      padding: EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: _stores.length,
                      itemBuilder: (context, index) {
                        final store = _stores[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductListPage(
                                  storeId: store.id,
                                  storeName: store.name, 
                                ),
                              ),
                            );
                          },
                          child: Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(15),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: store.image,
                                    height: 100,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => 
                                      Image.asset('assets/images/placeholder.png', fit: BoxFit.cover),
                                    errorWidget: (context, url, error) => 
                                      Image.asset('assets/images/placeholder.png', fit: BoxFit.cover),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        store.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        store.address.length > 30
                                            ? '${store.address.substring(0, 30)}...'
                                            : store.address,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}