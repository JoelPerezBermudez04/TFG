import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../models/compra_item_model.dart';

class CompraProvider with ChangeNotifier {
  final ApiService _api;
  List<CompraItem> _items = [];
  bool _isLoading = false;
  String? _error;

  // Constructor per defecte
  CompraProvider() : _api = ApiService();

  // Constructor injectable per a tests
  CompraProvider.withApi(this._api);

  List<CompraItem> get items => _items;
  List<CompraItem> get pendents => _items.where((i) => !i.comprat).toList();
  List<CompraItem> get comprats => _items.where((i) => i.comprat).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalPendents => pendents.length;

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

  Future<void> fetchItems() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get('/compra/');
      if (response['statusCode'] == 200) {
        _items = (response['body'] as List)
            .map((json) => CompraItem.fromJson(json))
            .toList();
        _sortItems();
      } else {
        _error = 'Error carregant la llista de la compra';
      }
    } catch (_) {
      _error = 'Error de connexió';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addItem({
    required int producteId,
    required double quantitat,
    required String unitat,
  }) async {
    _error = null;
    try {
      final response = await _api.post('/compra/', {
        'producte': producteId,
        'quantitat': quantitat,
        'unitat': unitat,
      });

      if (response['statusCode'] == 201) {
        await fetchItems();
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

  /// Afegeix múltiples productes d'un cop (des d'una recepta).
  /// Retorna el nombre d'items afegits correctament.
  Future<int> addMultiple(List<Map<String, dynamic>> items) async {
    int added = 0;
    for (final item in items) {
      final ok = await addItem(
        producteId: item['producte'] as int,
        quantitat: item['quantitat'] as double,
        unitat: item['unitat'] as String,
      );
      if (ok) added++;
    }
    return added;
  }

  Future<bool> toggleComprat(int itemId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1) return false;

    final item = _items[index];
    final nouEstat = !item.comprat;

    // Optimistic update
    _items[index] = item.copyWith(comprat: nouEstat);
    notifyListeners();

    try {
      final response = await _api.patch('/compra/$itemId/', {'comprat': nouEstat});
      if (response['statusCode'] == 200) {
        return true;
      } else {
        // Revert
        _items[index] = item;
        notifyListeners();
        return false;
      }
    } catch (_) {
      // Revert
      _items[index] = item;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteItem(int itemId) async {
    try {
      final response = await _api.delete('/compra/$itemId/');
      if (response['statusCode'] == 204) {
        _items.removeWhere((i) => i.id == itemId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteAllComprats() async {
    final toDelete = comprats.map((i) => i.id).toList();
    for (final id in toDelete) {
      await deleteItem(id);
    }
  }

  void _sortItems() {
    _items.sort((a, b) {
      if (a.comprat == b.comprat) {
        return a.dataAfegit.compareTo(b.dataAfegit);
      }
      return a.comprat ? 1 : -1;
    });
  }
}