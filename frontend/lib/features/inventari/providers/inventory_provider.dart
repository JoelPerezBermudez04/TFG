import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/config/api_config.dart';
import '../models/inventory_item_model.dart';

class InventoryProvider with ChangeNotifier {
  final _api = ApiService();
  List<InventoryItem> _items = [];
  List<InventoryItem> _expiringItems = [];
  bool _isLoading = false;
  String? _error;

  List<InventoryItem> get items => _items;
  List<InventoryItem> get expiringItems => _expiringItems;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get totalItems => _items.length;
  int get urgentCount => _items
      .where((i) =>
          i.expiryStatus == ExpiryStatus.urgent ||
          i.expiryStatus == ExpiryStatus.expired)
      .length;

  String _parseError(Map<String, dynamic>? body, String fallback) {
    if (body == null) return fallback;
    if (body['error'] is String) return body['error'];
    if (body['detail'] is String) return body['detail'];
    for (final key in body.keys) {
      final value = body[key];
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value is String) return value;
    }
    return fallback;
  }

  Future<void> fetchInventory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get(ApiConfig.inventory);

      if (response['statusCode'] == 200) {
        _items = (response['body'] as List)
            .map((json) => InventoryItem.fromJson(json))
            .toList();
        _sortItems();
      } else {
        _error = 'Error carregant inventari';
      }
    } catch (_) {
      _error = 'Error de connexió';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchExpiringItems() async {
    try {
      final response = await _api.get(ApiConfig.expiringItems);
      if (response['statusCode'] == 200) {
        _expiringItems = (response['body'] as List)
            .map((json) => InventoryItem.fromJson(json))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> addItem({
    required int producteId,
    required double quantitat,
    required String unitat,
    DateTime? dataCaducitat,
  }) async {
    _error = null;

    try {
      final data = {
        'producte': producteId,
        'quantitat': quantitat,
        'unitat': unitat,
        if (dataCaducitat != null)
          'data_caducitat': dataCaducitat.toIso8601String().split('T')[0],
      };

      final response = await _api.post(ApiConfig.inventory, data);

      if (response['statusCode'] == 201) {
        await fetchInventory();
        return true;
      } else {
        _error = _parseError(response['body'], 'Error afegint producte');
        notifyListeners();
        return false;
      }
    } catch (_) {
      _error = 'Error de connexió';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateItem(
    int itemId, {
    required double quantitat,
    required String unitat,
    DateTime? dataCaducitat,
    bool clearDate = false,
  }) async {
    _error = null;

    try {
      final data = <String, dynamic>{
        'quantitat': quantitat,
        'unitat': unitat,
        'data_caducitat': clearDate
            ? null
            : dataCaducitat?.toIso8601String().split('T')[0],
      };

      final response = await _api.patch('${ApiConfig.inventory}$itemId/', data);

      if (response['statusCode'] == 200) {
        await fetchInventory();
        return true;
      } else {
        _error = _parseError(response['body'], 'Error actualitzant producte');
        notifyListeners();
        return false;
      }
    } catch (_) {
      _error = 'Error de connexió';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteItem(int itemId) async {
    _error = null;

    try {
      final response = await _api.delete('${ApiConfig.inventory}$itemId/');

      if (response['statusCode'] == 204) {
        _items.removeWhere((item) => item.id == itemId);
        notifyListeners();
        return true;
      } else {
        _error = 'Error eliminant producte';
        notifyListeners();
        return false;
      }
    } catch (_) {
      _error = 'Error de connexió';
      notifyListeners();
      return false;
    }
  }

  InventoryItem? getItemById(int id) {
    try {
      return _items.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  void _sortItems() {
    _items.sort((a, b) {
      if (a.dataCaducitat == null && b.dataCaducitat == null) return 0;
      if (a.dataCaducitat == null) return 1;
      if (b.dataCaducitat == null) return -1;
      return a.dataCaducitat!.compareTo(b.dataCaducitat!);
    });
  }
}