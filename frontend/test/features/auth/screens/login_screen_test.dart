import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/auth/screens/login_screen.dart';

import 'login_screen_test.mocks.dart';

@GenerateMocks([AuthProvider])
void main() {
  late MockAuthProvider mockAuth;

  setUp(() {
    mockAuth = MockAuthProvider();
    when(mockAuth.isSubmitting).thenReturn(false);
    when(mockAuth.error).thenReturn(null);
    when(mockAuth.addListener(any)).thenReturn(null);
    when(mockAuth.removeListener(any)).thenReturn(null);
  });

  Widget buildSubject() {
    return MaterialApp(
      home: ChangeNotifierProvider<AuthProvider>.value(
        value: mockAuth,
        child: const LoginScreen(),
      ),
    );
  }

  group('LoginScreen - renderització inicial', () {
    testWidgets('mostra el títol de benvinguda', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Benvingut!'), findsOneWidget);
      expect(find.text('Inicia sessió per continuar'), findsOneWidget);
    });

    testWidgets('mostra els camps usuari i contrasenya', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.widgetWithText(TextFormField, 'Usuari'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Contrasenya'), findsOneWidget);
    });

    testWidgets('mostra el botó d\'iniciar sessió habilitat', (tester) async {
      await tester.pumpWidget(buildSubject());

      final button = find.widgetWithText(ElevatedButton, 'Iniciar sessió');
      expect(button, findsOneWidget);
      expect(tester.widget<ElevatedButton>(button).enabled, isTrue);
    });

    testWidgets('mostra el botó de Google', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Continuar amb Google'), findsOneWidget);
    });

    testWidgets('mostra l\'enllaç de registre', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('No tens compte? '), findsOneWidget);
      expect(find.widgetWithText(TextButton, "Registra't"), findsOneWidget);
    });
  });

  group('LoginScreen - validació de formulari', () {
    testWidgets('mostra error si l\'usuari és buit', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sessió'));
      await tester.pump();

      expect(find.text('Introdueix el teu usuari'), findsOneWidget);
    });

    testWidgets('mostra error si la contrasenya és buida', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Usuari'), 'testuser');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sessió'));
      await tester.pump();

      expect(find.text('Introdueix la contrasenya'), findsOneWidget);
    });

    testWidgets('no crida login si la validació falla', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sessió'));
      await tester.pump();

      verifyNever(mockAuth.login(any, any));
    });
  });

  group('LoginScreen - acció de login', () {
    testWidgets('crida auth.login amb les credencials correctes', (tester) async {
      when(mockAuth.login('testuser', '12345678'))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Usuari'), 'testuser');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Contrasenya'), '12345678');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sessió'));
      await tester.pump();

      verify(mockAuth.login('testuser', '12345678')).called(1);
    });

    testWidgets('mostra CircularProgressIndicator mentre isSubmitting és true',
        (tester) async {
      when(mockAuth.isSubmitting).thenReturn(true);

      await tester.pumpWidget(buildSubject());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Iniciar sessió'), findsNothing);
    });

    testWidgets('botó desactivat mentre isSubmitting és true', (tester) async {
      when(mockAuth.isSubmitting).thenReturn(true);

      await tester.pumpWidget(buildSubject());

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).first,
      );
      expect(button.enabled, isFalse);
    });
  });

  group('LoginScreen - toggle visibilitat contrasenya', () {
    testWidgets('la contrasenya s\'amaga per defecte', (tester) async {
      await tester.pumpWidget(buildSubject());

      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Contrasenya'),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.obscureText, isTrue);
    });

    testWidgets('tap a l\'icona mostra la contrasenya', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();

      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Contrasenya'),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.obscureText, isFalse);
    });
  });
}