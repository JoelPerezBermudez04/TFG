class InventoryItem {
  final int id;
  final int usuari;
  final int producte;
  final String? producteNom;
  final String? producteEmoji;
  final String? producteImatgeUrl;
  final double quantitat;
  final String unitat;
  final DateTime? dataCaducitat;
  final DateTime dataAfegit;
  final bool caducat;

  InventoryItem({
    required this.id,
    required this.usuari,
    required this.producte,
    this.producteNom,
    this.producteEmoji,
    this.producteImatgeUrl,
    required this.quantitat,
    required this.unitat,
    this.dataCaducitat,
    required this.dataAfegit,
    required this.caducat,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'],
      usuari: json['usuari'],
      producte: json['producte'],
      producteNom: json['producte_nom'],
      producteEmoji: json['producte_emoji'],
      producteImatgeUrl: json['producte_imatge_url'],
      quantitat: (json['quantitat'] as num).toDouble(),
      unitat: json['unitat'],
      dataCaducitat: json['data_caducitat'] != null
          ? DateTime.parse(json['data_caducitat'])
          : null,
      dataAfegit: DateTime.parse(json['data_afegit']),
      caducat: json['caducat'] ?? false,
    );
  }

  int get daysUntilExpiry {
    if (dataCaducitat == null) return 999;
    return dataCaducitat!.difference(DateTime.now()).inDays;
  }

  ExpiryStatus get expiryStatus {
    if (dataCaducitat == null) return ExpiryStatus.none;
    final days = daysUntilExpiry;
    if (days < 0 || caducat) return ExpiryStatus.expired;
    if (days <= 2) return ExpiryStatus.urgent;
    if (days <= 5) return ExpiryStatus.soon;
    return ExpiryStatus.fresh;
  }
}

enum ExpiryStatus { none, expired, urgent, soon, fresh }

const List<String> unitOptions = ['g', 'kg', 'ml', 'L', 'unitat', 'unitats'];