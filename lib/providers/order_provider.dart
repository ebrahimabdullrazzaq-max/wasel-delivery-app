import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import './auth_provider.dart';

class OrderProvider with ChangeNotifier {
  final String baseUrl;

  OrderProvider(this.baseUrl);

  Future<Map<String, dynamic>> confirmOrder({
    required List<Map<String, dynamic>> items,
    required String deliveryLocation,
    required String paymentMethod,
    required double total,
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/customer/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'items': items,
          'delivery_location': deliveryLocation,
          'payment_method': paymentMethod,
          'total': total,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': responseData['message'],
          'order': responseData['order'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Order confirmation failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }
}