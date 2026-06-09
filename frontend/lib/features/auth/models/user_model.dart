class User {
  final int id;
  final String username;
  final String email;
  final String provider;
  final int diesAvisCaducitat;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.provider,
    required this.diesAvisCaducitat,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'] ?? '',
      provider: json['provider'] ?? 'LOCAL',
      diesAvisCaducitat: json['dies_avis_caducitat'] ?? 5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'provider': provider,
      'dies_avis_caducitat': diesAvisCaducitat,
    };
  }
}