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

  Product({
    required this.id,
    required this.nom,
    required this.categoriaId,
    this.categoriaNom,
    required this.emoji,
    this.imatgeUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      nom: json['nom'],
      categoriaId: json['categoria'],
      categoriaNom: json['categoria_nom'],
      emoji: json['emoji'] ?? '🛒',
      imatgeUrl: json['imatge_url'],
    );
  }
}