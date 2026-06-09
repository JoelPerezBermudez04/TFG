import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/auth/models/user_model.dart';
import 'package:frontend/features/auth/screens/edit_profile_screen.dart';

import 'edit_profile_screen_test.mocks.dart';

@GenerateMocks([AuthProvider])
void main() {
  late MockAuthProvider mockAuth;

  final userLocal = User(
    id: 1,
    username: 'testuser',
    email: 'test@test.com',
    provider: 'LOCAL',
    diesAvisCaducitat: 5,
  );

  final userGoogle = User(
    id: 2,
    username: 'googleuser',
    email: 'google@gmail.com',
    provider: 'GOOGLE',
    diesAvisCaducitat: 5,
  );

  void setupMock(User user) {
    when(mockAuth.user).thenReturn(user);
    when(mockAuth.isSubmitting).thenReturn(false);
    when(mockAuth.error).thenReturn(null);
    when(mockAuth.addListener(any)).thenReturn(null);
    when(mockAuth.removeListener(any)).thenReturn(null);
  }

  Widget buildSubject() {
    return MaterialApp(
      home: ChangeNotifierProvider<AuthProvider>.value(
        value: mockAuth,
        child: const EditProfileScreen(),
      ),
    );
  }

  setUp(() {
    mockAuth = MockAuthProvider();
  });

  group('EditProfileScreen - usuari LOCAL', () {
    setUp(() => setupMock(userLocal));

    testWidgets('mostra el títol de la pantalla', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Editar perfil'), findsOneWidget);
    });

    testWidgets('omple el camp usuari amb el valor actual', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.widgetWithText(TextFormField, 'Usuari'), findsOneWidget);
      final field = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Usuari'),
      );
      expect(field.controller?.text, 'testuser');
    });

    testWidgets('mostra el camp email per a usuaris locals', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      final field = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Email'),
      );
      expect(field.controller?.text, 'test@test.com');
    });

    testWidgets('no mostra el missatge informatiu de Google', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
          find.text("L'email el gestiona Google i no es pot canviar aquí."),
          findsNothing);
    });

    testWidgets('mostra error si l\'usuari té menys de 3 caràcters',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Usuari'), 'ab');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar canvis'));
      await tester.pump();

      expect(find.text("L'usuari ha de tenir mínim 3 caràcters"), findsOneWidget);
    });

    testWidgets('mostra error si l\'email és invàlid', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'emailmale');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar canvis'));
      await tester.pump();

      expect(find.text('Introdueix un email vàlid'), findsOneWidget);
    });

    testWidgets('crida updateProfile amb usuari i email correctes',
        (tester) async {
      when(mockAuth.updateProfile(
        username: 'nounom',
        email: 'nou@test.com',
      )).thenAnswer((_) async => true);

      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Usuari'), 'nounom');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'nou@test.com');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar canvis'));
      await tester.pump();

      verify(mockAuth.updateProfile(
        username: 'nounom',
        email: 'nou@test.com',
      )).called(1);
    });
  });

  group('EditProfileScreen - usuari GOOGLE', () {
    setUp(() => setupMock(userGoogle));

    testWidgets('no mostra el camp email per a usuaris de Google',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.widgetWithText(TextFormField, 'Email'), findsNothing);
    });

    testWidgets('mostra el missatge informatiu de Google', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
          find.text("L'email el gestiona Google i no es pot canviar aquí."),
          findsOneWidget);
    });

    testWidgets('crida updateProfile sense email per a usuaris de Google',
        (tester) async {
      when(mockAuth.updateProfile(
        username: anyNamed('username'),
        email: null,
      )).thenAnswer((_) async => true);

      await tester.pumpWidget(buildSubject());

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Usuari'), 'nougoogle');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar canvis'));
      await tester.pump();

      verify(mockAuth.updateProfile(
        username: 'nougoogle',
        email: null,
      )).called(1);
    });
  });

  group('EditProfileScreen - estat de càrrega', () {
    testWidgets('mostra CircularProgressIndicator mentre isSubmitting és true',
        (tester) async {
      setupMock(userLocal);
      when(mockAuth.isSubmitting).thenReturn(true);

      await tester.pumpWidget(buildSubject());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('botó desactivat mentre isSubmitting és true', (tester) async {
      setupMock(userLocal);
      when(mockAuth.isSubmitting).thenReturn(true);

      await tester.pumpWidget(buildSubject());

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).first,
      );
      expect(button.enabled, isFalse);
    });
  });
}