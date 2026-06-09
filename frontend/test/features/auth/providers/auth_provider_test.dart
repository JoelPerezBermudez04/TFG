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
    mockApi = MockApiService();
    provider = AuthProvider(api: mockApi, init: false);
  });

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
  });

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
  });

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

    test('updateProfile returns true and updates the user', () async {
      when(mockApi.patch(ApiConfig.editProfile, any)).thenAnswer((_) async => {
            'statusCode': 200,
            'body': {...userJson, 'username': 'updatedUser'},
          });

      final ok = await provider.updateProfile(username: 'updatedUser');

      expect(ok, isTrue);
      expect(provider.user?.username, 'updatedUser');
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
  });

  test('clearError sets error to null', () {
    provider = AuthProvider(api: mockApi, init: false);
    provider.clearError();
    expect(provider.error, isNull);
  });
}
