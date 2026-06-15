import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/config/api_config.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/auth/models/user_model.dart';

import 'auth_provider_test.mocks.dart';

@GenerateMocks([ApiService])
void main() {
  late MockApiService mockApi;
  late AuthProvider provider;

  final userJson = {
    'id': 1,
    'username': 'testuser',
    'email': 'test@example.com',
    'provider': 'LOCAL',
    'dies_avis_caducitat': 7,
  };

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockApi = MockApiService();
    provider = AuthProvider(api: mockApi, init: false);
  });

  // ─── LOGIN ────────────────────────────────────────────────────────────────

  group('login', () {
    test('returns true and authenticates on success', () async {
      when(mockApi.post(ApiConfig.login, any)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': {
              'tokens': {'access': 'access', 'refresh': 'refresh'},
              'usuari': userJson,
            },
          });
      when(mockApi.setTokens(access: anyNamed('access'), refresh: anyNamed('refresh')))
          .thenAnswer((_) async {});

      final ok = await provider.login('testuser', 'password');

      expect(ok, isTrue);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.user?.username, 'testuser');
    });

    test('returns false and sets error on bad credentials', () async {
      when(mockApi.post(ApiConfig.login, any)).thenAnswer((_) async => {
            'statusCode': 400,
            'body': {'detail': 'Credencials incorrectes'},
          });

      final ok = await provider.login('testuser', 'wrong');

      expect(ok, isFalse);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.error, 'Credencials incorrectes');
    });

    // NOU: error de xarxa
    test('returns false and sets connection error on network exception', () async {
      when(mockApi.post(ApiConfig.login, any)).thenThrow(Exception('network'));

      final ok = await provider.login('testuser', 'password');

      expect(ok, isFalse);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.error, 'Error de connexió. Comprova la teva xarxa.');
    });

    // NOU: timeout
    test('returns false and sets timeout error on TimeoutException', () async {
      when(mockApi.post(ApiConfig.login, any)).thenThrow(TimeoutException('timeout'));

      final ok = await provider.login('testuser', 'password');

      expect(ok, isFalse);
      expect(provider.error, 'El servidor no respon. Torna-ho a intentar.');
    });
  });

  // ─── REGISTER ─────────────────────────────────────────────────────────────

  group('register', () {
    test('returns true and authenticates on success', () async {
      when(mockApi.post(ApiConfig.register, any)).thenAnswer((_) async => {
            'statusCode': 201,
            'body': {
              'tokens': {'access': 'access', 'refresh': 'refresh'},
              'usuari': userJson,
            },
          });
      when(mockApi.setTokens(access: anyNamed('access'), refresh: anyNamed('refresh')))
          .thenAnswer((_) async {});

      final ok = await provider.register('testuser', 'test@example.com', 'password');

      expect(ok, isTrue);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.user?.email, 'test@example.com');
    });

    test('returns false and sets error when registration fails', () async {
      when(mockApi.post(ApiConfig.register, any)).thenAnswer((_) async => {
            'statusCode': 400,
            'body': {'error': 'Nom d\'usuari ja existent'},
          });

      final ok = await provider.register('testuser', 'test@example.com', 'password');

      expect(ok, isFalse);
      expect(provider.error, 'Nom d\'usuari ja existent');
    });

    // NOU: error de xarxa
    test('returns false and sets connection error on network exception', () async {
      when(mockApi.post(ApiConfig.register, any)).thenThrow(Exception('network'));

      final ok = await provider.register('testuser', 'test@example.com', 'password');

      expect(ok, isFalse);
      expect(provider.error, 'Error de connexió. Comprova la teva xarxa.');
    });
  });

  // ─── PROFILE ──────────────────────────────────────────────────────────────

  group('profile', () {
    test('fetchProfile authenticates when the profile call succeeds', () async {
      when(mockApi.get(ApiConfig.profile)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': userJson,
          });

      await provider.fetchProfile();

      expect(provider.isAuthenticated, isTrue);
      expect(provider.user?.id, 1);
    });

    // NOU: fetchProfile falla → sessió esborrada
    test('fetchProfile clears session when the call fails', () async {
      when(mockApi.get(ApiConfig.profile)).thenAnswer((_) async => {
            'statusCode': 401,
            'body': {'detail': 'No autoritzat'},
          });
      when(mockApi.clearTokens()).thenAnswer((_) async {});

      await provider.fetchProfile();

      expect(provider.isAuthenticated, isFalse);
      expect(provider.user, isNull);
    });

    // NOU: fetchProfile llença excepció → sessió esborrada
    test('fetchProfile clears session on network exception', () async {
      when(mockApi.get(ApiConfig.profile)).thenThrow(Exception('network'));
      when(mockApi.clearTokens()).thenAnswer((_) async {});

      await provider.fetchProfile();

      expect(provider.isAuthenticated, isFalse);
      expect(provider.user, isNull);
    });

    test('updateProfile returns true and updates the user', () async {
      when(mockApi.patch(ApiConfig.editProfile, any)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': {...userJson, 'username': 'updatedUser'},
          });

      final ok = await provider.updateProfile(username: 'updatedUser');

      expect(ok, isTrue);
      expect(provider.user?.username, 'updatedUser');
    });

    // NOU: updateProfile falla
    test('updateProfile returns false and sets error on failure', () async {
      when(mockApi.patch(ApiConfig.editProfile, any)).thenAnswer((_) async => {
            'statusCode': 400,
            'body': {'error': 'Username ja en ús'},
          });

      final ok = await provider.updateProfile(username: 'duplicat');

      expect(ok, isFalse);
      expect(provider.error, 'Username ja en ús');
    });

    // NOU: updateProfile error de xarxa
    test('updateProfile returns false and sets connection error on exception', () async {
      when(mockApi.patch(ApiConfig.editProfile, any)).thenThrow(Exception('network'));

      final ok = await provider.updateProfile(username: 'qualsevol');

      expect(ok, isFalse);
      expect(provider.error, 'Error de connexió. Comprova la teva xarxa.');
    });

    test('changePassword returns true on success', () async {
      when(mockApi.post(ApiConfig.changePassword, any)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': {'detail': 'Contrasenya canviada'},
          });

      final ok = await provider.changePassword(currentPassword: 'old', newPassword: 'new');

      expect(ok, isTrue);
      expect(provider.error, isNull);
    });

    // NOU: changePassword falla
    test('changePassword returns false and sets error on failure', () async {
      when(mockApi.post(ApiConfig.changePassword, any)).thenAnswer((_) async => {
            'statusCode': 400,
            'body': {'error': 'La contrasenya actual és incorrecta'},
          });

      final ok = await provider.changePassword(currentPassword: 'wrong', newPassword: 'new');

      expect(ok, isFalse);
      expect(provider.error, 'La contrasenya actual és incorrecta');
    });

    // NOU: changePassword error de xarxa
    test('changePassword returns false and sets connection error on exception', () async {
      when(mockApi.post(ApiConfig.changePassword, any)).thenThrow(Exception('network'));

      final ok = await provider.changePassword(currentPassword: 'old', newPassword: 'new');

      expect(ok, isFalse);
      expect(provider.error, 'Error de connexió. Comprova la teva xarxa.');
    });

    test('deleteAccount returns true and clears session on success', () async {
      when(mockApi.delete(ApiConfig.deleteAccount, data: anyNamed('data')))
          .thenAnswer((_) async => {
                'statusCode': 204,
                'body': null,
              });
      when(mockApi.clearTokens()).thenAnswer((_) async {});

      final ok = await provider.deleteAccount(password: 'password');

      expect(ok, isTrue);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.user, isNull);
    });

    // NOU: deleteAccount falla → sessió es manté
    test('deleteAccount returns false and keeps session on failure', () async {
      when(mockApi.delete(ApiConfig.deleteAccount, data: anyNamed('data')))
          .thenAnswer((_) async => {
                'statusCode': 400,
                'body': {'error': 'Contrasenya incorrecta'},
              });

      // Primer autentiquem l'usuari manualment via fetchProfile
      when(mockApi.get(ApiConfig.profile)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': userJson,
          });
      await provider.fetchProfile();

      final ok = await provider.deleteAccount(password: 'wrong');

      expect(ok, isFalse);
      expect(provider.error, 'Contrasenya incorrecta');
      expect(provider.isAuthenticated, isTrue); // sessió intacta
    });

    // NOU: deleteAccount error de xarxa
    test('deleteAccount returns false and sets connection error on exception', () async {
      when(mockApi.delete(ApiConfig.deleteAccount, data: anyNamed('data')))
          .thenThrow(Exception('network'));

      final ok = await provider.deleteAccount(password: 'password');

      expect(ok, isFalse);
      expect(provider.error, 'Error de connexió. Comprova la teva xarxa.');
    });
  });

  // ─── LOGOUT ───────────────────────────────────────────────────────────────

  group('logout', () {
    // NOU: logout crida blacklist i esborra la sessió
    test('clears session and sets unauthenticated', () async {
      when(mockApi.hasTokens).thenReturn(true);
      when(mockApi.refreshToken).thenReturn('refresh_tok');
      when(mockApi.post(ApiConfig.logout, any)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': {},
          });
      when(mockApi.clearTokens()).thenAnswer((_) async {});

      // Autentiquem primer
      when(mockApi.get(ApiConfig.profile)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': userJson,
          });
      await provider.fetchProfile();
      expect(provider.isAuthenticated, isTrue);

      await provider.logout();

      expect(provider.isAuthenticated, isFalse);
      expect(provider.user, isNull);
      verify(mockApi.clearTokens()).called(1);
    });

    // NOU: logout sense tokens no peta
    test('works without tokens without throwing', () async {
      when(mockApi.hasTokens).thenReturn(false);
      when(mockApi.clearTokens()).thenAnswer((_) async {});

      await expectLater(provider.logout(), completes);

      expect(provider.isAuthenticated, isFalse);
    });

    // NOU: logout continua fins al final encara que la crida al servidor falli
    test('still clears session even if the server call throws', () async {
      when(mockApi.hasTokens).thenReturn(true);
      when(mockApi.refreshToken).thenReturn('refresh_tok');
      when(mockApi.post(ApiConfig.logout, any)).thenThrow(Exception('network'));
      when(mockApi.clearTokens()).thenAnswer((_) async {});

      await provider.logout();

      expect(provider.isAuthenticated, isFalse);
      verify(mockApi.clearTokens()).called(1);
    });
  });

  // ─── ALTRES ───────────────────────────────────────────────────────────────

  test('clearError sets error to null', () {
    provider = AuthProvider(api: mockApi, init: false);
    provider.clearError();
    expect(provider.error, isNull);
  });
}