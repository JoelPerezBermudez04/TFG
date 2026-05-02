import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/auth/models/user_model.dart';
import 'package:frontend/features/auth/screens/profile_screen.dart';

import 'profile_screen_test.mocks.dart';

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
    diesAvisCaducitat: 3,
  );

  void setupMock(User user) {
    when(mockAuth.user).thenReturn(user);
    when(mockAuth.isSubmitting).thenReturn(false);
    when(mockAuth.error).thenReturn(null);
    when(mockAuth.isAuthenticated).thenReturn(true);
    when(mockAuth.addListener(any)).thenReturn(null);
    when(mockAuth.removeListener(any)).thenReturn(null);
  }

  Widget buildSubject() {
    return MaterialApp(
      home: ChangeNotifierProvider<AuthProvider>.value(
        value: mockAuth,
        child: const ProfileScreen(),
      ),
    );
  }

  setUp(() {
    mockAuth = MockAuthProvider();
  });

  group('ProfileScreen - usuari LOCAL', () {
    setUp(() => setupMock(userLocal));

    testWidgets('mostra el títol de la pantalla', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Perfil'), findsOneWidget);
    });

    testWidgets('mostra el nom d\'usuari', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('testuser'), findsOneWidget);
    });

    testWidgets('mostra l\'email de l\'usuari', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('test@test.com'), findsOneWidget);
    });

    testWidgets('mostra la inicial del nom en majúscula', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('mostra l\'opció de canviar contrasenya per a usuaris locals',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Canviar contrasenya'), findsOneWidget);
    });

    testWidgets('no mostra la badge de compte Google', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Compte Google'), findsNothing);
    });

    testWidgets('mostra els dies d\'avís de caducitat correctament',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Avisar 5 dies abans'), findsOneWidget);
    });

    testWidgets('mostra les opcions de tancar sessió i eliminar compte',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Tancar sessió'), findsOneWidget);
      expect(find.text('Eliminar compte'), findsOneWidget);
    });

    testWidgets('mostra la versió de l\'app', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('FreshTrack v1.0.0'), findsOneWidget);
    });
  });

  group('ProfileScreen - usuari GOOGLE', () {
    setUp(() => setupMock(userGoogle));

    testWidgets('mostra la badge de compte Google', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Compte Google'), findsOneWidget);
    });

    testWidgets('no mostra l\'opció de canviar contrasenya', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Canviar contrasenya'), findsNothing);
    });

    testWidgets('mostra els dies d\'avís correctes', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Avisar 3 dies abans'), findsOneWidget);
    });
  });

  group('ProfileScreen - diàlegs', () {
    setUp(() => setupMock(userLocal));

    testWidgets('tap a Tancar sessió obre el diàleg de confirmació',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Tancar sessió'));
      await tester.pumpAndSettle();

      expect(find.text('Tancar sessió?'), findsOneWidget);
      expect(find.text('Segur que vols sortir?'), findsOneWidget);
    });

    testWidgets('cancel·lar el diàleg de logout no crida logout', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Tancar sessió'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel·lar'));
      await tester.pumpAndSettle();

      verifyNever(mockAuth.logout());
    });

    testWidgets('confirmar logout crida auth.logout', (tester) async {
      when(mockAuth.logout()).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Tancar sessió'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sortir'));
      await tester.pumpAndSettle();

      verify(mockAuth.logout()).called(1);
    });

    testWidgets(
        'tap a Eliminar compte (LOCAL) obre el diàleg amb camp de contrasenya',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Eliminar compte'));
      await tester.pumpAndSettle();

      expect(find.text('Eliminar compte?'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Contrasenya'), findsOneWidget);
    });

    testWidgets('tap a Avisos de caducitat obre el diàleg del selector de dies',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Avisos de caducitat'));
      await tester.pumpAndSettle();

      expect(find.text("Dies d'avís de caducitat"), findsOneWidget);
    });

    testWidgets('el selector de dies mostra el valor actual', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Avisos de caducitat'));
      await tester.pumpAndSettle();

      expect(find.text('5 dies'), findsOneWidget);
    });
  });

  group('ProfileScreen - diàleg eliminar compte GOOGLE', () {
    setUp(() => setupMock(userGoogle));

    testWidgets(
        'tap a Eliminar compte (GOOGLE) obre el diàleg sense camp de contrasenya',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Eliminar compte'));
      await tester.pumpAndSettle();

      expect(find.text('Eliminar compte?'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Contrasenya'), findsNothing);
    });
  });
}