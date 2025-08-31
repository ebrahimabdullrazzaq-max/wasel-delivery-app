import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProductProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<dynamic> _categories = [];
  List<dynamic> _products = [];

  List<dynamic> get categories => _categories;
  List<dynamic> get products => _products;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> fetchData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _categories = (await ApiService.getCategories()) as List;
      _products = (await ApiService.getProducts()) as List;
    } catch (e) {
      print("Error fetching data: $e");
    }

    _isLoading = false;
    notifyListeners();
  }
}
