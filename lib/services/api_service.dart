import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.43.181:8000/api';

  // Save token locally
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  // Get saved token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Register
  static Future<http.Response> register(String name, String email, String password) {
    return http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Accept': 'application/json'},
      body: {'name': name, 'email': email, 'password': password},
    );
  }

  // Login
  static Future<http.Response> login(String email, String password) {
    return http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Accept': 'application/json'},
      body: {'email': email, 'password': password},
    );
  }

  // Get products
  static Future<http.Response> getProducts() {
    return http.get(Uri.parse('$baseUrl/products'));
  }

  // Get categories
  static Future<http.Response> getCategories() {
    return http.get(Uri.parse('$baseUrl/categories'));
  }

  // Place order (as customer)
  static Future<http.Response> placeOrder({
    required List<Map<String, dynamic>> items,
    required String address,
  }) async {
    final token = await getToken();
    final url = Uri.parse('$baseUrl/orders');

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'items': items,
        'address': address,
      }),
    );

    return response;
  }

  // Get my orders (as customer)
  static Future<http.Response> getMyOrders() async {
    final token = await getToken();
    return http.get(
      Uri.parse('$baseUrl/my-orders'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
  }

  // Logout
  static Future<http.Response> logout() async {
    final token = await getToken();
    return http.post(
      Uri.parse('$baseUrl/logout'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
  }


  Future<Map<String, dynamic>> createOrder({
  required List<Map<String, dynamic>> products,
  required String address,
  required String token, required String location, required String latitude, required String longitude,
}) async {
  final url = Uri.parse('http://192.168.43.181:8000/api/customer/orders');

  final response = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: jsonEncode({
      'address': address,
      'items': products,
    }),
  );

  if (response.statusCode == 200 || response.statusCode == 201) {
    throw Exception('Failed to create order: ${response.body}');
  
  } else {
    return {
      'success': false,
      'message': jsonDecode(response.body)['message'] ?? 'Error',
    };
  }
}


 
}
