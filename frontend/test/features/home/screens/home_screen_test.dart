import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:frontend/features/auth/models/user_model.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/home/screens/main_screen.dart';
import 'package:frontend/features/inventari/providers/inventory_provider.dart';
import 'package:frontend/core/services/api_service.dart';

import 'home_screen_test.mocks.dart';

@GenerateMocks([InventoryProvider, AuthProvider, ApiService])
void main() {
  late MockInventoryProvider mockInventory;
  late MockAuthProvider mockAuth;
  late MockApiService mockApi;

  setUpAll(() async {
    await initializeDateFormatting('ca', null);
  });

  setUp(() {
    mockInventory = MockInventoryProvider();
    mockAuth = MockAuthProvider();
    mockApi = MockApiService();

    when(mockInventory.addListener(any)).thenReturn(null);
    when(mockInventory.removeListener(any)).thenReturn(null);
    when(mockAuth.addListener(any)).thenReturn(null);
    when(mockAuth.removeListener(any)).thenReturn(null);

    when(mockInventory.items).thenReturn([]);
    when(mockInventory.isLoading).thenReturn(false);
    when(mockInventory.fetchInventory()).thenAnswer((_) async {});

    when(mockAuth.user).thenReturn(User(
      id: 1,
      username: 'TestUser',
      email: 'test@example.com',
      provider: 'LOCAL',
      diesAvisCaducitat: 5,
    ));

    when(mockApi.get(any)).thenAnswer((_) async => {
          'statusCode': 200,
          'body': {
            'results': [],
          },
        });
  });

  Widget buildSubject() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<InventoryProvider>.value(value: mockInventory),
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ],
        child: HomeScreen(api: mockApi),
      ),
    );
  }

  testWidgets('mostra la salutació amb el nom d\'usuari', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data?.contains('TestUser') == true,
      ),
      findsOneWidget,
    );

    expect(find.text('Productes'), findsOneWidget);
    expect(find.text('Aviat'), findsOneWidget);
    expect(find.text('Caducats'), findsOneWidget);
  });

  testWidgets('mostra el missatge de rebost buit quan no hi ha productes',
      (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('El rebost és buit'), findsOneWidget);
    expect(find.text('Comença afegint productes al teu inventari'),
        findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Afegir producte'), findsOneWidget);
  });
}
