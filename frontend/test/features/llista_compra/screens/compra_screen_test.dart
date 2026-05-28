import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:frontend/features/llista_compra/models/compra_item_model.dart';
import 'package:frontend/features/llista_compra/providers/compra_provider.dart';
import 'package:frontend/features/llista_compra/screens/compra_screen.dart';

import 'compra_screen_test.mocks.dart';

@GenerateMocks([CompraProvider])
void main() {
  late MockCompraProvider mockCompra;

  setUp(() {
    mockCompra = MockCompraProvider();
    when(mockCompra.addListener(any)).thenReturn(null);
    when(mockCompra.removeListener(any)).thenReturn(null);
    when(mockCompra.fetchItems()).thenAnswer((_) async {});
    when(mockCompra.isLoading).thenReturn(false);
    when(mockCompra.error).thenReturn(null);
    when(mockCompra.items).thenReturn([]);
    when(mockCompra.pendents).thenReturn([]);
    when(mockCompra.comprats).thenReturn([]);
    when(mockCompra.totalPendents).thenReturn(0);
    when(mockCompra.deleteAllComprats()).thenAnswer((_) async {});
  });

  Widget buildSubject() {
    return MaterialApp(
      home: ChangeNotifierProvider<CompraProvider>.value(
        value: mockCompra,
        child: const CompraScreen(),
      ),
    );
  }

  testWidgets('mostra l\'estat buit quan no hi ha elements', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('La llista és buida'), findsOneWidget);
    expect(find.text('Afegeix productes manualment o des d\'una recepta'),
        findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('mostra el botó Netejar quan hi ha productes comprats',
      (tester) async {
    final item = CompraItem(
      id: 1,
      usuari: 1,
      producte: 1,
      producteNom: 'Tomàquet',
      unitat: 'unitat',
      quantitat: 1.0,
      comprat: true,
      dataAfegit: DateTime.now(),
    );

    when(mockCompra.items).thenReturn([item]);
    when(mockCompra.pendents).thenReturn([]);
    when(mockCompra.comprats).thenReturn([item]);
    when(mockCompra.totalPendents).thenReturn(0);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, 'Netejar'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Netejar'));
    await tester.pumpAndSettle();

    expect(find.text('Netejar comprats'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Eliminar'));
    await tester.pumpAndSettle();

    verify(mockCompra.deleteAllComprats()).called(1);
  });
}
