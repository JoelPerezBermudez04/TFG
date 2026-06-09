class CompraItem {
  final int id;
  final int usuari;
  final int producte;
  final String? producteNom;
  final String? producteEmoji;
  final String? producteImatgeUrl;
  final int? categoriaId;
  final String? categoriaNom;
  final String? categoriaEmoji;
  final double quantitat;
  final String unitat;
  final bool comprat;
  final DateTime dataAfegit;

  CompraItem({
    required this.id,
    required this.usuari,
    required this.producte,
    this.producteNom,
    this.producteEmoji,
    this.producteImatgeUrl,
    this.categoriaId,
    this.categoriaNom,
    this.categoriaEmoji,
    required this.quantitat,
    required this.unitat,
    required this.comprat,
    required this.dataAfegit,
  });

  factory CompraItem.fromJson(Map<String, dynamic> json) {
    return CompraItem(
      id: json['id'],
      usuari: json['usuari'],
      producte: json['producte'],
      producteNom: json['producte_nom'],
      producteEmoji: json['producte_emoji'],
      producteImatgeUrl: json['producte_imatge_url'],
      categoriaId: json['categoria_id'],
      categoriaNom: json['categoria_nom'],
      categoriaEmoji: json['categoria_emoji'],
      quantitat: (json['quantitat'] as num).toDouble(),
      unitat: json['unitat'],
      comprat: json['comprat'] ?? false,
      dataAfegit: DateTime.parse(json['data_afegit']),
    );
  }

  CompraItem copyWith({bool? comprat}) {
    return CompraItem(
      id: id,
      usuari: usuari,
      producte: producte,
      producteNom: producteNom,
      producteEmoji: producteEmoji,
      producteImatgeUrl: producteImatgeUrl,
      categoriaId: categoriaId,
      categoriaNom: categoriaNom,
      categoriaEmoji: categoriaEmoji,
      quantitat: quantitat,
      unitat: unitat,
      comprat: comprat ?? this.comprat,
      dataAfegit: dataAfegit,
    );
  }
}