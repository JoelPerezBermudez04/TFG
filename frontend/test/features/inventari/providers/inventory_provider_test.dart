import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/config/api_config.dart';
import 'package:frontend/features/inventari/providers/inventory_provider.dart';
import 'package:frontend/features/inventari/models/inventory_item_model.dart';

import 'inventory_provider_test.mocks.dart';

@GenerateMocks([ApiService])
void main() {
  late MockApiService mockApi;
  late InventoryProvider provider;

  Map<String, dynamic> itemJson({int id = 1, String? dataCaducitat}) => {
        'id': id,
        'usuari': 1,
        'producte': 10,
        'producte_nom': 'Llet',
        'producte_emoji': '🥛',
        'quantitat': 1.0,
        'unitat': 'L',
        'data_caducitat': dataCaducitat,
        'data_afegit': '2024-01-01T00:00:00Z',
        'caducat': false,
      };

  setUp(() {
    mockApi = MockApiService();
    provider = InventoryProvider(api: mockApi);
  });

  group('fetchInventory', () {
    test('loads inventory when server returns 200', () async {
      when(mockApi.get(ApiConfig.inventory)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [itemJson(id: 1), itemJson(id: 2)],
          });

      await provider.fetchInventory();

      expect(provider.isLoading, isFalse);
      expect(provider.items, hasLength(2));
      expect(provider.error, isNull);
    });

    test('sets error when server returns non-200', () async {
      when(mockApi.get(ApiConfig.inventory)).thenAnswer((_) async => {
            'statusCode': 500,
            'body': {'detail': 'Error intern'},
          });

      await provider.fetchInventory();

      expect(provider.items, isEmpty);
      expect(provider.error, 'Error carregant inventari');
    });

    test('sets connection error on exception', () async {
      when(mockApi.get(ApiConfig.inventory)).thenThrow(Exception('timeout'));

      await provider.fetchInventory();

      expect(provider.error, 'Error de connexió');
    });
  });

  group('fetchExpiringItems', () {
    test('loads expiring items on success', () async {
      when(mockApi.get(ApiConfig.expiringItems)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [itemJson(id: 5, dataCaducitat: '2024-01-02')],
          });

      await provider.fetchExpiringItems();

      expect(provider.expiringItems, hasLength(1));
      expect(provider.expiringItems.first.id, 5);
    });
  });

  group('addItem', () {
    test('returns true and refreshes inventory on success', () async {
      when(mockApi.post(ApiConfig.inventory, any)).thenAnswer((_) async => {
            'statusCode': 201,
            'body': itemJson(id: 3),
          });
      when(mockApi.get(ApiConfig.inventory)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [itemJson(id: 3)],
          });

      final ok = await provider.addItem(producteId: 10, quantitat: 1.0, unitat: 'L');

      expect(ok, isTrue);
      expect(provider.items, hasLength(1));
    });

    test('returns false and sets error on bad request', () async {
      when(mockApi.post(ApiConfig.inventory, any)).thenAnswer((_) async => {
            'statusCode': 400,
            'body': {'error': 'Producte invàlid'},
          });

      final ok = await provider.addItem(producteId: 10, quantitat: 1.0, unitat: 'L');

      expect(ok, isFalse);
      expect(provider.error, 'Producte invàlid');
    });
  });

  group('updateItem', () {
    test('returns true and refreshes inventory on success', () async {
      when(mockApi.patch('${ApiConfig.inventory}1/', any)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': itemJson(id: 1),
          });
      when(mockApi.get(ApiConfig.inventory)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [itemJson(id: 1)],
          });

      final ok = await provider.updateItem(1, quantitat: 2.0, unitat: 'kg');

      expect(ok, isTrue);
      expect(provider.items, hasLength(1));
    });

    test('returns false and sets error on failure', () async {
      when(mockApi.patch('${ApiConfig.inventory}1/', any)).thenAnswer((_) async => {
            'statusCode': 400,
            'body': {'detail': 'No es pot actualitzar'},
          });

      final ok = await provider.updateItem(1, quantitat: 2.0, unitat: 'kg');

      expect(ok, isFalse);
      expect(provider.error, 'No es pot actualitzar');
    });
  });

  group('deleteItem', () {
    test('returns true when the server deletes the item', () async {
      when(mockApi.delete('${ApiConfig.inventory}1/')).thenAnswer((_) async => {
            'statusCode': 204,
            'body': null,
          });

      final ok = await provider.deleteItem(1);

      expect(ok, isTrue);
    });

    test('returns false and sets error on failure', () async {
      when(mockApi.delete('${ApiConfig.inventory}1/')).thenAnswer((_) async => {
            'statusCode': 500,
            'body': {'detail': 'Error intern'},
          });

      final ok = await provider.deleteItem(1);

      expect(ok, isFalse);
      expect(provider.error, 'Error eliminant producte');
    });
  });

  test('getItemById returns the matching inventory item', () async {
    when(mockApi.get(ApiConfig.inventory)).thenAnswer((_) async => {
          'statusCode': 200,
          'body': [itemJson(id: 42)],
        });

    await provider.fetchInventory();

    final item = provider.getItemById(42);

    expect(item, isNotNull);
    expect(item?.id, 42);
  });
}
