import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:frontend/features/inventari/providers/inventory_provider.dart';
import 'package:frontend/features/inventari/models/inventory_item_model.dart';
import 'package:frontend/features/inventari/screens/product_detail_screen.dart';

import 'product_detail_screen_test.mocks.dart';

@GenerateMocks([InventoryProvider])
void main() {
  late MockInventoryProvider mockInventory;

  InventoryItem makeItem({
    int id = 1,
    String nom = 'Llet',
    double quantitat = 1.0,
    String unitat = 'unitat',
    DateTime? dataCaducitat,
    bool caducat = false,
  }) {
    return InventoryItem(
      id: id,
      usuari: 1,
      producte: 1,
      producteNom: nom,
      producteEmoji: '🥛',
      quantitat: quantitat,
      unitat: unitat,
      dataCaducitat: dataCaducitat,
      dataAfegit: DateTime(2025, 1, 1),
      caducat: caducat,
    );
  }

  setUp(() {
    mockInventory = MockInventoryProvider();
    when(mockInventory.isLoading).thenReturn(false);
    when(mockInventory.error).thenReturn(null);
    when(mockInventory.addListener(any)).thenReturn(null);
    when(mockInventory.removeListener(any)).thenReturn(null);
  });

  Widget buildSubject(InventoryItem? item) {
    when(mockInventory.getItemById(1)).thenReturn(item);
    return MaterialApp(
      home: ChangeNotifierProvider<InventoryProvider>.value(
        value: mockInventory,
        child: const ProductDetailScreen(itemId: 1),
      ),
    );
  }

  group('ProductDetailScreen - producte no trobat', () {
    testWidgets('mostra missatge si el producte no existeix', (tester) async {
      await tester.pumpWidget(buildSubject(null));

      expect(find.text('Producte no trobat'), findsOneWidget);
    });
  });

  group('ProductDetailScreen - renderització', () {
    testWidgets('mostra el nom del producte', (tester) async {
      await tester.pumpWidget(buildSubject(makeItem(nom: 'Llet')));

      expect(find.text('Llet'), findsOneWidget);
    });

    testWidgets('mostra la quantitat correcta (enter sense decimals)', (tester) async {
      await tester.pumpWidget(buildSubject(makeItem(quantitat: 1.0, unitat: 'unitat')));

      expect(find.text('1 unitat'), findsOneWidget);
    });

    testWidgets('mostra la quantitat en plural quan quantitat > 1', (tester) async {
      await tester.pumpWidget(buildSubject(makeItem(quantitat: 3.0, unitat: 'unitat')));

      expect(find.text('3 unitats'), findsOneWidget);
    });

    testWidgets('mostra "No definida" si no hi ha data de caducitat', (tester) async {
      await tester.pumpWidget(buildSubject(makeItem(dataCaducitat: null)));

      expect(find.text('No definida'), findsOneWidget);
    });

    testWidgets('mostra la data de caducitat formatada', (tester) async {
      await tester.pumpWidget(buildSubject(
        makeItem(dataCaducitat: DateTime(2025, 12, 31)),
      ));

      expect(find.text('31/12/2025'), findsAtLeastNWidgets(1));
    });

    testWidgets('mostra l\'etiqueta Fresc per a productes frescos', (tester) async {
      await tester.pumpWidget(buildSubject(
        makeItem(dataCaducitat: DateTime.now().add(const Duration(days: 30))),
      ));

      expect(find.text('Fresc'), findsOneWidget);
    });

    testWidgets('mostra l\'etiqueta Caducat per a productes caducats', (tester) async {
      await tester.pumpWidget(buildSubject(
        makeItem(
          dataCaducitat: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ));

      expect(find.text('Caducat'), findsAtLeastNWidgets(1));
    });

    testWidgets('mostra les targetes d\'informació', (tester) async {
      await tester.pumpWidget(buildSubject(makeItem()));

      expect(find.text('Quantitat'), findsOneWidget);
      expect(find.text('Caducitat'), findsOneWidget);
      expect(find.text('Afegit'), findsOneWidget);
      expect(find.text('Dies restants'), findsOneWidget);
    });

    testWidgets('mostra la barra de progres si hi ha data de caducitat', (tester) async {
      await tester.pumpWidget(buildSubject(
        makeItem(dataCaducitat: DateTime.now().add(const Duration(days: 10))),
      ));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('no mostra la barra de progres si no hi ha data', (tester) async {
      await tester.pumpWidget(buildSubject(makeItem(dataCaducitat: null)));

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('mostra els botons Llençat i Consumit', (tester) async {
      await tester.pumpWidget(buildSubject(makeItem()));

      expect(find.text('Llençat'), findsOneWidget);
      expect(find.text('Consumit'), findsOneWidget);
    });

    testWidgets('mostra el botó d\'editar a l\'AppBar', (tester) async {
      await tester.pumpWidget(buildSubject(makeItem()));

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });
  });

  group('ProductDetailScreen - diàlegs de confirmació', () {
    testWidgets('tap a Consumit obre el diàleg de confirmació', (tester) async {
      await tester.pumpWidget(buildSubject(makeItem(nom: 'Llet')));

      await tester.tap(find.text('Consumit'));
      await tester.pumpAndSettle();

      expect(find.text('Consumit "Llet"?'), findsOneWidget);
      expect(find.text('Cancel·lar'), findsOneWidget);
    });

    testWidgets('tap a Llençat obre el diàleg de confirmació', (tester) async {
      await tester.pumpWidget(buildSubject(makeItem(nom: 'Llet')));

      await tester.tap(find.text('Llençat'));
      await tester.pumpAndSettle();

      expect(find.text('Llençat "Llet"?'), findsOneWidget);
    });

    testWidgets('cancel·lar el diàleg no crida deleteItem', (tester) async {
      await tester.pumpWidget(buildSubject(makeItem()));

      await tester.tap(find.text('Consumit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel·lar'));
      await tester.pumpAndSettle();

      verifyNever(mockInventory.deleteItem(any));
    });

    testWidgets('confirmar Consumit crida deleteItem', (tester) async {
      when(mockInventory.deleteItem(1)).thenAnswer((_) async => true);

      await tester.pumpWidget(buildSubject(makeItem()));

      await tester.tap(find.text('Consumit'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(ElevatedButton, 'Consumit'),
        ),
      );
      await tester.pumpAndSettle();

      verify(mockInventory.deleteItem(1)).called(1);
    });
  });
}