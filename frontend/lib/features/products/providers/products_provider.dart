import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/config/api_config.dart';
import '../models/product_model.dart';

class ProductsProvider with ChangeNotifier {
  final _api = ApiService();
  List<Product> _products = [];
  List<Category> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchProducts({String? cerca}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      String endpoint = ApiConfig.products;
      if (cerca != null && cerca.isNotEmpty) {
        endpoint += '?cerca=${Uri.encodeComponent(cerca)}';
      }

      final response = await _api.get(endpoint);

      if (response['statusCode'] == 200) {
        _products = (response['body'] as List)
            .map((json) => Product.fromJson(json))
            .toList();
      } else {
        _error = 'Error carregant productes';
      }
    } catch (_) {
      _error = 'Error de connexió';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchCategories() async {
    try {
      final response = await _api.get(ApiConfig.categories);
      if (response['statusCode'] == 200) {
        _categories = (response['body'] as List)
            .map((json) => Category.fromJson(json))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  void clearProducts() {
    _products = [];
    notifyListeners();
  }

  Product? getProductById(int id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}