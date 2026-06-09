import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:frontend/features/inventari/providers/inventory_provider.dart';
import 'package:frontend/features/products/providers/products_provider.dart';
import 'package:frontend/features/products/models/product_model.dart';
import 'package:frontend/features/inventari/screens/add_product_screen.dart';

import 'add_product_screen_test.mocks.dart';

@GenerateMocks([InventoryProvider, ProductsProvider])
void main() {
  late MockInventoryProvider mockInventory;
  late MockProductsProvider mockProducts;

  final fakeCategories = [
    Category(id: 1, nom: 'Làctics', emoji: '🧀'),
    Category(id: 2, nom: 'Fruites', emoji: '🍎'),
  ];

  final fakeProducts = [
    Product(id: 1, nom: 'Llet', categoriaId: 1, categoriaNom: 'Làctics', emoji: '🥛'),
    Product(id: 2, nom: 'Iogurt', categoriaId: 1, categoriaNom: 'Làctics', emoji: '🫙'),
  ];

  void setupMocks({
    List<Category> categories = const [],
    List<Product> products = const [],
    bool isLoading = false,
  }) {
    when(mockInventory.isLoading).thenReturn(isLoading);
    when(mockInventory.error).thenReturn(null);
    when(mockInventory.addListener(any)).thenReturn(null);
    when(mockInventory.removeListener(any)).thenReturn(null);

    when(mockProducts.categories).thenReturn(categories);
    when(mockProducts.products).thenReturn(products);
    when(mockProducts.isLoading).thenReturn(false);
    when(mockProducts.error).thenReturn(null);
    when(mockProducts.fetchCategories()).thenAnswer((_) async {});
    when(mockProducts.fetchProducts()).thenAnswer((_) async {});
    when(mockProducts.fetchProducts(cerca: anyNamed('cerca')))
        .thenAnswer((_) async {});
    when(mockProducts.fetchProducts(categoriaId: anyNamed('categoriaId')))
        .thenAnswer((_) async {});
    when(mockProducts.clearProducts()).thenReturn(null);
    when(mockProducts.addListener(any)).thenReturn(null);
    when(mockProducts.removeListener(any)).thenReturn(null);
  }

  Widget buildSubject() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<InventoryProvider>.value(value: mockInventory),
          ChangeNotifierProvider<ProductsProvider>.value(value: mockProducts),
        ],
        child: const AddProductScreen(),
      ),
    );
  }

  setUp(() {
    mockInventory = MockInventoryProvider();
    mockProducts = MockProductsProvider();
  });

  group('AddProductScreen - Step 0: selecció de producte', () {
    testWidgets('mostra el títol "Selecciona un producte"', (tester) async {
      setupMocks(categories: fakeCategories);
      await tester.pumpWidget(buildSubject());

      expect(
        find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Selecciona un producte')),
        findsOneWidget,
      );
    });

    testWidgets('mostra el camp de cerca', (tester) async {
      setupMocks(categories: fakeCategories);
      await tester.pumpWidget(buildSubject());

      expect(find.widgetWithText(TextField, 'Cercar producte...'), findsOneWidget);
    });

    testWidgets('mostra les categories en un GridView', (tester) async {
      setupMocks(categories: fakeCategories);
      await tester.pumpWidget(buildSubject());

      expect(find.text('Làctics'), findsOneWidget);
      expect(find.text('Fruites'), findsOneWidget);
    });

    testWidgets('cerca amb menys de 2 caràcters no crida fetchProducts',
        (tester) async {
      setupMocks(categories: fakeCategories);
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextField, 'Cercar producte...'), 'L');
      await tester.pump();

      verifyNever(mockProducts.fetchProducts(cerca: anyNamed('cerca')));
    });

    testWidgets('cerca amb 2+ caràcters crida fetchProducts', (tester) async {
      setupMocks(categories: fakeCategories);
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextField, 'Cercar producte...'), 'Ll');
      await tester.pump();

      verify(mockProducts.fetchProducts(cerca: 'Ll')).called(1);
    });

    testWidgets('mostra resultats de cerca quan hi ha productes', (tester) async {
      setupMocks(categories: fakeCategories, products: fakeProducts);
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextField, 'Cercar producte...'), 'Ll');
      await tester.pump();

      expect(find.text('Llet'), findsOneWidget);
      expect(find.text('Iogurt'), findsOneWidget);
    });

    testWidgets('mostra missatge si la cerca no troba res', (tester) async {
      setupMocks(categories: fakeCategories, products: []);
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextField, 'Cercar producte...'), 'xyz');
      await tester.pump();

      expect(find.text('No s\'han trobat productes'), findsOneWidget);
    });

    testWidgets('la X del camp de cerca apareix quan hi ha text', (tester) async {
      setupMocks(categories: fakeCategories);
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextField, 'Cercar producte...'), 'Ll');
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });
  });


  group('AddProductScreen - Step 1: formulari d\'afegir', () {
    Future<void> selectProduct(WidgetTester tester) async {
      setupMocks(categories: fakeCategories, products: fakeProducts);
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextField, 'Cercar producte...'), 'Ll');
      await tester.pump();

      await tester.tap(find.text('Llet'));
      await tester.pump();
    }

    testWidgets('mostra el nom del producte seleccionat al títol', (tester) async {
      await selectProduct(tester);

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Llet')),
        findsOneWidget,
      );
    });

    testWidgets('mostra el camp de quantitat amb valor 1 per defecte',
        (tester) async {
      await selectProduct(tester);

      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller?.text, '1');
    });

    testWidgets('mostra el botó "Afegir al rebost"', (tester) async {
      await selectProduct(tester);

      expect(find.widgetWithText(ElevatedButton, 'Afegir al rebost'),
          findsOneWidget);
    });

    testWidgets('mostra "Seleccionar data (opcional)" quan no hi ha data',
        (tester) async {
      await selectProduct(tester);

      expect(find.text('Seleccionar data (opcional)'), findsOneWidget);
    });

    testWidgets('mostra el botó enrere per tornar al step 0', (tester) async {
      await selectProduct(tester);

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('tap al botó enrere torna al step 0', (tester) async {
      await selectProduct(tester);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();

      expect(
        find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Selecciona un producte')),
        findsOneWidget,
      );
    });

    testWidgets('mostra error si la quantitat és buida', (tester) async {
      await selectProduct(tester);

      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Afegir al rebost'));
      await tester.pump();

      expect(find.text('Obligatori'), findsOneWidget);
    });

    testWidgets('mostra error si la quantitat és 0 o negativa', (tester) async {
      await selectProduct(tester);

      await tester.enterText(find.byType(TextFormField), '0');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Afegir al rebost'));
      await tester.pump();

      expect(find.text('Valor invàlid'), findsOneWidget);
    });

    testWidgets('no crida addItem si la validació falla', (tester) async {
      await selectProduct(tester);

      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Afegir al rebost'));
      await tester.pump();

      verifyNever(mockInventory.addItem(
        producteId: anyNamed('producteId'),
        quantitat: anyNamed('quantitat'),
        unitat: anyNamed('unitat'),
      ));
    });

    testWidgets('crida addItem amb les dades correctes', (tester) async {
      when(mockInventory.addItem(
        producteId: 1,
        quantitat: 2.0,
        unitat: anyNamed('unitat'),
        dataCaducitat: null,
      )).thenAnswer((_) async => true);

      await selectProduct(tester);

      await tester.enterText(find.byType(TextFormField), '2');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Afegir al rebost'));
      await tester.pump();

      verify(mockInventory.addItem(
        producteId: 1,
        quantitat: 2.0,
        unitat: anyNamed('unitat'),
        dataCaducitat: null,
      )).called(1);
    });

    testWidgets('mostra CircularProgressIndicator mentre isLoading és true',
        (tester) async {
      setupMocks(categories: fakeCategories, products: fakeProducts, isLoading: true);
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextField, 'Cercar producte...'), 'Ll');
      await tester.pump();
      await tester.tap(find.text('Llet'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });


  group('Product.suggestedExpiryDate', () {
    test('retorna null si diesCaducitatAprox és null', () {
      final p = Product(
          id: 1, nom: 'Test', categoriaId: 1, emoji: '🛒',
          diesCaducitatAprox: null);
      expect(p.suggestedExpiryDate, isNull);
    });

    test('retorna data futura si diesCaducitatAprox té valor', () {
      final p = Product(
          id: 1, nom: 'Test', categoriaId: 1, emoji: '🛒',
          diesCaducitatAprox: 7);
      final expected = DateTime.now().add(const Duration(days: 7));
      expect(p.suggestedExpiryDate!.day, expected.day);
      expect(p.suggestedExpiryDate!.month, expected.month);
    });
  });

  group('Category.fromJson', () {
    test('mapeja tots els camps correctament', () {
      final json = {'id': 1, 'nom': 'Làctics', 'emoji': '🧀'};
      final cat = Category.fromJson(json);
      expect(cat.id, 1);
      expect(cat.nom, 'Làctics');
      expect(cat.emoji, '🧀');
    });

    test('usa emoji per defecte si no ve al JSON', () {
      final json = {'id': 1, 'nom': 'Sense emoji'};
      final cat = Category.fromJson(json);
      expect(cat.emoji, '🛒');
    });
  });

  group('Product.fromJson', () {
    test('mapeja tots els camps correctament', () {
      final json = {
        'id': 5,
        'nom': 'Llet',
        'categoria': 1,
        'categoria_nom': 'Làctics',
        'emoji': '🥛',
        'imatge_url': 'https://example.com/llet.png',
        'dies_caducitat_aprox': 7,
      };
      final p = Product.fromJson(json);
      expect(p.id, 5);
      expect(p.nom, 'Llet');
      expect(p.categoriaId, 1);
      expect(p.categoriaNom, 'Làctics');
      expect(p.emoji, '🥛');
      expect(p.imatgeUrl, 'https://example.com/llet.png');
      expect(p.diesCaducitatAprox, 7);
    });

    test('usa emoji per defecte si no ve al JSON', () {
      final json = {
        'id': 1, 'nom': 'Test', 'categoria': 1,
        'dies_caducitat_aprox': null,
      };
      final p = Product.fromJson(json);
      expect(p.emoji, '🛒');
      expect(p.diesCaducitatAprox, isNull);
    });
  });
}