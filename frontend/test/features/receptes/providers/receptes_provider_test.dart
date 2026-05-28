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

  setUp(() {
    mockApi = MockApiService();
    provider = ReceptesProvider(api: mockApi);
  });

  group('fetchReceptes', () {
    test('loads recomanacions in mode C', () async {
      when(mockApi.get(argThat(startsWith('/recomanacions/')))).thenAnswer((_) async => {
            'statusCode': 200,
            'body': {
              'count': 1,
              'results': [recomanacioJson],
            },
          });

      await provider.fetchReceptes();

      expect(provider.receptes, hasLength(1));
      expect(provider.total, 1);
      expect(provider.isLoading, isFalse);
    });

    test('sets error when server returns non-200', () async {
      when(mockApi.get(argThat(startsWith('/recomanacions/')))).thenAnswer((_) async => {
            'statusCode': 500,
            'body': {'detail': 'Error intern'},
          });

      await provider.fetchReceptes();

      expect(provider.receptes, isEmpty);
      expect(provider.error, 'Error carregant recomanacions');
    });
  });

  group('filters and product selection', () {

    test('setProducte uses server-side product filter', () async {
      when(mockApi.get(argThat(contains('producte=3')))).thenAnswer((_) async => {
            'statusCode': 200,
            'body': {
              'count': 1,
              'results': [recomanacioJson],
            },
          });

      provider.setProducte(3, 'Carxofa');
      await Future<void>.delayed(Duration.zero);

      expect(provider.producteId, 3);
      expect(provider.producteNom, 'Carxofa');
      verify(mockApi.get(argThat(contains('producte=3')))).called(1);
    });
  });

  group('details and favorites', () {
    test('fetchDetall loads recipe details', () async {
      when(mockApi.get('/receptes/123/')).thenAnswer((_) async => {
            'statusCode': 200,
            'body': detallJson,
          });

      await provider.fetchDetall('123');

      expect(provider.receptaDetall, isNotNull);
      expect(provider.receptaDetall?.idApi, '123');
    });

    test('fetchFavorits loads saved favorites', () async {
      when(mockApi.get('/favorits/')).thenAnswer((_) async => {
            'statusCode': 200,
            'body': favoritsJson,
          });

      await provider.fetchFavorits();

      expect(provider.favorits, hasLength(1));
      expect(provider.esFavorit('123'), isTrue);
    });

    test('toggleFavorit adds a favorite when not present', () async {
      when(mockApi.get('/favorits/')).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [],
          });
      when(mockApi.post('/favorits/', any)).thenAnswer((_) async => {
            'statusCode': 201,
            'body': favoritsJson.first,
          });

      await provider.fetchFavorits();
      await provider.toggleFavorit('123');

      expect(provider.favorits, hasLength(1));
      expect(provider.esFavorit('123'), isTrue);
    });

    test('toggleFavorit removes a favorite when already present', () async {
      when(mockApi.get('/favorits/')).thenAnswer((_) async => {
            'statusCode': 200,
            'body': favoritsJson,
          });
      when(mockApi.delete('/favorits/123/')).thenAnswer((_) async => {
            'statusCode': 204,
            'body': null,
          });

      await provider.fetchFavorits();
      await provider.toggleFavorit('123');

      expect(provider.favorits, isEmpty);
      expect(provider.esFavorit('123'), isFalse);
    });
  });
}
