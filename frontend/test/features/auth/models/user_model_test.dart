import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/models/user_model.dart';

void main() {
  group('User.fromJson', () {
    test('mapeja tots els camps correctament', () {
      final json = {
        'id': 1,
        'username': 'testuser',
        'email': 'test@example.com',
        'provider': 'LOCAL',
        'dies_avis_caducitat': 3,
      };

      final user = User.fromJson(json);

      expect(user.id, 1);
      expect(user.username, 'testuser');
      expect(user.email, 'test@example.com');
      expect(user.provider, 'LOCAL');
      expect(user.diesAvisCaducitat, 3);
    });

    test('usa valors per defecte quan falten camps opcionals', () {
      final json = {
        'id': 2,
        'username': 'altreuser',
      };

      final user = User.fromJson(json);

      expect(user.email, '');
      expect(user.provider, 'LOCAL');
      expect(user.diesAvisCaducitat, 5);
    });

    test('mapeja provider GOOGLE correctament', () {
      final json = {
        'id': 3,
        'username': 'googleuser',
        'email': 'google@gmail.com',
        'provider': 'GOOGLE',
        'dies_avis_caducitat': 7,
      };

      final user = User.fromJson(json);

      expect(user.provider, 'GOOGLE');
    });
  });

  group('User.toJson', () {
    test('serialitza tots els camps correctament', () {
      final user = User(
        id: 1,
        username: 'testuser',
        email: 'test@example.com',
        provider: 'LOCAL',
        diesAvisCaducitat: 5,
      );

      final json = user.toJson();

      expect(json['id'], 1);
      expect(json['username'], 'testuser');
      expect(json['email'], 'test@example.com');
      expect(json['provider'], 'LOCAL');
      expect(json['dies_avis_caducitat'], 5);
    });

    test('fromJson i toJson són inversos', () {
      final original = {
        'id': 1,
        'username': 'testuser',
        'email': 'test@example.com',
        'provider': 'LOCAL',
        'dies_avis_caducitat': 5,
      };

      final result = User.fromJson(original).toJson();

      expect(result, original);
    });
  });
}