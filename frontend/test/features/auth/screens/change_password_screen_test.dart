import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/auth/screens/change_password_screen.dart';

import 'change_password_screen_test.mocks.dart';

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
        child: const ChangePasswordScreen(),
      ),
    );
  }

  group('ChangePasswordScreen - renderització inicial', () {
    testWidgets('mostra el títol de la pantalla', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Canviar contrasenya')),
        findsOneWidget,
      );
    });

    testWidgets('mostra els tres camps de contrasenya', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.widgetWithText(TextFormField, 'Contrasenya actual'),
          findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Nova contrasenya'),
          findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Confirmar nova contrasenya'),
          findsOneWidget);
    });

    testWidgets('mostra el botó de canviar contrasenya', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.widgetWithText(ElevatedButton, 'Canviar contrasenya'),
          findsOneWidget);
    });
  });

  group('ChangePasswordScreen - validació de formulari', () {
    testWidgets('mostra error si la contrasenya actual és buida', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(
          find.widgetWithText(ElevatedButton, 'Canviar contrasenya'));
      await tester.pump();

      expect(find.text('Introdueix la contrasenya actual'), findsOneWidget);
    });

    testWidgets('mostra error si la nova contrasenya té menys de 8 caràcters',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Contrasenya actual'),
          'actual1234');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nova contrasenya'), '1234567');
      await tester.tap(
          find.widgetWithText(ElevatedButton, 'Canviar contrasenya'));
      await tester.pump();

      expect(find.text('La contrasenya ha de tenir mínim 8 caràcters'),
          findsOneWidget);
    });

    testWidgets(
        'mostra error si la nova contrasenya és igual a l\'actual',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Contrasenya actual'), 'mateixa12');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nova contrasenya'), 'mateixa12');
      await tester.tap(
          find.widgetWithText(ElevatedButton, 'Canviar contrasenya'));
      await tester.pump();

      expect(
          find.text(
              "La nova contrasenya ha de ser diferent de l'actual"),
          findsOneWidget);
    });

    testWidgets('mostra error si les contrasenyes noves no coincideixen',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Contrasenya actual'), 'actual123');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nova contrasenya'), 'nova12345');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmar nova contrasenya'),
          'diferent45');
      await tester.tap(
          find.widgetWithText(ElevatedButton, 'Canviar contrasenya'));
      await tester.pump();

      expect(find.text('Les contrasenyes no coincideixen'), findsOneWidget);
    });

    testWidgets('no crida changePassword si la validació falla', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(
          find.widgetWithText(ElevatedButton, 'Canviar contrasenya'));
      await tester.pump();

      verifyNever(mockAuth.changePassword(
        currentPassword: anyNamed('currentPassword'),
        newPassword: anyNamed('newPassword'),
      ));
    });
  });

  group('ChangePasswordScreen - acció de canvi', () {
    Future<void> _omplirFormulariValid(WidgetTester tester) async {
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Contrasenya actual'), 'actual123');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nova contrasenya'), 'nova12345');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmar nova contrasenya'),
          'nova12345');
    }

    testWidgets('crida changePassword amb les dades correctes', (tester) async {
      when(mockAuth.changePassword(
        currentPassword: 'actual123',
        newPassword: 'nova12345',
      )).thenAnswer((_) async => true);

      await tester.pumpWidget(buildSubject());
      await _omplirFormulariValid(tester);
      await tester.tap(
          find.widgetWithText(ElevatedButton, 'Canviar contrasenya'));
      await tester.pump();

      verify(mockAuth.changePassword(
        currentPassword: 'actual123',
        newPassword: 'nova12345',
      )).called(1);
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

  group('ChangePasswordScreen - toggle visibilitat', () {
    EditableText _editableOf(WidgetTester tester, String label) {
      return tester.widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(TextFormField, label),
          matching: find.byType(EditableText),
        ),
      );
    }

    testWidgets('totes les contrasenyes s\'amaguen per defecte', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(_editableOf(tester, 'Contrasenya actual').obscureText, isTrue);
      expect(_editableOf(tester, 'Nova contrasenya').obscureText, isTrue);
      expect(_editableOf(tester, 'Confirmar nova contrasenya').obscureText, isTrue);
    });

    testWidgets('tap a l\'icona mostra la contrasenya actual', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byIcon(Icons.visibility_off).first);
      await tester.pump();

      expect(_editableOf(tester, 'Contrasenya actual').obscureText, isFalse);
    });
  });
}