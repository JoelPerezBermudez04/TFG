import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/config/api_config.dart';
import '../models/user_model.dart';

enum AuthStatus { checking, authenticated, unauthenticated }

class AuthProvider with ChangeNotifier {
  final _api = ApiService();

  User? _user;
  AuthStatus _status = AuthStatus.checking;
  bool _isSubmitting = false;
  String? _error;

  User? get user => _user;
  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isChecking => _status == AuthStatus.checking;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    await _api.loadTokens();
    if (_api.hasTokens) {
      await fetchProfile();
    } else {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  String _parseError(Map<String, dynamic>? body, String fallback) {
    if (body == null) return fallback;

    if (body['error'] is String) return body['error'];
    if (body['detail'] is String) return body['detail'];

    for (final key in body.keys) {
      final value = body[key];
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value is String) return value;
    }

    return fallback;
  }

  Future<bool> login(String username, String password) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.post(ApiConfig.login, {
        'username': username,
        'password': password,
      });

      if (response['statusCode'] == 200) {
        final data = response['body'] as Map<String, dynamic>;
        await _api.setTokens(
          access: data['tokens']['access'],
          refresh: data['tokens']['refresh'],
        );
        _user = User.fromJson(data['usuari']);
        _status = AuthStatus.authenticated;
        _isSubmitting = false;
        notifyListeners();
        return true;
      } else {
        _error = _parseError(response['body'], 'Error en iniciar sessió');
        _isSubmitting = false;
        notifyListeners();
        return false;
      }
    } catch (_) {
      _error = 'Error de connexió. Comprova la teva xarxa.';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.post(ApiConfig.register, {
        'username': username,
        'email': email,
        'password': password,
      });

      if (response['statusCode'] == 201) {
        final data = response['body'] as Map<String, dynamic>;
        await _api.setTokens(
          access: data['tokens']['access'],
          refresh: data['tokens']['refresh'],
        );
        _user = User.fromJson(data['usuari']);
        _status = AuthStatus.authenticated;
        _isSubmitting = false;
        notifyListeners();
        return true;
      } else {
        _error = _parseError(response['body'], 'Error en registrar-se');
        _isSubmitting = false;
        notifyListeners();
        return false;
      }
    } catch (_) {
      _error = 'Error de connexió. Comprova la teva xarxa.';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchProfile() async {
    try {
      final response = await _api.get(ApiConfig.profile);
      if (response['statusCode'] == 200) {
        _user = User.fromJson(response['body']);
        _status = AuthStatus.authenticated;
      } else {
        // Token invàlid o expirat sense possibilitat de refresh
        await _clearSession();
      }
    } catch (_) {
      await _clearSession();
    }
    notifyListeners();
  }

  Future<bool> updateProfile({
    String? username,
    String? email,
    int? diesAvisCaducitat,
  }) async {
    _error = null;

    try {
      final data = <String, dynamic>{};
      if (username != null) data['username'] = username;
      if (email != null) data['email'] = email;
      if (diesAvisCaducitat != null) data['dies_avis_caducitat'] = diesAvisCaducitat;

      final response = await _api.patch(ApiConfig.editProfile, data);

      if (response['statusCode'] == 200) {
        _user = User.fromJson(response['body']);
        notifyListeners();
        return true;
      } else {
        _error = _parseError(response['body'], 'Error en actualitzar el perfil');
        notifyListeners();
        return false;
      }
    } catch (_) {
      _error = 'Error de connexió. Comprova la teva xarxa.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    
    if (_api.hasTokens) {
      try {
        final refresh = _api.refreshToken;
        if (refresh != null) {
          await _api.post(ApiConfig.logout, {'refresh': refresh});
        }
      } catch (_) {
        // Ignorar errors de logout (p. ex. token ja invalidat)
      }
    }
    await _clearSession();
    notifyListeners();
  }

  Future<void> _clearSession() async {
    await _api.clearTokens();
    _user = null;
    _status = AuthStatus.unauthenticated;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}