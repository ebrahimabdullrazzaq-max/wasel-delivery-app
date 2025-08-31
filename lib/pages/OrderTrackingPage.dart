// pages/ordertrackingpage.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

class OrderTrackingPage extends StatefulWidget {
  final int orderId;
  final String token;
  final VoidCallback? onRatingSubmitted;

  const OrderTrackingPage({
    Key? key,
    required this.orderId,
    required this.token,
    this.onRatingSubmitted,
  }) : super(key: key);

  @override
  _OrderTrackingPageState createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  Map<String, dynamic>? orderData;
  bool isLoading = true;
  String? error;
  bool hasShownRatingDialog = false;

  @override
  void initState() {
    super.initState();
    fetchOrderDetails();
  }

  Future<void> refreshOrder() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    await fetchOrderDetails();
  }

  Future<void> fetchOrderDetails() async {
    try {
      final url = Uri.parse('http://192.168.43.181:8000/api/customer/orders/${widget.orderId}');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (responseData.containsKey('id')) {
          if (mounted) {
            setState(() {
              orderData = responseData;
              isLoading = false;
            });
            final status = orderData?['status'];
            final isRated = orderData?['is_rated'] ?? false;
            if (status == 'delivered' && !isRated && !hasShownRatingDialog) {
              hasShownRatingDialog = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _showRatingDialog();
                }
              });
            }
          }
        } else {
          if (mounted) {
            setState(() {
              error = 'Order data not found.';
              isLoading = false;
            });
          }
        }
      } else {
        final String message = responseData['message'] ?? 'Failed to load order';
        if (mounted) {
          setState(() {
            error = 'Error: $message';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Network error. Please check your connection.';
          isLoading = false;
        });
      }
    }
  }

  void _showRatingDialog() {
    double rating = 0;
    TextEditingController reviewController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              'Rate Your Experience',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'How was your order from ${orderData?['store']?['name'] ?? 'the store'}?',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 36,
                        ),
                        onPressed: () {
                          setState(() {
                            rating = index + 1.0;
                          });
                        },
                      );
                    }),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Your rating: ${rating.toInt()}/5',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: reviewController,
                    decoration: InputDecoration(
                      labelText: 'Optional review',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      hintText: 'Share your experience (optional)...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Later', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  if (rating <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please select a rating'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  setState(() => isSubmitting = true);
                  try {
                    final response = await http.post(
                      Uri.parse('http://192.168.43.181:8000/api/customer/orders/${widget.orderId}/rate'),
                      headers: {
                        'Authorization': 'Bearer ${widget.token}',
                        'Content-Type': 'application/json',
                      },
                      body: jsonEncode({
                        'rating': rating,
                        'review': reviewController.text.trim(),
                      }),
                    );
                    if (response.statusCode == 200) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Thank you for your feedback!'),
                          backgroundColor: Color(0xFF0D47A1),
                        ),
                      );
                      await fetchOrderDetails();
                      Navigator.pop(context);
                      if (widget.onRatingSubmitted != null) {
                        widget.onRatingSubmitted!();
                      }
                    } else {
                      final errorMsg = jsonDecode(response.body)['message'] ?? 'Unknown error';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed: $errorMsg'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } finally {
                    setState(() => isSubmitting = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFC62828), // Red
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isSubmitting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text('Submit', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusTimeline(String status) {
    final steps = [
      {'title': 'Ordered', 'subtitle': 'Under Review', 'icon': Icons.receipt_long},
      {'title': 'Preparing', 'subtitle': '', 'icon': Icons.restaurant},
      {'title': 'On the Way', 'subtitle': '', 'icon': Icons.delivery_dining},
      {'title': 'Delivered', 'icon': Icons.check_circle},
    ];

    int activeStep = switch (status) {
      'under_review' => 0,
      'preparing' => 1,
      'on_the_way' => 2,
      'delivered' => 3,
      _ => 0,
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (index) {
              final isActive = index <= activeStep;
              final isCompleted = index < activeStep;
              return Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isActive ? Color(0xFF0D47A1) : Colors.grey[200],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? Color(0xFF0D47A1) : Colors.grey,
                        width: 2,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: Color(0xFF0D47A1).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Icon(
                      steps[index]['icon'] as IconData,
                      color: isCompleted ? Colors.white : (isActive ? Colors.white : Colors.grey),
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 70,
                    child: Column(
                      children: [
                        Text(
                          steps[index]['title'] as String,
                          style: TextStyle(
                            color: isActive ? Color(0xFF0D47A1) : Colors.grey[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (steps[index].containsKey('subtitle') && steps[index]['subtitle'] != '')
                          Text(
                            steps[index]['subtitle'] as String,
                            style: TextStyle(
                              color: isActive ? Color(0xFF0D47A1).withOpacity(0.8) : Colors.grey[500],
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: (activeStep + 1) / steps.length,
            backgroundColor: Colors.grey[200],
            color: Color(0xFF0D47A1),
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails() {
    final order = orderData!;
    final List items = order['order_items'] ?? [];
    final createdAt = order['created_at'];
    final date = createdAt != null ? DateTime.tryParse(createdAt) ?? DateTime.now() : DateTime.now();
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);

    final hasRating = order['rating'] != null;
    final rating = (order['rating'] ?? 0).toDouble();
    final review = order['review'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: Text(
              'Order Tracking',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
                fontFamily: 'Cairo',
              ),
            ),
          ),
          const Divider(color: Colors.grey, thickness: 1),
          const SizedBox(height: 16),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order Placed', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('#${order['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (hasRating) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            Text(' $rating/5', style: TextStyle(color: Colors.grey[700])),
                          ],
                        ),
                      ],
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Total', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                     Text(
  '\$${double.tryParse(order['total'].toString())?.toStringAsFixed(2) ?? '0.00'}',
  style: const TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 16,
    color: Color(0xFFC62828),
  ),
),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Order Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 8),
          _buildStatusTimeline(order['status'] ?? 'under_review'),
          const SizedBox(height: 24),
          if (order['store'] != null) ...[
            Text(
              'Store Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.store, color: Color(0xFF0D47A1)),
                ),
                title: Text(
                  order['store']['name'] ?? 'Store',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  order['store']['address'] ?? 'No address',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                trailing: (order['store']['average_rating'] != null)
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 18),
                          Text(
                            (order['store']['average_rating'] as num).toStringAsFixed(1),
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
          ],
          Text(
            'Order Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 8),
       ...items.map((item) {
  final productName = item['custom_name'] ?? (item['product']?['name'] ?? 'Unknown Product');
  final qty = item['quantity'] ?? 1;
  final price = double.tryParse(item['price'].toString()) ?? 0.0;

  return Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.shopping_basket, color: Colors.green[600]),
      ),
      title: Text(productName),
      subtitle: Text('\$${price.toStringAsFixed(2)}'),
      trailing: Text('x$qty'),
    ),
  );
}).toList(),
          const SizedBox(height: 24),
          if (hasRating) ...[
            Text(
              'Your Review',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 24),
                        Text(' $rating/5', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                    if (review != null && review.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        review,
                        style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSummaryRow('Subtotal', order['subtotal']),
                  _buildSummaryRow('Delivery Fee', order['delivery_fee']),
                  const Divider(height: 24),
                  _buildSummaryRow('Total', order['total'], isTotal: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, dynamic amount, {bool isTotal = false}) {
    double value = 0;
    if (amount is String) {
      value = double.tryParse(amount) ?? 0;
    } else if (amount is num) {
      value = amount.toDouble();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? Color(0xFF0D47A1) : Colors.black,
            ),
          ),
          Text(
          '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? Color(0xFF0D47A1) : Colors.black,
            ),
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
          'Track Your Order',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFF0D47A1), // Navy Blue
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: refreshOrder,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshOrder,
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
            : error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 60, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: refreshOrder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF0D47A1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Retry',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  )
                : orderData == null
                    ? Center(child: Text('No order data available'))
                    : Directionality(
                        textDirection: ui.TextDirection.ltr, // Use LTR unless Arabic
                        child: SingleChildScrollView(child: _buildOrderDetails()),
                      ),
      ),
    );
  }
}