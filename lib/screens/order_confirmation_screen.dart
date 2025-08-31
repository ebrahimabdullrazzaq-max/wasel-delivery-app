import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../widgets/order_summary.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double total;
  final String deliveryLocation;

  const OrderConfirmationScreen({
    Key? key,
    required this.cartItems,
    required this.total,
    required this.deliveryLocation,
  }) : super(key: key);

  @override
  _OrderConfirmationScreenState createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _confirmOrder() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    final result = await orderProvider.confirmOrder(
      items: widget.cartItems,
      deliveryLocation: widget.deliveryLocation,
      paymentMethod: 'cash', // Default payment method
      total: widget.total,
      token: authProvider.token!,
    );

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      Navigator.pushReplacementNamed(context, '/order-success');
    } else {
      setState(() {
        _errorMessage = result['message'];
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Order'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: OrderSummary(
                  items: widget.cartItems,
                  total: widget.total,
                  deliveryLocation: widget.deliveryLocation,
                ),
              ),
            ),
            
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _confirmOrder,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'CONFIRM ORDER',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}