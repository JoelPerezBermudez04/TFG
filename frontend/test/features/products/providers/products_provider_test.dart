import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/features/products/providers/products_provider.dart';
import 'package:frontend/features/products/models/product_model.dart';

import 'products_provider_test.mocks.dart';

@GenerateMocks([ApiService])
void main() {
  late MockApiService mockApi;
  late ProductsProvider provider;

  final productJson = {
    'id': 1,
    'nom': 'Tomàquet',
    'categoria': 2,
    'categoria_nom': 'Verdures',
    'emoji': '🍅',
    'imatge_url': null,
    'dies_caducitat_aprox': 7,
  };

  final categoryJson = {'id': 2, 'nom': 'Verdures', 'emoji': '🥦'};

  setUp(() {
    mockApi = MockApiService();
    provider = ProductsProvider.withApi(mockApi);
  });

  // ─────────────────────────────────────────────
  // fetchProducts
  // ─────────────────────────────────────────────
  group('fetchProducts', () {
    test('carrega productes correctament amb resposta 200', () async {
      when(mockApi.get(any)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [productJson],
          });

      await provider.fetchProducts();

      expect(provider.isLoading, isFalse);
      expect(provider.products, hasLength(1));
      expect(provider.products.first.nom, 'Tomàquet');
      expect(provider.error, isNull);
    });

    test('estableix error quan el servidor falla', () async {
      when(mockApi.get(any)).thenAnswer((_) async => {
            'statusCode': 500,
            'body': {},
          });

      await provider.fetchProducts();

      expect(provider.products, isEmpty);
      expect(provider.error, isNotNull);
    });

    test('estableix error de connexió en cas d\'excepció', () async {
      when(mockApi.get(any)).thenThrow(Exception('no internet'));

      await provider.fetchProducts();

      expect(provider.error, 'Error de connexió');
    });

    test('construeix la URL amb el paràmetre cerca', () async {
      when(mockApi.get(argThat(contains('cerca=')))).thenAnswer((_) async => {
            'statusCode': 200,
            'body': <dynamic>[],
          });

      await provider.fetchProducts(cerca: 'llet');

      final captured = verify(mockApi.get(captureAny)).captured.single as String;
      expect(captured, contains('cerca=llet'));
    });

    test('construeix la URL amb el paràmetre categoria', () async {
      when(mockApi.get(argThat(contains('categoria=')))).thenAnswer((_) async => {
            'statusCode': 200,
            'body': <dynamic>[],
          });

      await provider.fetchProducts(categoriaId: 3);

      final captured = verify(mockApi.get(captureAny)).captured.single as String;
      expect(captured, contains('categoria=3'));
    });

    test('combina cerca i categoria a la URL', () async {
      when(mockApi.get(any)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': <dynamic>[],
          });

      await provider.fetchProducts(cerca: 'arròs', categoriaId: 5);

      final captured = verify(mockApi.get(captureAny)).captured.single as String;
      expect(captured, contains('cerca='));
      expect(captured, contains('categoria=5'));
    });
  });

  // ─────────────────────────────────────────────
  // fetchCategories
  // ─────────────────────────────────────────────
  group('fetchCategories', () {
    test('carrega categories correctament', () async {
      when(mockApi.get(any)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [categoryJson],
          });

      await provider.fetchCategories();

      expect(provider.categories, hasLength(1));
      expect(provider.categories.first.nom, 'Verdures');
    });

    test('no modifica les categories si el servidor falla (silenciós)', () async {
      when(mockApi.get(any)).thenAnswer((_) async => {
            'statusCode': 404,
            'body': {},
          });

      await provider.fetchCategories();

      expect(provider.categories, isEmpty);
    });

    test('no llança excepció si hi ha error de xarxa', () async {
      when(mockApi.get(any)).thenThrow(Exception('timeout'));

      expect(() => provider.fetchCategories(), returnsNormally);
    });
  });

  // ─────────────────────────────────────────────
  // clearProducts
  // ─────────────────────────────────────────────
  group('clearProducts', () {
    test('buida la llista de productes', () async {
      when(mockApi.get(any)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [productJson],
          });
      await provider.fetchProducts();
      expect(provider.products, hasLength(1));

      provider.clearProducts();

      expect(provider.products, isEmpty);
    });
  });

  // ─────────────────────────────────────────────
  // getProductById
  // ─────────────────────────────────────────────
  group('getProductById', () {
    setUp(() async {
      when(mockApi.get(any)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [productJson],
          });
      await provider.fetchProducts();
    });

    test('retorna el producte si existeix a la llista local', () {
      final p = provider.getProductById(1);

      expect(p, isNotNull);
      expect(p!.nom, 'Tomàquet');
    });

    test('retorna null si no existeix', () {
      final p = provider.getProductById(999);

      expect(p, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // fetchProductById
  // ─────────────────────────────────────────────
  group('fetchProductById', () {
    test('retorna el producte local si ja existeix (sense crida a l\'API)', () async {
      when(mockApi.get(any)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': [productJson],
          });
      await provider.fetchProducts();

      // Reseta el mock per verificar que no es torna a cridar
      reset(mockApi);

      final p = await provider.fetchProductById(1);

      expect(p, isNotNull);
      verifyNever(mockApi.get(any));
    });

    test('crida l\'API si el producte no és a la llista local', () async {
      when(mockApi.get('/productes/99/')).thenAnswer((_) async => {
            'statusCode': 200,
            'body': {...productJson, 'id': 99, 'nom': 'Albergínia'},
          });

      final p = await provider.fetchProductById(99);

      expect(p, isNotNull);
      expect(p!.nom, 'Albergínia');
    });

    test('retorna null si l\'API no troba el producte', () async {
      when(mockApi.get('/productes/999/')).thenAnswer((_) async => {
            'statusCode': 404,
            'body': {'error': 'No trobat'},
          });

      final p = await provider.fetchProductById(999);

      expect(p, isNull);
    });

    test('retorna null si hi ha error de xarxa', () async {
      when(mockApi.get(any)).thenThrow(Exception('timeout'));

      final p = await provider.fetchProductById(50);

      expect(p, isNull);
    });
  });
}