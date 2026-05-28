import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:frontend/features/inventari/models/inventory_item_model.dart';
import 'package:frontend/features/inventari/providers/inventory_provider.dart';
import 'package:frontend/features/receptes/providers/receptes_provider.dart';
import 'package:frontend/features/receptes/screens/recepta_detail_screen.dart';

import 'recepta_detail_screen_test.mocks.dart';

@GenerateMocks([ReceptesProvider, InventoryProvider])
void main() {
  late MockReceptesProvider mockReceptes;
  late MockInventoryProvider mockInventory;

  setUp(() {
    mockReceptes = MockReceptesProvider();
    mockInventory = MockInventoryProvider();
    when(mockReceptes.addListener(any)).thenReturn(null);
    when(mockReceptes.removeListener(any)).thenReturn(null);
    when(mockInventory.addListener(any)).thenReturn(null);
    when(mockInventory.removeListener(any)).thenReturn(null);
    when(mockReceptes.fetchDetall(any)).thenAnswer((_) async {});
    when(mockReceptes.esFavorit(any)).thenReturn(false);
    when(mockReceptes.isToggling(any)).thenReturn(false);
    when(mockInventory.items).thenReturn([]);
  });

  Widget buildSubject() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<ReceptesProvider>.value(value: mockReceptes),
          ChangeNotifierProvider<InventoryProvider>.value(value: mockInventory),
        ],
        child: const ReceptaDetailScreen(idApi: 'recepta-1'),
      ),
    );
  }

  testWidgets('mostra l\'error i reintenta la càrrega quan no hi ha recepta',
      (tester) async {
    when(mockReceptes.loadingDetall).thenReturn(false);
    when(mockReceptes.receptaDetall).thenReturn(null);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('No s\'ha pogut carregar la recepta'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Reintentar'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Reintentar'));
    await tester.pumpAndSettle();

    verify(mockReceptes.fetchDetall('recepta-1')).called(2);
  });

  testWidgets('mostra el contingut de la recepta i el botó de cuinar',
      (tester) async {
    final recepte = Recepta(
      idApi: 'recepta-1',
      nom: 'Recepta Test',
      descripcio: 'Descripció de prova',
      imatgeUrl: null,
      tempsPreparacio: 10,
      porcions: 2,
      instruccions: ['Pas 1', 'Pas 2'],
      dietes: const ['Vegetarià'],
      intolerancias: const [],
      ingredients: const [
        IngredientRecepta(
          producte: 1,
          producteNom: 'Tomàquet',
          producteEmoji: '🍅',
          producteImatgeUrl: null,
          quantitat: 1.0,
          unitat: 'unitat',
          nomOriginal: 'Tomàquet',
        ),
      ],
      numIngredients: 1,
    );

    when(mockReceptes.loadingDetall).thenReturn(false);
    when(mockReceptes.receptaDetall).thenReturn(recepte);
    when(mockInventory.items).thenReturn([
      InventoryItem(
        id: 1,
        usuari: 1,
        producte: 1,
        producteNom: 'Tomàquet',
        producteEmoji: '🍅',
        quantitat: 1.0,
        unitat: 'unitat',
        dataAfegit: DateTime.now(),
        caducat: false,
      ),
    ]);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Recepta Test'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) =>
          widget is Text && widget.data?.contains('Cuinar — marcar') == true),
      findsOneWidget,
    );
  });
}
