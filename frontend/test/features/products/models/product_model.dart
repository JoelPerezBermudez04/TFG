class Category {
  final int id;
  final String nom;
  final String emoji;

  Category({
    required this.id,
    required this.nom,
    required this.emoji,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      nom: json['nom'],
      emoji: json['emoji'] ?? '🛒',
    );
  }
}

class Product {
  final int id;
  final String nom;
  final int categoriaId;
  final String? categoriaNom;
  final String emoji;
  final String? imatgeUrl;
  final int? diesCaducitatAprox;

  Product({
    required this.id,
    required this.nom,
    required this.categoriaId,
    this.categoriaNom,
    required this.emoji,
    this.imatgeUrl,
    this.diesCaducitatAprox,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      nom: json['nom'],
      categoriaId: json['categoria'],
      categoriaNom: json['categoria_nom'],
      emoji: json['emoji'] ?? '🛒',
      imatgeUrl: json['imatge_url'],
      diesCaducitatAprox: json['dies_caducitat_aprox'],
    );
  }

  DateTime? get suggestedExpiryDate {
    if (diesCaducitatAprox == null) return null;
    return DateTime.now().add(Duration(days: diesCaducitatAprox!));
  }
}