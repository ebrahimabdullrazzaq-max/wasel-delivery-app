// pages/my_orders_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'ordertrackingpage.dart';

class MyOrdersPage extends StatefulWidget {
  final String currentCity;

  MyOrdersPage({required this.currentCity}); // Pass current city here

  @override
  _MyOrdersPageState createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        setState(() {
          error = 'Not logged in';
          isLoading = false;
        });
        return;
      }

      final url = Uri.parse('http://192.168.43.181:8000/api/customer/orders');
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic>? ordersData = data['orders'];

        final filteredOrders = ordersData?.where((order) {
          final storeAddress = order['store']?['address']?.toString().toLowerCase() ?? '';
          return storeAddress.contains(widget.currentCity.toLowerCase());
        }).toList() ?? [];

        setState(() {
          orders = List<Map<String, dynamic>>.from(filteredOrders);
          isLoading = false;
        });
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          error = data['message'] ?? 'Failed to load orders';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Network error. Please check your connection.';
        isLoading = false;
      });
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'on_the_way':
        return Colors.blue;
      case 'preparing':
        return Colors.orange;
      case 'under_review':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final createdAt = order['created_at'];
    final date = createdAt != null ? DateTime.tryParse(createdAt) ?? DateTime.now() : DateTime.now();
    final formattedDate = DateFormat('dd MMM yyyy').format(date);
    final formattedTime = DateFormat('hh:mm a').format(date);

    final storeName = order['store']?['name'] ?? 'Unknown Store';
    final storeAddress = order['store']?['address'] ?? 'Unknown Address';
    final total = double.tryParse(order['total'].toString()) ?? 0.0;
    final status = order['status']?.toString() ?? 'pending';
    final orderId = order['id'];

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderTrackingPage(
                orderId: orderId,
                token: Provider.of<AuthProvider>(context, listen: false).token!,
              ),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #$orderId',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D47A1)),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(color: getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              // Store Info
              Row(
                children: [
                  Icon(Icons.store, size: 18, color: Color(0xFF0D47A1)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(storeName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(storeAddress, style: TextStyle(color: Colors.grey[600], fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              // Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.fastfood, size: 18, color: Colors.orange),
                      SizedBox(width: 4),
                      Text('${order['order_items'].length} Items', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                    ],
                  ),
                  Text('\$${total.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFC62828))),
                ],
              ),
              SizedBox(height: 8),
              // Date & Time
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(formattedDate, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  SizedBox(width: 16),
                  Icon(Icons.access_time, size: 14, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(formattedTime, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentCity = widget.currentCity;

    return Scaffold(
      appBar: AppBar(
        title: Text('My Orders'),
        backgroundColor: Color(0xFF0D47A1),
        centerTitle: true,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: fetchOrders),
        ],
      ),
      body: Column(
        children: [
          // City display
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Icon(Icons.location_on, color: Color(0xFF0D47A1)),
                SizedBox(width: 8),
                Text('Location:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                SizedBox(width: 8),
                Text(currentCity, style: TextStyle(fontSize: 14, color: Colors.black87)),
              ],
            ),
          ),
          SizedBox(height: 8),
          // Orders List
          Expanded(
            child: RefreshIndicator(
              onRefresh: fetchOrders,
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
                  : error != null
                      ? Center(child: Text(error!, style: TextStyle(color: Colors.red)))
                      : orders.isEmpty
                          ? Center(child: Text('No orders found in $currentCity'))
                          : ListView.builder(
                              itemCount: orders.length,
                              itemBuilder: (context, index) => _buildOrderCard(orders[index]),
                            ),
            ),
          ),
        ],
      ),
    );
  }
}
