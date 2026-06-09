import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:frontend/features/receptes/providers/receptes_provider.dart';
import 'package:frontend/features/receptes/screens/receptes_screen.dart';

import 'receptes_screen_test.mocks.dart';

@GenerateMocks([ReceptesProvider])
void main() {
  late MockReceptesProvider mockProvider;

  setUp(() {
    mockProvider = MockReceptesProvider();
    when(mockProvider.addListener(any)).thenReturn(null);
    when(mockProvider.removeListener(any)).thenReturn(null);
    when(mockProvider.fetchReceptes()).thenAnswer((_) async {});
    when(mockProvider.fetchFavorits()).thenAnswer((_) async {});
    when(mockProvider.isLoading).thenReturn(false);
    when(mockProvider.error).thenReturn(null);
    when(mockProvider.receptes).thenReturn([]);
    when(mockProvider.favorits).thenReturn([]);
    when(mockProvider.loadingFavorits).thenReturn(false);
    when(mockProvider.teFiltresActius).thenReturn(false);
    when(mockProvider.total).thenReturn(0);
    when(mockProvider.hasMore).thenReturn(false);
  });

  Widget buildSubject() {
    return MaterialApp(
      home: ChangeNotifierProvider<ReceptesProvider>.value(
        value: mockProvider,
        child: const ReceptesScreen(),
      ),
    );
  }

  testWidgets('mostra les pestanyes i el missatge de sense resultats',
      (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Totes'), findsOneWidget);
    expect(find.text('Preferides'), findsOneWidget);
    expect(find.text('Sense resultats'), findsOneWidget);
  });

  testWidgets('mostra el missatge de preferides buides quan es selecciona la pestanya',
      (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Preferides'));
    await tester.pumpAndSettle();

    expect(find.text('Cap preferida encara'), findsOneWidget);
    expect(find.text('Prem el cor d\'una recepta per guardar-la aquí'),
        findsOneWidget);
  });
}
