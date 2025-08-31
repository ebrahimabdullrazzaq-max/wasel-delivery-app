// providers/auth_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  final String baseUrl = 'http://192.168.43.181:8000/api';
  bool _isAuthenticated = false;
  Map<String, dynamic>? _user;
  String? _token;
  bool _isLoading = false;
  

  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;

  // ✅ Add getters
  String? get name => _user?['name'];
  String? get email => _user?['email'];
  String? get phone => _user?['phone'];
  String? get address => _user?['address'];
  double? get latitude => _user?['latitude'];
  double? get longitude => _user?['longitude'];

  // ✅ Initialize auth state
  Future<void> initialize() async {
    await _loadToken();
    if (_token != null) {
      await _fetchUserProfile(); // ✅ This was missing!
    }
  }

  // ✅ Load token from SharedPreferences
  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _isAuthenticated = _token != null;
    notifyListeners();
  }

  // ✅ Save token
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    _token = token;
    _isAuthenticated = true;
    notifyListeners();
  }

  // ✅ Fetch user profile from API
 Future<void> _fetchUserProfile() async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/user'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      _user = data['user'];

      // ✅ Save user to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', json.encode(_user!));

      notifyListeners();
    } else {
      await logout();
    }
  } catch (e) {
    await logout();
  }
}

  // ✅ Update user profile
  Future<void> updateUser(Map<String, dynamic> updatedUser) async {
    _user = updatedUser;

    // ✅ Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', json.encode(_user!));

    notifyListeners();
  }

  // ✅ Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    _token = null;
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  // ✅ Login with Email & Password
 Future<Map<String, dynamic>> login(String email, String password) async {
  try {
    _isLoading = true;
    notifyListeners();

    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: { 'Content-Type': 'application/json' },
      body: json.encode({ 'email': email, 'password': password }),
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      await _saveToken(data['token']);
      _user = data['user'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', json.encode(_user!));

      notifyListeners();

      return {'success': true, 'user': _user};
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Login failed',
      };
    }
  } catch (e) {
    return {
      'success': false,
      'message': 'Network error. Please check your connection.',
    };
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

  // ✅ Register new user
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    required String phone,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': confirmPassword,
          'phone': phone,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 201 && responseData['success'] == true) {
        await _saveToken(responseData['token']);
        _user = responseData['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', json.encode(_user!));

        notifyListeners();

        return {'success': true, 'user': _user};
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Registration failed',
          'errors': responseData['errors'] ?? {},
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Email or phone number alredy exist.Please try another email or phone number',
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // providers/auth_provider.dart

Future<Map<String, dynamic>> deleteAccount(String token) async {
  try {
    final response = await http.delete(
      Uri.parse('$baseUrl/user'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = json.decode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      await logout(); // Clear local data
      return {'success': true, 'message': data['message']};
    } else {
      return {'success': false, 'message': data['message'] ?? 'Failed to delete account'};
    }
  } catch (e) {
    return {'success': false, 'message': 'Network error. Could not delete account.'};
  }
}
}