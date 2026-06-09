import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/inventari/providers/inventory_provider.dart';
import 'package:frontend/features/inventari/models/inventory_item_model.dart';
import 'package:frontend/features/inventari/screens/inventory_screen.dart';

import 'inventory_screen_test.mocks.dart';

@GenerateMocks([AuthProvider, InventoryProvider])
void main() {
  late MockAuthProvider mockAuth;
  late MockInventoryProvider mockInventory;

  InventoryItem makeItem({
    int id = 1,
    String nom = 'Llet',
    String emoji = '🥛',
    DateTime? dataCaducitat,
    bool caducat = false,
    String? categoriaNom,
    int? categoriaId,
  }) {
    return InventoryItem(
      id: id,
      usuari: 1,
      producte: id,
      producteNom: nom,
      producteEmoji: emoji,
      producteCategoriaId: categoriaId,
      producteCategoriaNom: categoriaNom,
      producteCategoriaEmoji: categoriaNom != null ? '🥛' : null,
      quantitat: 1.0,
      unitat: 'unitat',
      dataCaducitat: dataCaducitat,
      dataAfegit: DateTime(2025, 1, 1),
      caducat: caducat,
    );
  }

  void setupMocks({List<InventoryItem> items = const []}) {
    when(mockAuth.user).thenReturn(null);
    when(mockAuth.isAuthenticated).thenReturn(true);
    when(mockAuth.addListener(any)).thenReturn(null);
    when(mockAuth.removeListener(any)).thenReturn(null);

    when(mockInventory.items).thenReturn(items);
    when(mockInventory.isLoading).thenReturn(false);
    when(mockInventory.error).thenReturn(null);
    when(mockInventory.fetchInventory()).thenAnswer((_) async {});
    when(mockInventory.addListener(any)).thenReturn(null);
    when(mockInventory.removeListener(any)).thenReturn(null);
  }

  Widget buildSubject() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ChangeNotifierProvider<InventoryProvider>.value(value: mockInventory),
        ],
        child: const InventoryScreen(),
      ),
    );
  }

  setUp(() {
    mockAuth = MockAuthProvider();
    mockInventory = MockInventoryProvider();
  });

  group('InventoryScreen - renderització inicial', () {
    testWidgets('mostra el títol El meu rebost', (tester) async {
      setupMocks();
      await tester.pumpWidget(buildSubject());

      expect(find.text('El meu rebost'), findsOneWidget);
    });

    testWidgets('mostra el camp de cerca', (tester) async {
      setupMocks();
      await tester.pumpWidget(buildSubject());

      expect(find.widgetWithText(TextField, 'Cercar productes...'), findsOneWidget);
    });

    testWidgets('mostra els filtres Tot, Fresc, Aviat i Caducat', (tester) async {
      setupMocks();
      await tester.pumpWidget(buildSubject());

      expect(find.text('Tot'), findsOneWidget);
      expect(find.text('Fresc'), findsOneWidget);
      expect(find.text('Aviat'), findsOneWidget);
      expect(find.text('Caducat'), findsOneWidget);
    });
  });

  group('InventoryScreen - estat de càrrega', () {
    testWidgets('mostra CircularProgressIndicator quan isLoading és true', (tester) async {
      setupMocks();
      when(mockInventory.isLoading).thenReturn(true);
      await tester.pumpWidget(buildSubject());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('InventoryScreen - rebost buit', () {
    testWidgets('mostra l\'estat buit quan no hi ha items', (tester) async {
      setupMocks(items: []);
      await tester.pumpWidget(buildSubject());

      expect(find.text('El rebost està buit'), findsOneWidget);
      expect(find.text('Afegeix productes per començar'), findsOneWidget);
    });

    testWidgets('mostra el comptador a 0 productes', (tester) async {
      setupMocks(items: []);
      await tester.pumpWidget(buildSubject());

      expect(find.text('0 productes'), findsOneWidget);
    });
  });

  group('InventoryScreen - llistat d\'items', () {
    testWidgets('mostra els productes a la llista', (tester) async {
      setupMocks(items: [
        makeItem(id: 1, nom: 'Llet'),
        makeItem(id: 2, nom: 'Pa'),
      ]);
      await tester.pumpWidget(buildSubject());

      expect(find.text('Llet'), findsOneWidget);
      expect(find.text('Pa'), findsOneWidget);
    });

    testWidgets('mostra el comptador correcte amb 1 producte (singular)', (tester) async {
      setupMocks(items: [makeItem()]);
      await tester.pumpWidget(buildSubject());

      expect(find.text('1 producte'), findsOneWidget);
    });

    testWidgets('mostra el comptador correcte amb múltiples productes (plural)', (tester) async {
      setupMocks(items: [makeItem(id: 1), makeItem(id: 2)]);
      await tester.pumpWidget(buildSubject());

      expect(find.text('2 productes'), findsOneWidget);
    });
  });

  group('InventoryScreen - cerca', () {
    testWidgets('filtra els productes per nom en cercar', (tester) async {
      setupMocks(items: [
        makeItem(id: 1, nom: 'Llet'),
        makeItem(id: 2, nom: 'Pa'),
      ]);
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextField, 'Cercar productes...'), 'llet');
      await tester.pump();

      expect(find.text('Llet'), findsOneWidget);
      expect(find.text('Pa'), findsNothing);
    });

    testWidgets('mostra la X per esborrar la cerca quan hi ha text', (tester) async {
      setupMocks(items: [makeItem()]);
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextField, 'Cercar productes...'), 'abc');
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('tap a la X esborra la cerca', (tester) async {
      setupMocks(items: [makeItem()]);
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextField, 'Cercar productes...'), 'abc');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      final field = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Cercar productes...'),
      );
      expect(field.controller?.text ?? '', isEmpty);
    });
  });

  group('InventoryScreen - filtres', () {
    Finder filterChip(String label) => find.widgetWithText(FilterChip, label);

    testWidgets('filtre Fresc mostra només productes frescos', (tester) async {
      setupMocks(items: [
        makeItem(id: 1, nom: 'Llet',
            dataCaducitat: DateTime.now().add(const Duration(days: 30))),
        makeItem(id: 2, nom: 'Iogurt',
            dataCaducitat: DateTime.now().subtract(const Duration(days: 1))),
      ]);
      await tester.pumpWidget(buildSubject());

      await tester.tap(filterChip('Fresc'));
      await tester.pump();

      expect(find.text('Llet'), findsOneWidget);
      expect(find.text('Iogurt'), findsNothing);
    });

    testWidgets('filtre Caducat mostra només productes caducats', (tester) async {
      setupMocks(items: [
        makeItem(id: 1, nom: 'Llet',
            dataCaducitat: DateTime.now().add(const Duration(days: 30))),
        makeItem(id: 2, nom: 'Iogurt',
            dataCaducitat: DateTime.now().subtract(const Duration(days: 1))),
      ]);
      await tester.pumpWidget(buildSubject());

      await tester.tap(filterChip('Caducat'));
      await tester.pump();

      expect(find.text('Llet'), findsNothing);
      expect(find.text('Iogurt'), findsOneWidget);
    });
  });

  group('InventoryScreen - vista grid/llista', () {
    testWidgets('per defecte mostra la vista de llista', (tester) async {
      setupMocks(items: [makeItem()]);
      await tester.pumpWidget(buildSubject());

      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
    });

    testWidgets('tap a grid canvia a vista de graella', (tester) async {
      setupMocks(items: [makeItem()]);
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pump();

      expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);
    });
  });

  group('InventoryScreen - ordenació', () {
    testWidgets('tap a l\'icona de sort obre el bottomSheet', (tester) async {
      setupMocks(items: [makeItem()]);
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byIcon(Icons.sort_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Ordenar per'), findsOneWidget);
      expect(find.text('Data de caducitat'), findsOneWidget);
      expect(find.text('Nom (A-Z)'), findsOneWidget);
      expect(find.text('Categoria'), findsOneWidget);
    });
  });
}