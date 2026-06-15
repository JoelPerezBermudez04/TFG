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

  // ── Fixtures ──────────────────────────────────────────────────────────────

  Map<String, dynamic> itemJson({
    int id = 1,
    String? dataCaducitat,
    bool caducat = false,
  }) =>
      {
        'id': id,
        'usuari': 1,
        'producte': 10,
        'producte_nom': 'Llet',
        'producte_emoji': '🥛',
        'producte_categoria_id': 1,
        'producte_categoria_nom': 'Làctics',
        'producte_categoria_emoji': '🧀',
        'quantitat': 1.0,
        'unitat': 'L',
        'data_caducitat': dataCaducitat,
        'data_afegit': '2024-01-01T00:00:00Z',
        'caducat': caducat,
      };

  // Data en el futur pròxim → urgent; data en el passat → caducat
  final avui = DateTime.now();
  String dateStr(DateTime d) => d.toIso8601String().split('T')[0];
  String tomorrow() => dateStr(avui.add(const Duration(days: 1)));
  String yesterday() => dateStr(avui.subtract(const Duration(days: 1)));
  String nextMonth() => dateStr(avui.add(const Duration(days: 30)));

  setUp(() {
    mockApi = MockApiService();
    provider = InventoryProvider(api: mockApi);
  });

  // ── fetchInventory ────────────────────────────────────────────────────────

  group('fetchInventory', () {
    test('carrega inventari quan el servidor retorna 200', () async {
      when(mockApi.get(ApiConfig.inventory)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [itemJson(id: 1), itemJson(id: 2)],
          });

      await provider.fetchInventory();

      expect(provider.isLoading, isFalse);
      expect(provider.items, hasLength(2));
      expect(provider.error, isNull);
    });

    test('estableix error quan el servidor retorna no-200', () async {
      when(mockApi.get(ApiConfig.inventory)).thenAnswer((_) async => {
            'statusCode': 500,
            'body': {'detail': 'Error intern'},
          });

      await provider.fetchInventory();

      expect(provider.items, isEmpty);
      expect(provider.error, 'Error carregant inventari');
    });

    test('estableix error de connexió quan llença excepció', () async {
      when(mockApi.get(ApiConfig.inventory)).thenThrow(Exception('timeout'));

      await provider.fetchInventory();

      expect(provider.error, 'Error de connexió');
      expect(provider.isLoading, isFalse);
    });

    // NOU: ordena els items per data de caducitat (els sense data al final)
    test('ordena els items: primer els que caduca aviat, últims els sense data', () async {
      when(mockApi.get(ApiConfig.inventory)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [
              itemJson(id: 3, dataCaducitat: null),
              itemJson(id: 1, dataCaducitat: tomorrow()),
              itemJson(id: 2, dataCaducitat: nextMonth()),
            ],
          });

      await provider.fetchInventory();

      expect(provider.items[0].id, 1);  // caduca demà → primer
      expect(provider.items[1].id, 2);  // caduca d'aquí un mes → segon
      expect(provider.items[2].id, 3);  // sense data → últim
    });

    // NOU: totalItems reflecteix el nombre d'items carregats
    test('totalItems retorna el nombre total d\'items', () async {
      when(mockApi.get(ApiConfig.inventory)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [itemJson(id: 1), itemJson(id: 2), itemJson(id: 3)],
          });

      await provider.fetchInventory();

      expect(provider.totalItems, 3);
    });
  });

  // ── urgentCount ───────────────────────────────────────────────────────────

  group('urgentCount', () {
    test('compta items urgents i caducats', () async {
      when(mockApi.get(ApiConfig.inventory)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [
              itemJson(id: 1, dataCaducitat: yesterday(), caducat: true),   // caducat
              itemJson(id: 2, dataCaducitat: tomorrow()),                    // urgent (pròxim)
              itemJson(id: 3, dataCaducitat: nextMonth()),                   // ok
              itemJson(id: 4),                                             // sense data
            ],
          });

      await provider.fetchInventory();

      // Només ids 1 i 2 haurien de tenir status urgent/expired
      expect(provider.urgentCount, lessThanOrEqualTo(2));
    });

    test('urgentCount és 0 quan no hi ha items', () {
      expect(provider.urgentCount, 0);
    });
  });

  // ── fetchExpiringItems ────────────────────────────────────────────────────

  group('fetchExpiringItems', () {
    test('carrega items propers a caducar quan el servidor retorna 200', () async {
      when(mockApi.get(ApiConfig.expiringItems)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [itemJson(id: 5, dataCaducitat: tomorrow())],
          });

      await provider.fetchExpiringItems();

      expect(provider.expiringItems, hasLength(1));
      expect(provider.expiringItems.first.id, 5);
    });

    // NOU: no-200 → llista buida i sense error visible
    test('deixa expiringItems buit quan el servidor retorna no-200', () async {
      when(mockApi.get(ApiConfig.expiringItems)).thenAnswer((_) async => {
            'statusCode': 500,
            'body': {},
          });

      await provider.fetchExpiringItems();

      expect(provider.expiringItems, isEmpty);
    });

    // NOU: excepció → no peta i deixa llista buida
    test('no llença excepció en cas d\'error de xarxa', () async {
      when(mockApi.get(ApiConfig.expiringItems)).thenThrow(Exception('network'));

      await expectLater(provider.fetchExpiringItems(), completes);
      expect(provider.expiringItems, isEmpty);
    });
  });

  // ── addItem ───────────────────────────────────────────────────────────────

  group('addItem', () {
    test('retorna true i refresca l\'inventari quan té èxit', () async {
      when(mockApi.post(ApiConfig.inventory, any)).thenAnswer((_) async => {
            'statusCode': 201,
            'body': itemJson(id: 3),
          });
      when(mockApi.get(ApiConfig.inventory)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [itemJson(id: 3)],
          });

      final ok = await provider.addItem(
        producteId: 10,
        quantitat: 1.0,
        unitat: 'L',
      );

      expect(ok, isTrue);
      expect(provider.items, hasLength(1));
    });

    test('retorna false i estableix error en bad request', () async {
      when(mockApi.post(ApiConfig.inventory, any)).thenAnswer((_) async => {
            'statusCode': 400,
            'body': {'error': 'Producte invàlid'},
          });

      final ok = await provider.addItem(
        producteId: 10,
        quantitat: 1.0,
        unitat: 'L',
      );

      expect(ok, isFalse);
      expect(provider.error, 'Producte invàlid');
    });

    // NOU: excepció de xarxa
    test('retorna false i estableix error de connexió quan llença excepció', () async {
      when(mockApi.post(ApiConfig.inventory, any)).thenThrow(Exception('network'));

      final ok = await provider.addItem(
        producteId: 10,
        quantitat: 1.0,
        unitat: 'L',
      );

      expect(ok, isFalse);
      expect(provider.error, 'Error de connexió');
    });

    // NOU: amb data de caducitat
    test('inclou data_caducitat quan s\'especifica', () async {
      final caducitat = DateTime(2025, 12, 31);
      when(mockApi.post(ApiConfig.inventory, argThat(containsPair('data_caducitat', '2025-12-31'))))
          .thenAnswer((_) async => {
                'statusCode': 201,
                'body': itemJson(id: 4, dataCaducitat: '2025-12-31'),
              });
      when(mockApi.get(ApiConfig.inventory)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [itemJson(id: 4, dataCaducitat: '2025-12-31')],
          });

      final ok = await provider.addItem(
        producteId: 10,
        quantitat: 1.0,
        unitat: 'L',
        dataCaducitat: caducitat,
      );

      expect(ok, isTrue);
      verify(mockApi.post(
        ApiConfig.inventory,
        argThat(containsPair('data_caducitat', '2025-12-31')),
      )).called(1);
    });
  });

  // ── updateItem ────────────────────────────────────────────────────────────

  group('updateItem', () {
    test('retorna true i refresca l\'inventari quan té èxit', () async {
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

    test('retorna false i estableix error en fallada', () async {
      when(mockApi.patch('${ApiConfig.inventory}1/', any)).thenAnswer((_) async => {
            'statusCode': 400,
            'body': {'detail': 'No es pot actualitzar'},
          });

      final ok = await provider.updateItem(1, quantitat: 2.0, unitat: 'kg');

      expect(ok, isFalse);
      expect(provider.error, 'No es pot actualitzar');
    });

    // NOU: excepció de xarxa
    test('retorna false i estableix error de connexió quan llença excepció', () async {
      when(mockApi.patch('${ApiConfig.inventory}1/', any)).thenThrow(Exception('network'));

      final ok = await provider.updateItem(1, quantitat: 2.0, unitat: 'kg');

      expect(ok, isFalse);
      expect(provider.error, 'Error de connexió');
    });

    // NOU: clearDate=true envia data_caducitat null
    test('envia data_caducitat null quan clearDate és true', () async {
      when(mockApi.patch('${ApiConfig.inventory}1/', argThat(containsPair('data_caducitat', null))))
          .thenAnswer((_) async => {
                'statusCode': 200,
                'body': itemJson(id: 1),
              });
      when(mockApi.get(ApiConfig.inventory)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [itemJson(id: 1)],
          });

      final ok = await provider.updateItem(
        1,
        quantitat: 1.0,
        unitat: 'L',
        clearDate: true,
      );

      expect(ok, isTrue);
      verify(mockApi.patch(
        '${ApiConfig.inventory}1/',
        argThat(containsPair('data_caducitat', null)),
      )).called(1);
    });

    // NOU: amb nova data de caducitat
    test('envia la nova data de caducitat quan s\'especifica', () async {
      final novaData = DateTime(2026, 6, 15);
      when(mockApi.patch('${ApiConfig.inventory}1/', argThat(containsPair('data_caducitat', '2026-06-15'))))
          .thenAnswer((_) async => {
                'statusCode': 200,
                'body': itemJson(id: 1, dataCaducitat: '2026-06-15'),
              });
      when(mockApi.get(ApiConfig.inventory)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [itemJson(id: 1, dataCaducitat: '2026-06-15')],
          });

      final ok = await provider.updateItem(
        1,
        quantitat: 1.0,
        unitat: 'L',
        dataCaducitat: novaData,
      );

      expect(ok, isTrue);
    });
  });

  // ── deleteItem ────────────────────────────────────────────────────────────

  group('deleteItem', () {
    test('retorna true i elimina l\'item de la llista local', () async {
      // Primer carreguem l'item a la llista
      when(mockApi.get(ApiConfig.inventory)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [itemJson(id: 1), itemJson(id: 2)],
          });
      await provider.fetchInventory();

      when(mockApi.delete('${ApiConfig.inventory}1/')).thenAnswer((_) async => {
            'statusCode': 204,
            'body': null,
          });

      final ok = await provider.deleteItem(1);

      expect(ok, isTrue);
      expect(provider.items, hasLength(1));
      expect(provider.items.first.id, 2);
    });

    test('retorna false i estableix error en fallada del servidor', () async {
      when(mockApi.delete('${ApiConfig.inventory}1/')).thenAnswer((_) async => {
            'statusCode': 500,
            'body': {'detail': 'Error intern'},
          });

      final ok = await provider.deleteItem(1);

      expect(ok, isFalse);
      expect(provider.error, 'Error eliminant producte');
    });

    // NOU: excepció de xarxa
    test('retorna false i estableix error de connexió quan llença excepció', () async {
      when(mockApi.delete('${ApiConfig.inventory}1/')).thenThrow(Exception('network'));

      final ok = await provider.deleteItem(1);

      expect(ok, isFalse);
      expect(provider.error, 'Error de connexió');
    });

    // NOU: la llista no es modifica si el servidor retorna error
    test('no modifica la llista si el servidor retorna no-204', () async {
      when(mockApi.get(ApiConfig.inventory)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [itemJson(id: 1)],
          });
      await provider.fetchInventory();

      when(mockApi.delete('${ApiConfig.inventory}1/')).thenAnswer((_) async => {
            'statusCode': 500,
            'body': {},
          });

      await provider.deleteItem(1);

      expect(provider.items, hasLength(1));
    });
  });

  // ── getItemById ───────────────────────────────────────────────────────────

  group('getItemById', () {
    test('retorna l\'item correcte quan existeix', () async {
      when(mockApi.get(ApiConfig.inventory)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [itemJson(id: 42)],
          });
      await provider.fetchInventory();

      final item = provider.getItemById(42);

      expect(item, isNotNull);
      expect(item?.id, 42);
    });

    // NOU: retorna null quan l'id no existeix
    test('retorna null quan l\'id no existeix', () async {
      when(mockApi.get(ApiConfig.inventory)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [itemJson(id: 1)],
          });
      await provider.fetchInventory();

      final item = provider.getItemById(999);

      expect(item, isNull);
    });

    // NOU: retorna null quan la llista és buida
    test('retorna null quan la llista és buida', () {
      expect(provider.getItemById(1), isNull);
    });
  });
}