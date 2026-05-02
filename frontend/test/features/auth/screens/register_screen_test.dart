import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/auth/screens/register_screen.dart';

import 'register_screen_test.mocks.dart';

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
        child: const RegisterScreen(),
      ),
    );
  }

  group('RegisterScreen - renderització inicial', () {
    testWidgets('mostra el títol de la pantalla', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Crear compte')),
        findsOneWidget,
      );
    });

    testWidgets('mostra tots els camps del formulari', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.widgetWithText(TextFormField, 'Usuari'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Contrasenya'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Confirmar contrasenya'),
          findsOneWidget);
    });

    testWidgets('mostra el botó de crear compte', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.widgetWithText(ElevatedButton, 'Crear compte'), findsOneWidget);
    });
  });

  group('RegisterScreen - validació de formulari', () {
    testWidgets('mostra error si l\'usuari és buit', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear compte'));
      await tester.pump();

      expect(find.text("Introdueix un nom d'usuari"), findsOneWidget);
    });

    testWidgets('mostra error si l\'usuari té menys de 3 caràcters',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Usuari'), 'ab');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear compte'));
      await tester.pump();

      expect(find.text("L'usuari ha de tenir mínim 3 caràcters"), findsOneWidget);
    });

    testWidgets('mostra error si l\'email és invàlid', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Usuari'), 'testuser');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'emailinvalid');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear compte'));
      await tester.pump();

      expect(find.text('Introdueix un email vàlid'), findsOneWidget);
    });

    testWidgets('mostra error si la contrasenya té menys de 8 caràcters',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Usuari'), 'testuser');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'test@test.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Contrasenya'), '1234567');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear compte'));
      await tester.pump();

      expect(find.text('La contrasenya ha de tenir mínim 8 caràcters'),
          findsOneWidget);
    });

    testWidgets('mostra error si les contrasenyes no coincideixen',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Usuari'), 'testuser');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'test@test.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Contrasenya'), '12345678');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmar contrasenya'),
          'diferent678');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear compte'));
      await tester.pump();

      expect(find.text('Les contrasenyes no coincideixen'), findsOneWidget);
    });

    testWidgets('no crida register si la validació falla', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear compte'));
      await tester.pump();

      verifyNever(mockAuth.register(any, any, any));
    });
  });

  group('RegisterScreen - acció de registre', () {
    Future<void> _omplirFormulariValid(WidgetTester tester) async {
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Usuari'), 'testuser');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'test@test.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Contrasenya'), '12345678');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmar contrasenya'),
          '12345678');
    }

    testWidgets('crida auth.register amb les dades correctes', (tester) async {
      when(mockAuth.register('testuser', 'test@test.com', '12345678'))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(buildSubject());
      await _omplirFormulariValid(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear compte'));
      await tester.pump();

      verify(mockAuth.register('testuser', 'test@test.com', '12345678'))
          .called(1);
    });

    testWidgets('mostra CircularProgressIndicator mentre isSubmitting és true',
        (tester) async {
      when(mockAuth.isSubmitting).thenReturn(true);

      await tester.pumpWidget(buildSubject());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
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

  group('RegisterScreen - toggle visibilitat contrasenyes', () {
    EditableText _editableOf(WidgetTester tester, String label) {
      return tester.widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(TextFormField, label),
          matching: find.byType(EditableText),
        ),
      );
    }

    testWidgets('les contrasenyes s\'amaguen per defecte', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(_editableOf(tester, 'Contrasenya').obscureText, isTrue);
      expect(_editableOf(tester, 'Confirmar contrasenya').obscureText, isTrue);
    });

    testWidgets('tap a l\'icona de contrasenya la mostra', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byIcon(Icons.visibility_off).first);
      await tester.pump();

      expect(_editableOf(tester, 'Contrasenya').obscureText, isFalse);
    });
  });
}