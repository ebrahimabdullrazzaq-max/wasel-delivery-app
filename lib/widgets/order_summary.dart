import 'package:flutter/material.dart';

class OrderSummary extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final double total;
  final String deliveryLocation;

  const OrderSummary({
    Key? key,
    required this.items,
    required this.total,
    required this.deliveryLocation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            for (var item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['name'],
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    Text(
                      '${item['quantity']} x \$${item['price'].toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            
            const Divider(),
            Row(
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            const Text(
              'Delivery Location:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              deliveryLocation,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}