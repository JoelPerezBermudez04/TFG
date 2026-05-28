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

// Model per al mode recomanacions (/recomanacions/)
class Recomanacio {
  final String idApi;
  final String nom;
  final String? imatgeUrl;
  final int tempsPreparacio;
  final int porcions;
  final List<String>? dietes;
  final List<String>? intolerancias;
  final double score;
  final int ingredientsCoberts;
  final int totalIngredients;

  const Recomanacio({
    required this.idApi,
    required this.nom,
    this.imatgeUrl,
    required this.tempsPreparacio,
    required this.porcions,
    this.dietes,
    this.intolerancias,
    required this.score,
    required this.ingredientsCoberts,
    required this.totalIngredients,
  });

  factory Recomanacio.fromJson(Map<String, dynamic> j) => Recomanacio(
        idApi: j['id_api'] as String,
        nom: j['nom'] as String,
        imatgeUrl: j['imatge_url'] as String?,
        tempsPreparacio: j['temps_preparacio'] as int,
        porcions: j['porcions'] as int,
        dietes: (j['dietes'] as List?)?.cast<String>(),
        intolerancias: (j['intolerancias'] as List?)?.cast<String>(),
        score: (j['score'] as num).toDouble(),
        ingredientsCoberts: j['ingredients_coberts'] as int,
        totalIngredients: j['total_ingredients'] as int,
      );

  // Converteix a Recepta per reutilitzar ReceptaCard
  Recepta toRecepta() => Recepta(
        idApi: idApi,
        nom: nom,
        imatgeUrl: imatgeUrl,
        tempsPreparacio: tempsPreparacio,
        porcions: porcions,
        dietes: dietes,
        intolerancias: intolerancias,
        ingredients: const [],
        numIngredients: totalIngredients,
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
  final ApiService _api;

  ReceptesProvider({ApiService? api}) : _api = api ?? ApiService();

  // Cache de totes les receptes (sense filtres de servidor)
  List<Recepta> _totsReceptes = [];

  // Llistat mostrat (resultat de filtrar _totsReceptes)
  List<Recepta> _receptes = [];
  bool _isLoading = false;
  String? _error;
  int _total = 0;
  int _offset = 0;
  static const int _limit = 20;
  bool get hasMore {
    // Si hi ha filtre local actiu (cerca o múltiples dietes), no paginem automàticament
    // perquè el filtre ja s'aplica sobre tots els resultats carregats
    final teFiltreLocal = _search.isNotEmpty || _dietes.length > 1;
    if (teFiltreLocal) return false;
    return _offset < _serverTotal;
  }
  int _serverTotal = 0;

  // Filtres actius
  String _search = '';
  List<String> _dietes = [];
  int? _maxTemps;
  int? _producteId;
  String? _producteNom;

  // Filtres de recomanacions (mode C)
  bool _modeRecomanacions = true;
  bool _nomesInventari = false;
  bool _nomesUrgents = false;
  List<int> _productesSeleccionats = [];  // IDs d'inventari per filtrar

  // Recomanacions actuals (mode C)
  List<Recomanacio> _recomanacions = [];
  // Comptador de generació: s'incrementa cada cop que es fa un fetch nou (no loadMore)
  // per detectar si una càrrega paginada en curs ha quedat obsoleta
  int _fetchGeneration = 0;

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
  List<String> get dietes => _dietes;
  int? get maxTemps => _maxTemps;
  int? get producteId => _producteId;
  String? get producteNom => _producteNom;

  bool get modeRecomanacions => _modeRecomanacions;
  bool get nomesInventari => _nomesInventari;
  bool get nomesUrgents => _nomesUrgents;
  List<int> get productesSeleccionats => _productesSeleccionats;
  List<Recomanacio> get recomanacions => _recomanacions;

  Recepta? get receptaDetall => _receptaDetall;
  bool get loadingDetall => _loadingDetall;

  List<FavoritItem> get favorits => _favorits;
  bool get loadingFavorits => _loadingFavorits;
  bool esFavorit(String idApi) => _favoritIds.contains(idApi);
  bool isToggling(String idApi) => _toggling.contains(idApi);

  // ── Filtres ──
  void setSearch(String v) {
    _search = v;
    if (_modeRecomanacions) {
      // En mode recomanacions el filtre és local sobre els resultats ja carregats
      _aplicarFiltresRecomanacions();
    } else {
      _aplicarFiltres();
    }
  }

  void setDietes(List<String> v) {
    _dietes = v;
    if (_modeRecomanacions) {
      _fetchRecomanacions();
    } else {
      _aplicarFiltres();
    }
  }
  void setMaxTemps(int? v) { _maxTemps = v; _aplicarFiltres(); }

  // setProducte usa mode B (servidor), no filtre local
  void setProducte(int? id, String? nom) {
    _producteId = id;
    _producteNom = nom;
    if (id != null) {
      _fetchReceptesServidor();
    } else {
      _aplicarFiltres();
    }
  }

  // ── Filtres de recomanacions (mode C) ──
  void setModeRecomanacions(bool v) {
    _modeRecomanacions = v;
    if (v) {
      _fetchRecomanacions();
    } else {
      _recomanacions = [];
      if (_totsReceptes.isNotEmpty) {
        _aplicarFiltres();
      } else {
        fetchReceptes();
      }
    }
  }

  void setNomesInventari(bool v) {
    _nomesInventari = v;
    if (_modeRecomanacions) _fetchRecomanacions();
  }

  void setNomesUrgents(bool v) {
    _nomesUrgents = v;
    if (_modeRecomanacions) _fetchRecomanacions();
  }

  void setProductesSeleccionats(List<int> ids) {
    _productesSeleccionats = ids;
    if (_modeRecomanacions) _fetchRecomanacions();
  }

  void clearFiltres() {
    _search = '';
    _dietes = [];
    _maxTemps = null;
    _producteId = null;
    _producteNom = null;
    _modeRecomanacions = true;
    _nomesInventari = false;
    _nomesUrgents = false;
    _productesSeleccionats = [];
    _recomanacions = [];
    _fetchRecomanacions();
  }

  bool get teFiltresActius =>
      _search.isNotEmpty ||
      _dietes.isNotEmpty ||
      _maxTemps != null ||
      _producteId != null ||
      _nomesInventari ||
      _nomesUrgents;

  // Filtra localment sobre _totsReceptes
  void _aplicarFiltres() {
    var llista = _totsReceptes;

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      llista = llista.where((r) => r.nom.toLowerCase().contains(q)).toList();
    }
    if (_dietes.isNotEmpty) {
      llista = llista.where((r) =>
          r.dietes != null &&
          _dietes.every((d) =>
              r.dietes!.any((v) => v.toLowerCase() == d.toLowerCase()))).toList();
    }
    if (_maxTemps != null) {
      llista = llista.where((r) => r.tempsPreparacio <= _maxTemps!).toList();
    }

    _receptes = llista;
    _total = llista.length;
    notifyListeners();
  }

  // Filtra localment sobre els resultats de recomanacions ja carregats (sense nova crida al servidor)
  void _aplicarFiltresRecomanacions({bool notify = true}) {
    var visibles = _recomanacions;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      visibles = visibles.where((r) => r.nom.toLowerCase().contains(q)).toList();
    }
    if (_dietes.length > 1) {
      visibles = visibles.where((r) =>
          _dietes.every((d) =>
              r.dietes != null &&
              r.dietes!.any((v) => v.toLowerCase() == d.toLowerCase()))).toList();
    }
    _receptes = visibles.map((r) => r.toRecepta()).toList();
    // El total reflecteix els resultats visibles (filtrats localment), no el total del servidor
    _total = _receptes.length;
    if (notify) notifyListeners();
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
    // Quan hi ha filtre per producte, el passem al servidor (el llistat no inclou ingredients)
    if (_producteId != null) params['producte'] = _producteId.toString();
    final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '/receptes/?$qs';
  }

  // ── Fetch llistat ──
  // Mode A (normal): carrega totes les pàgines i filtra localment
  // Mode B (filtre per producte): delega al servidor via ?producte=X
  // Mode C (recomanacions): crida /recomanacions/ amb filtres d'inventari
  Future<void> fetchReceptes({bool loadMore = false}) async {
    if (_isLoading) return;

    if (_modeRecomanacions) {
      await _fetchRecomanacions(loadMore: loadMore);
      return;
    }

    if (_producteId != null) {
      await _fetchReceptesServidor(loadMore: loadMore);
      return;
    }

    // Mode A
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

  // Mode B: resultats filtrats per producte directament del servidor
  Future<void> _fetchReceptesServidor({bool loadMore = false}) async {
    _isLoading = true;
    _error = null;
    if (!loadMore) {
      _receptes = [];
      _offset = 0;
      _serverTotal = 0;
    }
    notifyListeners();

    try {
      final response = await _api.get(_buildQuery(offset: loadMore ? _offset : 0));
      if (response['statusCode'] == 200) {
        final body = response['body'] as Map<String, dynamic>;
        _serverTotal = (body['count'] as int?) ?? 0;
        final results = (body['results'] as List)
            .map((e) => Recepta.fromJson(e as Map<String, dynamic>))
            .toList();
        if (loadMore) {
          _receptes.addAll(results);
        } else {
          _receptes = results;
        }
        _offset = _receptes.length;
        _total = _serverTotal;
      } else {
        _error = 'Error carregant receptes';
      }
    } catch (_) {
      _error = 'Error de connexió';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Mode C: recomanacions basades en l'inventari de l'usuari, amb paginació
  Future<void> _fetchRecomanacions({bool loadMore = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    if (!loadMore) {
      _recomanacions = [];
      _receptes = [];
      _offset = 0;
      _serverTotal = 0;
      _fetchGeneration++;
    }
    final int myGeneration = _fetchGeneration;
    notifyListeners();

    try {
      final params = <String, String>{};
      params['limit'] = _limit.toString();
      params['offset'] = _offset.toString();
      // El backend accepta un sol valor de dieta; si n'hi ha diverses
      // enviem la primera i filtrem la resta localment
      if (_dietes.isNotEmpty) params['dieta'] = _dietes.first;
      if (_maxTemps != null) params['max_temps'] = _maxTemps.toString();
      if (_nomesInventari) params['nomes_inventari'] = 'true';
      if (_nomesUrgents) params['nomes_urgents'] = 'true';
      if (_productesSeleccionats.isNotEmpty) {
        params['productes'] = _productesSeleccionats.join(',');
      }
      final qs = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final response = await _api.get('/recomanacions/?$qs');

      // Si mentre esperàvem s'ha iniciat un fetch nou, descartem aquesta resposta
      if (myGeneration != _fetchGeneration) return;

      if (response['statusCode'] == 200) {
        final body = response['body'] as Map<String, dynamic>;
        _serverTotal = (body['count'] as int?) ?? 0;
        final results = (body['results'] as List)
            .map((e) => Recomanacio.fromJson(e as Map<String, dynamic>))
            .toList();
        if (loadMore) {
          _recomanacions.addAll(results);
        } else {
          _recomanacions = results;
        }
        _offset = _recomanacions.length;
        // Filtres locals sobre els resultats del servidor
        _aplicarFiltresRecomanacions(notify: false);

        // Paginació automàtica només si no hi ha filtre local de cerca actiu,
        // ja que el buscador filtra sobre els resultats ja carregats
        final teFiltreLocal = _search.isNotEmpty || _dietes.length > 1;
        if (!teFiltreLocal && _offset < _serverTotal) {
          _isLoading = false;
          notifyListeners();
          _fetchRecomanacions(loadMore: true);
          return;
        }
      } else {
        _error = 'Error carregant recomanacions';
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