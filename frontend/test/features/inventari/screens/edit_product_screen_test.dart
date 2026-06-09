import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:frontend/features/inventari/providers/inventory_provider.dart';
import 'package:frontend/features/inventari/models/inventory_item_model.dart';
import 'package:frontend/features/inventari/screens/edit_product_screen.dart';

import 'edit_product_screen_test.mocks.dart';

@GenerateMocks([InventoryProvider])
void main() {
  late MockInventoryProvider mockInventory;

  InventoryItem makeItem({
    double quantitat = 2.0,
    String unitat = 'kg',
    DateTime? dataCaducitat,
    String nom = 'Tomàquets',
  }) {
    return InventoryItem(
      id: 1,
      usuari: 1,
      producte: 1,
      producteNom: nom,
      producteEmoji: '🍅',
      quantitat: quantitat,
      unitat: unitat,
      dataCaducitat: dataCaducitat,
      dataAfegit: DateTime(2025, 1, 1),
      caducat: false,
    );
  }

  setUp(() {
    mockInventory = MockInventoryProvider();
    when(mockInventory.isLoading).thenReturn(false);
    when(mockInventory.error).thenReturn(null);
    when(mockInventory.addListener(any)).thenReturn(null);
    when(mockInventory.removeListener(any)).thenReturn(null);
  });

  Widget buildSubject(InventoryItem item) {
    return MaterialApp(
      home: ChangeNotifierProvider<InventoryProvider>.value(
        value: mockInventory,
        child: EditProductScreen(item: item),
      ),
    );
  }

  group('EditProductScreen - renderització inicial', () {
    testWidgets('mostra el nom del producte al títol', (tester) async {
      await tester.pumpWidget(buildSubject(makeItem()));

      expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.text('Tomàquets')),
        findsOneWidget,
      );
    });

    testWidgets('omple el camp quantitat amb el valor actual', (tester) async {
      await tester.pumpWidget(buildSubject(makeItem(quantitat: 2.0)));

      final field = tester.widget<TextFormField>(
        find.byType(TextFormField),
      );
      expect(field.controller?.text, '2');
    });

    testWidgets('mostra la data de caducitat si n\'hi ha', (tester) async {
      await tester.pumpWidget(buildSubject(
        makeItem(dataCaducitat: DateTime(2025, 6, 15)),
      ));

      expect(find.text('15/06/2025'), findsOneWidget);
    });

    testWidgets('mostra "Sense data de caducitat" si no n\'hi ha', (tester) async {
      await tester.pumpWidget(buildSubject(makeItem(dataCaducitat: null)));

      expect(find.text('Sense data de caducitat'), findsOneWidget);
    });

    testWidgets('mostra el botó de guardar canvis', (tester) async {
      await tester.pumpWidget(buildSubject(makeItem()));

      expect(find.widgetWithText(ElevatedButton, 'Guardar canvis'), findsOneWidget);
    });
  });

  group('EditProductScreen - validació', () {
    testWidgets('mostra error si la quantitat és buida', (tester) async {
      await tester.pumpWidget(buildSubject(makeItem()));

      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar canvis'));
      await tester.pump();

      expect(find.text('Obligatori'), findsOneWidget);
    });

    testWidgets('mostra error si la quantitat és 0', (tester) async {
      await tester.pumpWidget(buildSubject(makeItem()));

      await tester.enterText(find.byType(TextFormField), '0');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar canvis'));
      await tester.pump();

      expect(find.text('Valor invàlid'), findsOneWidget);
    });

    testWidgets('no crida updateItem si la validació falla', (tester) async {
      await tester.pumpWidget(buildSubject(makeItem()));

      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar canvis'));
      await tester.pump();

      verifyNever(mockInventory.updateItem(
        any,
        quantitat: anyNamed('quantitat'),
        unitat: anyNamed('unitat'),
      ));
    });
  });

  group('EditProductScreen - acció de guardar', () {
    testWidgets('crida updateItem amb la quantitat correcta', (tester) async {
      when(mockInventory.updateItem(
        1,
        quantitat: 3.0,
        unitat: 'kg',
        dataCaducitat: null,
        clearDate: false,
      )).thenAnswer((_) async => true);

      await tester.pumpWidget(buildSubject(makeItem(dataCaducitat: null)));

      await tester.enterText(find.byType(TextFormField), '3');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar canvis'));
      await tester.pump();

      verify(mockInventory.updateItem(
        1,
        quantitat: 3.0,
        unitat: 'kg',
        dataCaducitat: null,
        clearDate: false,
      )).called(1);
    });

    testWidgets('mostra CircularProgressIndicator mentre isLoading és true',
        (tester) async {
      when(mockInventory.isLoading).thenReturn(true);
      await tester.pumpWidget(buildSubject(makeItem()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('botó desactivat mentre isLoading és true', (tester) async {
      when(mockInventory.isLoading).thenReturn(true);
      await tester.pumpWidget(buildSubject(makeItem()));

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).first,
      );
      expect(button.enabled, isFalse);
    });
  });

  group('EditProductScreen - gestió data de caducitat', () {
    testWidgets('la X esborra la data de caducitat existent', (tester) async {
      await tester.pumpWidget(buildSubject(
        makeItem(dataCaducitat: DateTime(2025, 6, 15)),
      ));

      expect(find.text('15/06/2025'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(find.text('Sense data de caducitat'), findsOneWidget);
    });
  });
}