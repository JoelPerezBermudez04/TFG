import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/features/receptes/providers/receptes_provider.dart';

import 'receptes_provider_test.mocks.dart';

@GenerateMocks([ApiService])
void main() {
  late MockApiService mockApi;
  late ReceptesProvider provider;

  // ── Fixtures ─────────────────────────────────────────────────────────────

  final recomanacioJson = {
    'id_api': '123',
    'nom': 'Paella',
    'imatge_url': null,
    'temps_preparacio': 30,
    'porcions': 4,
    'dietes': ['vegana'],
    'intolerancias': ['gluten'],
    'score': 9.5,
    'ingredients_coberts': 3,
    'total_ingredients': 5,
  };

  final receptaJson = {
    'id_api': '123',
    'nom': 'Paella',
    'imatge_url': null,
    'temps_preparacio': 30,
    'porcions': 4,
    'dietes': ['vegana'],
    'intolerancias': ['gluten'],
    'ingredients': <dynamic>[],
    'num_ingredients': 5,
  };

  final detallJson = {
    'id_api': '123',
    'nom': 'Paella',
    'descripcio': 'Recepta de prova',
    'imatge_url': null,
    'temps_preparacio': 30,
    'porcions': 4,
    'instruccions': ['Fase 1', 'Fase 2'],
    'dietes': ['vegana'],
    'intolerancias': ['gluten'],
    'ingredients': [
      {
        'producte': 10,
        'producte_nom': 'Arròs',
        'producte_emoji': '🍚',
        'producte_imatge_url': null,
        'quantitat': 1.0,
        'unitat': 'kg',
        'nom_original': 'Arròs de gra llarg',
      }
    ],
    'num_ingredients': 1,
  };

  final favoritsJson = [
    {
      'id': 1,
      'recepta': '123',
      'recepta_nom': 'Paella',
      'recepta_imatge_url': null,
      'recepta_temps_preparacio': 30,
      'recepta_dietes': ['vegana'],
    }
  ];

  // Helper: retorna una pàgina buida de recomanacions (evita side-effects al setUp)
  void stubRecomanacionsEmpty() {
    when(mockApi.get(argThat(startsWith('/recomanacions/')))).thenAnswer(
      (_) async => {'statusCode': 200, 'body': {'count': 0, 'results': []}},
    );
  }

  void stubRecomanacionsOne() {
    when(mockApi.get(argThat(startsWith('/recomanacions/')))).thenAnswer(
      (_) async => {
        'statusCode': 200,
        'body': {'count': 1, 'results': [recomanacioJson]},
      },
    );
  }

  setUp(() {
    mockApi = MockApiService();
    // El provider arranca en modeRecomanacions=true i crida _fetchRecomanacions
    // al constructor; stubbem per defecte per evitar MissingStubError.
    stubRecomanacionsEmpty();
    provider = ReceptesProvider(api: mockApi);
  });

  // ── Mode C: recomanacions ─────────────────────────────────────────────────

  group('fetchReceptes – mode C (recomanacions)', () {
    test('carrega recomanacions i actualitza receptes i total', () async {
      stubRecomanacionsOne();
      await provider.fetchReceptes();

      expect(provider.receptes, hasLength(1));
      expect(provider.total, 1);
      expect(provider.isLoading, isFalse);
    });

    test('estableix error quan el servidor retorna no-200', () async {
      when(mockApi.get(argThat(startsWith('/recomanacions/')))).thenAnswer(
        (_) async => {'statusCode': 500, 'body': {'detail': 'Error intern'}},
      );
      await provider.fetchReceptes();

      expect(provider.receptes, isEmpty);
      expect(provider.error, 'Error carregant recomanacions');
    });

    test('estableix error de connexió quan llença excepció', () async {
      when(mockApi.get(argThat(startsWith('/recomanacions/')))).thenThrow(
        Exception('network'),
      );
      await provider.fetchReceptes();

      expect(provider.error, 'Error de connexió');
      expect(provider.isLoading, isFalse);
    });

    test('no fa cap crida nova si ja hi ha una en curs', () async {
      // Simula càrrega lenta per poder cridar fetchReceptes dues vegades
      when(mockApi.get(argThat(startsWith('/recomanacions/')))).thenAnswer(
        (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return {'statusCode': 200, 'body': {'count': 0, 'results': []}};
        },
      );

      final f1 = provider.fetchReceptes();
      final f2 = provider.fetchReceptes(); // ha de ser ignorat
      await Future.wait([f1, f2]);

      // Només s'hauria d'haver cridat una vegada (la del setUp + una nova)
      verify(mockApi.get(argThat(startsWith('/recomanacions/')))).called(lessThan(3));
    });
  });

  // ── Mode A: receptes normals ──────────────────────────────────────────────

  group('fetchReceptes – mode A (receptes normals)', () {
    setUp(() {
      // Desactivem mode recomanacions per entrar al mode A
      when(mockApi.get(argThat(startsWith('/receptes/')))).thenAnswer(
        (_) async => {
          'statusCode': 200,
          'body': {'count': 1, 'results': [receptaJson]},
        },
      );
      provider.setModeRecomanacions(false);
    });

    test('carrega receptes i actualitza la llista', () async {
      await provider.fetchReceptes();

      expect(provider.receptes, hasLength(1));
      expect(provider.receptes.first.nom, 'Paella');
      expect(provider.isLoading, isFalse);
    });

    test('estableix error quan el servidor retorna no-200', () async {
      when(mockApi.get(argThat(startsWith('/receptes/')))).thenAnswer(
        (_) async => {'statusCode': 500, 'body': {}},
      );
      await provider.fetchReceptes();

      expect(provider.error, 'Error carregant receptes');
    });

    test('estableix error de connexió quan llença excepció', () async {
      when(mockApi.get(argThat(startsWith('/receptes/')))).thenThrow(
        Exception('network'),
      );
      await provider.fetchReceptes();

      expect(provider.error, 'Error de connexió');
    });
  });

  // ── Mode B: filtre per producte (servidor) ────────────────────────────────

  group('setProducte / mode B', () {
    test('usa filtre de producte al servidor', () async {
      when(mockApi.get(argThat(contains('producte=3')))).thenAnswer(
        (_) async => {
          'statusCode': 200,
          'body': {'count': 1, 'results': [receptaJson]},
        },
      );

      provider.setProducte(3, 'Carxofa');
      await Future<void>.delayed(Duration.zero);

      expect(provider.producteId, 3);
      expect(provider.producteNom, 'Carxofa');
      verify(mockApi.get(argThat(contains('producte=3')))).called(1);
    });

    test('estableix error quan el servidor retorna no-200', () async {
      when(mockApi.get(argThat(contains('producte=3')))).thenAnswer(
        (_) async => {'statusCode': 500, 'body': {}},
      );

      provider.setProducte(3, 'Carxofa');
      await Future<void>.delayed(Duration.zero);

      expect(provider.error, 'Error carregant receptes');
    });

    test('estableix error de connexió quan llença excepció', () async {
      when(mockApi.get(argThat(contains('producte=3')))).thenThrow(
        Exception('network'),
      );

      provider.setProducte(3, 'Carxofa');
      await Future<void>.delayed(Duration.zero);

      expect(provider.error, 'Error de connexió');
    });

    test('setProducte(null) neteja el producte i aplica filtres locals', () async {
      // Primer posem un producte
      when(mockApi.get(argThat(contains('producte=3')))).thenAnswer(
        (_) async => {
          'statusCode': 200,
          'body': {'count': 1, 'results': [receptaJson]},
        },
      );
      provider.setProducte(3, 'Carxofa');
      await Future<void>.delayed(Duration.zero);

      provider.setProducte(null, null);

      expect(provider.producteId, isNull);
      expect(provider.producteNom, isNull);
    });
  });

  // ── Canvi de mode ─────────────────────────────────────────────────────────

  group('setModeRecomanacions', () {
    test('setModeRecomanacions(true) dispara fetch de recomanacions', () async {
      // Primer anem a mode A
      when(mockApi.get(argThat(startsWith('/receptes/')))).thenAnswer(
        (_) async => {'statusCode': 200, 'body': {'count': 0, 'results': []}},
      );
      provider.setModeRecomanacions(false);
      await Future<void>.delayed(Duration.zero);

      stubRecomanacionsOne();
      provider.setModeRecomanacions(true);
      await Future<void>.delayed(Duration.zero);

      expect(provider.modeRecomanacions, isTrue);
      expect(provider.receptes, hasLength(1));
    });

    test('setModeRecomanacions(false) amb receptes en cache no fa nova crida', () async {
      // Carreguem el mode A primer per tenir _totsReceptes
      when(mockApi.get(argThat(startsWith('/receptes/')))).thenAnswer(
        (_) async => {
          'statusCode': 200,
          'body': {'count': 1, 'results': [receptaJson]},
        },
      );
      provider.setModeRecomanacions(false);
      await Future<void>.delayed(Duration.zero);
      await provider.fetchReceptes();

      // Ara tornem a mode C i de nou a mode A: hauria de reutilitzar cache
      stubRecomanacionsEmpty();
      provider.setModeRecomanacions(true);
      await Future<void>.delayed(Duration.zero);
      provider.setModeRecomanacions(false);

      expect(provider.modeRecomanacions, isFalse);
      expect(provider.receptes, hasLength(1));
    });
  });

  // ── Filtres locals (mode C) ───────────────────────────────────────────────

  group('filtres locals – mode C', () {
    setUp(() async {
      stubRecomanacionsOne();
      await provider.fetchReceptes();
    });

    test('setSearch filtra per nom localment sense nova crida', () {
      provider.setSearch('Paella');
      expect(provider.receptes, hasLength(1));

      provider.setSearch('XYZ_inexistent');
      expect(provider.receptes, isEmpty);
    });

    test('setSearch buit restaura tots els resultats', () {
      provider.setSearch('XYZ');
      provider.setSearch('');
      expect(provider.receptes, hasLength(1));
    });

    test('setDietes dispara nou fetch al servidor en mode C', () async {
      when(mockApi.get(argThat(contains('dieta=vegana')))).thenAnswer(
        (_) async => {
          'statusCode': 200,
          'body': {'count': 1, 'results': [recomanacioJson]},
        },
      );

      provider.setDietes(['vegana']);
      await Future<void>.delayed(Duration.zero);

      verify(mockApi.get(argThat(contains('dieta=vegana')))).called(1);
    });

    test('setMaxTemps dispara nou fetch al servidor en mode C', () async {
      when(mockApi.get(argThat(contains('max_temps=60')))).thenAnswer(
        (_) async => {
          'statusCode': 200,
          'body': {'count': 1, 'results': [recomanacioJson]},
        },
      );

      provider.setMaxTemps(60);
      await Future<void>.delayed(Duration.zero);

      verify(mockApi.get(argThat(contains('max_temps=60')))).called(1);
    });
  });

  // ── Filtres locals (mode A) ───────────────────────────────────────────────

  group('filtres locals – mode A', () {
    setUp(() async {
      when(mockApi.get(argThat(startsWith('/receptes/')))).thenAnswer(
        (_) async => {
          'statusCode': 200,
          'body': {
            'count': 2,
            'results': [
              receptaJson,
              {
                ...receptaJson,
                'id_api': '456',
                'nom': 'Truita',
                'temps_preparacio': 10,
                'dietes': ['vegetariana'],
              },
            ],
          },
        },
      );
      provider.setModeRecomanacions(false);
      await Future<void>.delayed(Duration.zero);
      await provider.fetchReceptes();
    });

    test('setSearch filtra per nom localment', () {
      provider.setSearch('Truita');
      expect(provider.receptes, hasLength(1));
      expect(provider.receptes.first.nom, 'Truita');
    });

    test('setDietes filtra localment en mode A', () {
      provider.setDietes(['vegetariana']);
      expect(provider.receptes, hasLength(1));
      expect(provider.receptes.first.nom, 'Truita');
    });

    test('setMaxTemps filtra localment en mode A', () {
      provider.setMaxTemps(15);
      expect(provider.receptes, hasLength(1));
      expect(provider.receptes.first.nom, 'Truita');
    });
  });

  // ── Filtres de recomanacions (flags) ──────────────────────────────────────

  group('filtres recomanacions – flags', () {
    test('setNomesInventari dispara fetch amb nomes_inventari=true', () async {
      when(mockApi.get(argThat(contains('nomes_inventari=true')))).thenAnswer(
        (_) async => {'statusCode': 200, 'body': {'count': 0, 'results': []}},
      );

      provider.setNomesInventari(true);
      await Future<void>.delayed(Duration.zero);

      expect(provider.nomesInventari, isTrue);
      verify(mockApi.get(argThat(contains('nomes_inventari=true')))).called(1);
    });

    test('setNomesUrgents dispara fetch amb nomes_urgents=true', () async {
      when(mockApi.get(argThat(contains('nomes_urgents=true')))).thenAnswer(
        (_) async => {'statusCode': 200, 'body': {'count': 0, 'results': []}},
      );

      provider.setNomesUrgents(true);
      await Future<void>.delayed(Duration.zero);

      expect(provider.nomesUrgents, isTrue);
      verify(mockApi.get(argThat(contains('nomes_urgents=true')))).called(1);
    });

    test('setProductesSeleccionats dispara fetch amb productes=1,2', () async {
      when(mockApi.get(argThat(contains('productes=1%2C2')))).thenAnswer(
        (_) async => {'statusCode': 200, 'body': {'count': 0, 'results': []}},
      );

      provider.setProductesSeleccionats([1, 2]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.productesSeleccionats, [1, 2]);
      verify(mockApi.get(argThat(contains('productes=')))).called(1);
    });

    test('setRecomanacionsFiltres aplica múltiples filtres alhora', () async {
      when(mockApi.get(argThat(startsWith('/recomanacions/')))).thenAnswer(
        (_) async => {'statusCode': 200, 'body': {'count': 0, 'results': []}},
      );

      provider.setRecomanacionsFiltres(
        dietes: ['vegana'],
        maxTemps: 30,
        nomesInventari: true,
        nomesUrgents: false,
      );
      await Future<void>.delayed(Duration.zero);

      expect(provider.dietes, ['vegana']);
      expect(provider.maxTemps, 30);
      expect(provider.nomesInventari, isTrue);
      expect(provider.nomesUrgents, isFalse);
    });
  });

  // ── clearFiltres ──────────────────────────────────────────────────────────

  group('clearFiltres', () {
    test('reseteja tots els filtres i torna a mode C', () async {
      // Posem alguns filtres
      provider.setNomesInventari(true);
      await Future<void>.delayed(Duration.zero);

      stubRecomanacionsEmpty();
      provider.clearFiltres();
      await Future<void>.delayed(Duration.zero);

      expect(provider.search, '');
      expect(provider.dietes, isEmpty);
      expect(provider.maxTemps, isNull);
      expect(provider.producteId, isNull);
      expect(provider.modeRecomanacions, isTrue);
      expect(provider.nomesInventari, isFalse);
      expect(provider.nomesUrgents, isFalse);
      expect(provider.productesSeleccionats, isEmpty);
    });
  });

  // ── teFiltresActius ───────────────────────────────────────────────────────

  group('teFiltresActius', () {
    test('és false quan no hi ha cap filtre actiu', () {
      expect(provider.teFiltresActius, isFalse);
    });

    test('és true quan hi ha cerca', () {
      provider.setSearch('paella');
      expect(provider.teFiltresActius, isTrue);
    });

    test('és true quan nomesInventari és true', () async {
      when(mockApi.get(argThat(startsWith('/recomanacions/')))).thenAnswer(
        (_) async => {'statusCode': 200, 'body': {'count': 0, 'results': []}},
      );
      provider.setNomesInventari(true);
      await Future<void>.delayed(Duration.zero);
      expect(provider.teFiltresActius, isTrue);
    });

    test('és true quan nomesUrgents és true', () async {
      when(mockApi.get(argThat(startsWith('/recomanacions/')))).thenAnswer(
        (_) async => {'statusCode': 200, 'body': {'count': 0, 'results': []}},
      );
      provider.setNomesUrgents(true);
      await Future<void>.delayed(Duration.zero);
      expect(provider.teFiltresActius, isTrue);
    });
  });

  // ── Detall ────────────────────────────────────────────────────────────────

  group('fetchDetall', () {
    test('carrega el detall correctament', () async {
      when(mockApi.get('/receptes/123/')).thenAnswer(
        (_) async => {'statusCode': 200, 'body': detallJson},
      );

      await provider.fetchDetall('123');

      expect(provider.receptaDetall, isNotNull);
      expect(provider.receptaDetall?.idApi, '123');
      expect(provider.loadingDetall, isFalse);
    });

    test('deixa receptaDetall null quan el servidor retorna no-200', () async {
      when(mockApi.get('/receptes/123/')).thenAnswer(
        (_) async => {'statusCode': 404, 'body': {}},
      );

      await provider.fetchDetall('123');

      expect(provider.receptaDetall, isNull);
      expect(provider.loadingDetall, isFalse);
    });

    test('deixa receptaDetall null quan llença excepció', () async {
      when(mockApi.get('/receptes/123/')).thenThrow(Exception('network'));

      await provider.fetchDetall('123');

      expect(provider.receptaDetall, isNull);
      expect(provider.loadingDetall, isFalse);
    });
  });

  // ── Favorits ──────────────────────────────────────────────────────────────

  group('fetchFavorits', () {
    test('carrega favorits i actualitza esFavorit', () async {
      when(mockApi.get('/favorits/')).thenAnswer(
        (_) async => {'statusCode': 200, 'body': favoritsJson},
      );

      await provider.fetchFavorits();

      expect(provider.favorits, hasLength(1));
      expect(provider.esFavorit('123'), isTrue);
      expect(provider.loadingFavorits, isFalse);
    });

    test('deixa favorits buit quan el servidor retorna no-200', () async {
      when(mockApi.get('/favorits/')).thenAnswer(
        (_) async => {'statusCode': 401, 'body': {}},
      );

      await provider.fetchFavorits();

      expect(provider.favorits, isEmpty);
    });

    test('deixa favorits buit quan llença excepció', () async {
      when(mockApi.get('/favorits/')).thenThrow(Exception('network'));

      await provider.fetchFavorits();

      expect(provider.favorits, isEmpty);
      expect(provider.loadingFavorits, isFalse);
    });
  });

  group('toggleFavorit', () {
    test('afegeix favorit quan no és present', () async {
      when(mockApi.get('/favorits/')).thenAnswer(
        (_) async => {'statusCode': 200, 'body': []},
      );
      when(mockApi.post('/favorits/', any)).thenAnswer(
        (_) async => {'statusCode': 201, 'body': favoritsJson.first},
      );

      await provider.fetchFavorits();
      await provider.toggleFavorit('123');

      expect(provider.favorits, hasLength(1));
      expect(provider.esFavorit('123'), isTrue);
    });

    test('elimina favorit quan ja és present', () async {
      when(mockApi.get('/favorits/')).thenAnswer(
        (_) async => {'statusCode': 200, 'body': favoritsJson},
      );
      when(mockApi.delete('/favorits/123/')).thenAnswer(
        (_) async => {'statusCode': 204, 'body': null},
      );

      await provider.fetchFavorits();
      await provider.toggleFavorit('123');

      expect(provider.favorits, isEmpty);
      expect(provider.esFavorit('123'), isFalse);
    });

    test('no modifica favorits si el servidor retorna error en afegir', () async {
      when(mockApi.get('/favorits/')).thenAnswer(
        (_) async => {'statusCode': 200, 'body': []},
      );
      when(mockApi.post('/favorits/', any)).thenAnswer(
        (_) async => {'statusCode': 400, 'body': {'error': 'ja existeix'}},
      );

      await provider.fetchFavorits();
      await provider.toggleFavorit('123');

      expect(provider.favorits, isEmpty);
      expect(provider.esFavorit('123'), isFalse);
    });

    test('no modifica favorits si el servidor retorna error en eliminar', () async {
      when(mockApi.get('/favorits/')).thenAnswer(
        (_) async => {'statusCode': 200, 'body': favoritsJson},
      );
      when(mockApi.delete('/favorits/123/')).thenAnswer(
        (_) async => {'statusCode': 500, 'body': {}},
      );

      await provider.fetchFavorits();
      await provider.toggleFavorit('123');

      expect(provider.favorits, hasLength(1));
      expect(provider.esFavorit('123'), isTrue);
    });

    test('no fa res si ja hi ha un toggle en curs pel mateix id', () async {
      when(mockApi.get('/favorits/')).thenAnswer(
        (_) async => {'statusCode': 200, 'body': []},
      );
      when(mockApi.post('/favorits/', any)).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return {'statusCode': 201, 'body': favoritsJson.first};
      });

      await provider.fetchFavorits();
      final f1 = provider.toggleFavorit('123');
      final f2 = provider.toggleFavorit('123'); // ha de ser ignorat
      await Future.wait([f1, f2]);

      verify(mockApi.post('/favorits/', any)).called(1);
    });

    test('isToggling és true durant el toggle i false en acabar', () async {
      when(mockApi.get('/favorits/')).thenAnswer(
        (_) async => {'statusCode': 200, 'body': []},
      );
      when(mockApi.post('/favorits/', any)).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return {'statusCode': 201, 'body': favoritsJson.first};
      });

      await provider.fetchFavorits();
      final future = provider.toggleFavorit('123');
      expect(provider.isToggling('123'), isTrue);
      await future;
      expect(provider.isToggling('123'), isFalse);
    });
  });

  // ── Getters auxiliars ─────────────────────────────────────────────────────

  group('getters auxiliars', () {
    test('hasMore és false en mode recomanacions', () {
      expect(provider.hasMore, isFalse);
    });

    test('hasMore és false en mode B sense resultats', () async {
      when(mockApi.get(argThat(contains('producte=1')))).thenAnswer(
        (_) async => {'statusCode': 200, 'body': {'count': 0, 'results': []}},
      );
      provider.setProducte(1, 'Test');
      await Future<void>.delayed(Duration.zero);

      expect(provider.hasMore, isFalse);
    });

    test('loadingDetall és false inicialment', () {
      expect(provider.loadingDetall, isFalse);
    });

    test('loadingFavorits és false inicialment', () {
      expect(provider.loadingFavorits, isFalse);
    });
  });
}