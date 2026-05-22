import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

// ──────────────────────────────────────────────
// Models
// ──────────────────────────────────────────────

class IngredientRecepta {
  final int producte;
  final String producteNom;
  final String producteEmoji;
  final String? producteImatgeUrl;
  final double quantitat;
  final String unitat;
  final String nomOriginal;

  const IngredientRecepta({
    required this.producte,
    required this.producteNom,
    required this.producteEmoji,
    this.producteImatgeUrl,
    required this.quantitat,
    required this.unitat,
    required this.nomOriginal,
  });

  factory IngredientRecepta.fromJson(Map<String, dynamic> j) => IngredientRecepta(
        producte: j['producte'] as int,
        producteNom: j['producte_nom'] as String? ?? '',
        producteEmoji: j['producte_emoji'] as String? ?? '🛒',
        producteImatgeUrl: j['producte_imatge_url'] as String?,
        quantitat: (j['quantitat'] as num).toDouble(),
        unitat: j['unitat'] as String,
        nomOriginal: j['nom_original'] as String? ?? '',
      );
}

class Recepta {
  final String idApi;
  final String nom;
  final String? descripcio;
  final String? imatgeUrl;
  final int tempsPreparacio;
  final int porcions;
  final List<String>? instruccions;
  final List<String>? dietes;
  final List<String>? intolerancias;
  final List<IngredientRecepta> ingredients;
  final int numIngredients;

  const Recepta({
    required this.idApi,
    required this.nom,
    this.descripcio,
    this.imatgeUrl,
    required this.tempsPreparacio,
    required this.porcions,
    this.instruccions,
    this.dietes,
    this.intolerancias,
    required this.ingredients,
    required this.numIngredients,
  });

  factory Recepta.fromJson(Map<String, dynamic> j) => Recepta(
        idApi: j['id_api'] as String,
        nom: j['nom'] as String,
        descripcio: j['descripcio'] as String?,
        imatgeUrl: j['imatge_url'] as String?,
        tempsPreparacio: j['temps_preparacio'] as int,
        porcions: j['porcions'] as int,
        instruccions: (j['instruccions'] as List?)?.map((e) {
          if (e is String) return e;
          if (e is Map) {
            return (e['text'] ?? e['pas'] ?? e['descripcio'] ?? e['step'] ??
                    e['description'] ?? e.values.firstWhere(
                      (v) => v is String,
                      orElse: () => '',
                    ))
                .toString();
          }
          return e.toString();
        }).toList(),
        dietes: (j['dietes'] as List?)?.cast<String>(),
        intolerancias: (j['intolerancias'] as List?)?.cast<String>(),
        ingredients: (j['ingredients'] as List? ?? [])
            .map((e) => IngredientRecepta.fromJson(e as Map<String, dynamic>))
            .toList(),
        numIngredients: j['num_ingredients'] as int? ??
            (j['ingredients'] as List? ?? []).length,
      );
}

class FavoritItem {
  final int id;
  final String receptaId;
  final String receptaNom;
  final String? receptaImatgeUrl;
  final int receptaTempsPreparacio;
  final List<String>? receptaDietes;

  const FavoritItem({
    required this.id,
    required this.receptaId,
    required this.receptaNom,
    this.receptaImatgeUrl,
    required this.receptaTempsPreparacio,
    this.receptaDietes,
  });

  factory FavoritItem.fromJson(Map<String, dynamic> j) => FavoritItem(
        id: j['id'] as int,
        receptaId: (j['recepta'] ?? '').toString(),
        receptaNom: j['recepta_nom'] as String? ?? '',
        receptaImatgeUrl: j['recepta_imatge_url'] as String?,
        receptaTempsPreparacio: j['recepta_temps_preparacio'] as int? ?? 0,
        receptaDietes: (j['recepta_dietes'] as List?)?.cast<String>(),
      );
}

// ──────────────────────────────────────────────
// Provider
// ──────────────────────────────────────────────

class ReceptesProvider with ChangeNotifier {
  final _api = ApiService();

  // Cache de totes les receptes (sense filtres de servidor)
  List<Recepta> _totsReceptes = [];

  // Llistat mostrat (resultat de filtrar _totsReceptes)
  List<Recepta> _receptes = [];
  bool _isLoading = false;
  String? _error;
  int _total = 0;
  int _offset = 0;
  static const int _limit = 20;
  bool get hasMore => _offset < _serverTotal;
  int _serverTotal = 0;

  // Filtres actius
  String _search = '';
  String? _dieta;
  String? _intolerancia;
  int? _maxTemps;

  // Detall
  Recepta? _receptaDetall;
  bool _loadingDetall = false;

  // Favorits
  List<FavoritItem> _favorits = [];
  bool _loadingFavorits = false;
  final Set<String> _favoritIds = {};   // idApi de receptes guardades
  final Set<String> _toggling = {};     // ids en procés

  // ── Getters ──
  List<Recepta> get receptes => _receptes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get total => _total;

  String get search => _search;
  String? get dieta => _dieta;
  String? get intolerancia => _intolerancia;
  int? get maxTemps => _maxTemps;

  Recepta? get receptaDetall => _receptaDetall;
  bool get loadingDetall => _loadingDetall;

  List<FavoritItem> get favorits => _favorits;
  bool get loadingFavorits => _loadingFavorits;
  bool esFavorit(String idApi) => _favoritIds.contains(idApi);
  bool isToggling(String idApi) => _toggling.contains(idApi);

  // ── Filtres ──
  void setSearch(String v) { _search = v; _aplicarFiltres(); }
  void setDieta(String? v) { _dieta = v; _aplicarFiltres(); }
  void setIntolerancia(String? v) { _intolerancia = v; _aplicarFiltres(); }
  void setMaxTemps(int? v) { _maxTemps = v; _aplicarFiltres(); }

  void clearFiltres() {
    _search = '';
    _dieta = null;
    _intolerancia = null;
    _maxTemps = null;
    _aplicarFiltres();
  }

  bool get teFiltresActius =>
      _search.isNotEmpty || _dieta != null || _intolerancia != null || _maxTemps != null;

  // Filtra localment sobre _totsReceptes
  void _aplicarFiltres() {
    var llista = _totsReceptes;

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      llista = llista.where((r) => r.nom.toLowerCase().contains(q)).toList();
    }
    if (_dieta != null) {
      final d = _dieta!.toLowerCase();
      llista = llista.where((r) =>
          r.dietes != null &&
          r.dietes!.any((v) => v.toLowerCase().contains(d))).toList();
    }
    if (_intolerancia != null) {
      final intol = _intolerancia!.toLowerCase();
      llista = llista.where((r) =>
          r.intolerancias == null ||
          !r.intolerancias!.any((v) => v.toLowerCase().contains(intol))).toList();
    }
    if (_maxTemps != null) {
      llista = llista.where((r) => r.tempsPreparacio <= _maxTemps!).toList();
    }

    _receptes = llista;
    _total = llista.length;
    notifyListeners();
  }

  void _resetAndFetch() {
    _totsReceptes = [];
    _receptes = [];
    _offset = 0;
    _total = 0;
    _serverTotal = 0;
    fetchReceptes();
  }

  String _buildQuery({int? offset}) {
    final params = <String, String>{};
    params['limit'] = _limit.toString();
    params['offset'] = (offset ?? _offset).toString();
    final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '/receptes/?$qs';
  }

  // ── Fetch llistat (carrega tot paginant al servidor, filtra localment) ──
  Future<void> fetchReceptes({bool loadMore = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    if (!loadMore) notifyListeners();

    final int offset = loadMore ? _offset : 0;
    try {
      final response = await _api.get(_buildQuery(offset: offset));
      if (response['statusCode'] == 200) {
        final body = response['body'] as Map<String, dynamic>;
        _serverTotal = (body['count'] as int?) ?? 0;
        final results = (body['results'] as List)
            .map((e) => Recepta.fromJson(e as Map<String, dynamic>))
            .toList();
        if (loadMore) {
          _totsReceptes.addAll(results);
        } else {
          _totsReceptes = results;
        }
        _offset = _totsReceptes.length;
        _aplicarFiltres();
        // Si hi ha més pàgines, carrega-les totes per poder filtrar localment
        if (_offset < _serverTotal) {
          _isLoading = false;
          fetchReceptes(loadMore: true);
          return;
        }
      } else {
        _error = 'Error carregant receptes';
      }
    } catch (_) {
      _error = 'Error de connexió';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Fetch detall ──
  Future<void> fetchDetall(String idApi) async {
    _loadingDetall = true;
    _receptaDetall = null;
    notifyListeners();

    try {
      final response = await _api.get('/receptes/$idApi/');
      if (response['statusCode'] == 200) {
        _receptaDetall = Recepta.fromJson(response['body'] as Map<String, dynamic>);
      }
    } catch (_) {}

    _loadingDetall = false;
    notifyListeners();
  }

  // ── Favorits ──
  Future<void> fetchFavorits() async {
    _loadingFavorits = true;
    notifyListeners();

    try {
      final response = await _api.get('/favorits/');
      if (response['statusCode'] == 200) {
        _favorits = (response['body'] as List)
            .map((e) => FavoritItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _favoritIds
          ..clear()
          ..addAll(_favorits.map((f) => f.receptaId));
      }
    } catch (_) {}

    _loadingFavorits = false;
    notifyListeners();
  }

  Future<void> toggleFavorit(String idApi) async {
    if (_toggling.contains(idApi)) return;
    _toggling.add(idApi);
    notifyListeners();

    final esFav = _favoritIds.contains(idApi);
    try {
      if (esFav) {
        // Busquem l'id del favorit (el pk al backend és l'idApi de la recepta)
        final response = await _api.delete('/favorits/$idApi/');
        if (response['statusCode'] == 204) {
          _favoritIds.remove(idApi);
          _favorits.removeWhere((f) => f.receptaId == idApi);
        }
      } else {
        final response = await _api.post('/favorits/', {'recepta': idApi});
        if (response['statusCode'] == 201) {
          _favoritIds.add(idApi);
          final newFav = FavoritItem.fromJson(response['body'] as Map<String, dynamic>);
          _favorits.add(newFav);
        }
      }
    } catch (_) {}

    _toggling.remove(idApi);
    notifyListeners();
  }
}