import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/features/llista_compra/providers/compra_provider.dart';
import 'package:frontend/features/llista_compra/models/compra_item_model.dart';

import 'compra_provider_test.mocks.dart';

// Genera el mock amb: dart run build_runner build
@GenerateMocks([ApiService])
void main() {
  late MockApiService mockApi;
  late CompraProvider provider;

  // JSON base per reutilitzar als tests
  Map<String, dynamic> itemJson({
    int id = 1,
    bool comprat = false,
    String data = '2024-01-01T00:00:00Z',
  }) =>
      {
        'id': id,
        'usuari': 1,
        'producte': 10,
        'producte_nom': 'Llet',
        'producte_emoji': '🥛',
        'quantitat': 1.0,
        'unitat': 'L',
        'comprat': comprat,
        'data_afegit': data,
      };

  setUp(() {
    mockApi = MockApiService();
    provider = CompraProvider.withApi(mockApi); // constructor injectable (veure nota)
  });

  // ─────────────────────────────────────────────
  // fetchItems
  // ─────────────────────────────────────────────
  group('fetchItems', () {
    test('carrega items quan el servidor retorna 200', () async {
      when(mockApi.get('/compra/')).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [itemJson(id: 1), itemJson(id: 2)],
          });

      await provider.fetchItems();

      expect(provider.isLoading, isFalse);
      expect(provider.items, hasLength(2));
      expect(provider.error, isNull);
    });

    test('estableix error quan el servidor falla', () async {
      when(mockApi.get('/compra/')).thenAnswer((_) async => {
            'statusCode': 500,
            'body': {'detail': 'error intern'},
          });

      await provider.fetchItems();

      expect(provider.items, isEmpty);
      expect(provider.error, isNotNull);
    });

    test('estableix error de connexió quan l\'API llança una excepció', () async {
      when(mockApi.get('/compra/')).thenThrow(Exception('timeout'));

      await provider.fetchItems();

      expect(provider.items, isEmpty);
      expect(provider.error, 'Error de connexió');
    });

    test('isLoading és false un cop acabat', () async {
      when(mockApi.get('/compra/')).thenAnswer((_) async => {
            'statusCode': 200,
            'body': <dynamic>[],
          });

      await provider.fetchItems();

      expect(provider.isLoading, isFalse);
    });
  });

  // ─────────────────────────────────────────────
  // Getters derivats: pendents / comprats
  // ─────────────────────────────────────────────
  group('getters pendents / comprats', () {
    setUp(() async {
      when(mockApi.get('/compra/')).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [
              itemJson(id: 1, comprat: false),
              itemJson(id: 2, comprat: true),
              itemJson(id: 3, comprat: false),
            ],
          });
      await provider.fetchItems();
    });

    test('pendents retorna els items no comprats', () {
      expect(provider.pendents, hasLength(2));
      expect(provider.pendents.every((i) => !i.comprat), isTrue);
    });

    test('comprats retorna els items comprats', () {
      expect(provider.comprats, hasLength(1));
      expect(provider.comprats.every((i) => i.comprat), isTrue);
    });

    test('totalPendents és el recompte correcte', () {
      expect(provider.totalPendents, 2);
    });
  });

  // ─────────────────────────────────────────────
  // addItem
  // ─────────────────────────────────────────────
  group('addItem', () {
    test('retorna true i refresca la llista en cas d\'èxit', () async {
      when(mockApi.post('/compra/', any)).thenAnswer((_) async => {
            'statusCode': 201,
            'body': itemJson(id: 5),
          });
      when(mockApi.get('/compra/')).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [itemJson(id: 5)],
          });

      final ok = await provider.addItem(
        producteId: 10,
        quantitat: 1.0,
        unitat: 'L',
      );

      expect(ok, isTrue);
      expect(provider.items, hasLength(1));
    });

    test('retorna false i desa l\'error del servidor', () async {
      when(mockApi.post('/compra/', any)).thenAnswer((_) async => {
            'statusCode': 400,
            'body': {'error': 'Producte ja a la llista'},
          });

      final ok = await provider.addItem(
        producteId: 10,
        quantitat: 1.0,
        unitat: 'L',
      );

      expect(ok, isFalse);
      expect(provider.error, 'Producte ja a la llista');
    });

    test('retorna false en cas d\'excepció de xarxa', () async {
      when(mockApi.post('/compra/', any)).thenThrow(Exception('no internet'));

      final ok = await provider.addItem(
        producteId: 10,
        quantitat: 1.0,
        unitat: 'L',
      );

      expect(ok, isFalse);
      expect(provider.error, 'Error de connexió');
    });
  });

  // ─────────────────────────────────────────────
  // toggleComprat
  // ─────────────────────────────────────────────
  group('toggleComprat', () {
    setUp(() async {
      when(mockApi.get('/compra/')).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [itemJson(id: 1, comprat: false)],
          });
      await provider.fetchItems();
    });

    test('canvia optimisticament a comprat=true i confirma', () async {
      when(mockApi.patch('/compra/1/', any)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': itemJson(id: 1, comprat: true),
          });

      final ok = await provider.toggleComprat(1);

      expect(ok, isTrue);
      expect(provider.items.first.comprat, isTrue);
    });

    test('reverteix el canvi si el servidor falla', () async {
      when(mockApi.patch('/compra/1/', any)).thenAnswer((_) async => {
            'statusCode': 500,
            'body': {},
          });

      await provider.toggleComprat(1);

      expect(provider.items.first.comprat, isFalse);
    });

    test('reverteix si hi ha excepció de xarxa', () async {
      when(mockApi.patch('/compra/1/', any)).thenThrow(Exception('timeout'));

      await provider.toggleComprat(1);

      expect(provider.items.first.comprat, isFalse);
    });

    test('retorna false si l\'id no existeix', () async {
      final ok = await provider.toggleComprat(999);

      expect(ok, isFalse);
    });
  });

  // ─────────────────────────────────────────────
  // deleteItem
  // ─────────────────────────────────────────────
  group('deleteItem', () {
    setUp(() async {
      when(mockApi.get('/compra/')).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [itemJson(id: 1), itemJson(id: 2)],
          });
      await provider.fetchItems();
    });

    test('elimina l\'item de la llista local quan el servidor retorna 204', () async {
      when(mockApi.delete('/compra/1/')).thenAnswer((_) async => {
            'statusCode': 204,
            'body': null,
          });

      final ok = await provider.deleteItem(1);

      expect(ok, isTrue);
      expect(provider.items.any((i) => i.id == 1), isFalse);
      expect(provider.items, hasLength(1));
    });

    test('no elimina l\'item si el servidor falla', () async {
      when(mockApi.delete('/compra/1/')).thenAnswer((_) async => {
            'statusCode': 500,
            'body': {},
          });

      final ok = await provider.deleteItem(1);

      expect(ok, isFalse);
      expect(provider.items, hasLength(2));
    });
  });

  // ─────────────────────────────────────────────
  // deleteAllComprats
  // ─────────────────────────────────────────────
  group('deleteAllComprats', () {
    test('elimina tots els items marcats com a comprats', () async {
      when(mockApi.get('/compra/')).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [
              itemJson(id: 1, comprat: false),
              itemJson(id: 2, comprat: true),
              itemJson(id: 3, comprat: true),
            ],
          });
      await provider.fetchItems();

      when(mockApi.delete('/compra/2/')).thenAnswer((_) async => {'statusCode': 204});
      when(mockApi.delete('/compra/3/')).thenAnswer((_) async => {'statusCode': 204});

      await provider.deleteAllComprats();

      expect(provider.items, hasLength(1));
      expect(provider.items.first.id, 1);
    });
  });

  // ─────────────────────────────────────────────
  // _parseError (comportament observable via addItem)
  // ─────────────────────────────────────────────
  group('_parseError', () {
    test('extreu missatge del camp "detail"', () async {
      when(mockApi.post('/compra/', any)).thenAnswer((_) async => {
            'statusCode': 400,
            'body': {'detail': 'Unauthorized'},
          });

      await provider.addItem(producteId: 1, quantitat: 1.0, unitat: 'unitat');

      expect(provider.error, 'Unauthorized');
    });

    test('extreu el primer element d\'una llista d\'errors', () async {
      when(mockApi.post('/compra/', any)).thenAnswer((_) async => {
            'statusCode': 400,
            'body': {
              'producte': ['Producte no vàlid.']
            },
          });

      await provider.addItem(producteId: 1, quantitat: 1.0, unitat: 'unitat');

      expect(provider.error, 'Producte no vàlid.');
    });
  });
}