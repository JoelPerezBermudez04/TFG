import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/inventari/models/inventory_item_model.dart';

void main() {
  InventoryItem makeItem({
    int id = 1,
    DateTime? dataCaducitat,
    DateTime? dataAfegit,
    bool caducat = false,
    double quantitat = 1.0,
    String unitat = 'unitat',
  }) {
    return InventoryItem(
      id: id,
      usuari: 1,
      producte: 1,
      producteNom: 'Test',
      quantitat: quantitat,
      unitat: unitat,
      dataCaducitat: dataCaducitat,
      dataAfegit: dataAfegit ?? DateTime.now(),
      caducat: caducat,
    );
  }

  group('InventoryItem.fromJson', () {
    test('mapeja tots els camps correctament', () {
      final json = {
        'id': 1,
        'usuari': 2,
        'producte': 3,
        'producte_nom': 'Llet',
        'producte_emoji': '🥛',
        'producte_imatge_url': 'https://example.com/llet.png',
        'producte_categoria_id': 5,
        'producte_categoria_nom': 'Làctics',
        'producte_categoria_emoji': '🧀',
        'quantitat': 2,
        'unitat': 'L',
        'data_caducitat': '2025-12-31',
        'data_afegit': '2025-01-01',
        'caducat': false,
      };

      final item = InventoryItem.fromJson(json);

      expect(item.id, 1);
      expect(item.usuari, 2);
      expect(item.producte, 3);
      expect(item.producteNom, 'Llet');
      expect(item.producteEmoji, '🥛');
      expect(item.producteImatgeUrl, 'https://example.com/llet.png');
      expect(item.producteCategoriaId, 5);
      expect(item.producteCategoriaNom, 'Làctics');
      expect(item.producteCategoriaEmoji, '🧀');
      expect(item.quantitat, 2.0);
      expect(item.unitat, 'L');
      expect(item.dataCaducitat, DateTime(2025, 12, 31));
      expect(item.dataAfegit, DateTime(2025, 1, 1));
      expect(item.caducat, false);
    });

    test('dataCaducitat és null quan no ve al JSON', () {
      final json = {
        'id': 1,
        'usuari': 1,
        'producte': 1,
        'quantitat': 1,
        'unitat': 'unitat',
        'data_caducitat': null,
        'data_afegit': '2025-01-01',
        'caducat': false,
      };

      final item = InventoryItem.fromJson(json);
      expect(item.dataCaducitat, isNull);
    });

    test('caducat és false per defecte si no ve al JSON', () {
      final json = {
        'id': 1,
        'usuari': 1,
        'producte': 1,
        'quantitat': 1,
        'unitat': 'unitat',
        'data_afegit': '2025-01-01',
      };

      final item = InventoryItem.fromJson(json);
      expect(item.caducat, false);
    });

    test('quantitat funciona amb valors decimal (num)', () {
      final json = {
        'id': 1,
        'usuari': 1,
        'producte': 1,
        'quantitat': 1.5,
        'unitat': 'kg',
        'data_afegit': '2025-01-01',
        'caducat': false,
      };

      final item = InventoryItem.fromJson(json);
      expect(item.quantitat, 1.5);
    });
  });

  group('InventoryItem.daysUntilExpiry', () {
    test('retorna 999 si no hi ha data de caducitat', () {
      final item = makeItem(dataCaducitat: null);
      expect(item.daysUntilExpiry, 999);
    });

    test('retorna 0 si caduca avui', () {
      final today = DateTime.now();
      final item = makeItem(dataCaducitat: DateTime(today.year, today.month, today.day));
      expect(item.daysUntilExpiry, 0);
    });

    test('retorna valor positiu si no ha caducat', () {
      final item = makeItem(
        dataCaducitat: DateTime.now().add(const Duration(days: 5)),
      );
      expect(item.daysUntilExpiry, 5);
    });

    test('retorna valor negatiu si ja ha caducat', () {
      final item = makeItem(
        dataCaducitat: DateTime.now().subtract(const Duration(days: 3)),
      );
      expect(item.daysUntilExpiry, -3);
    });
  });

  group('InventoryItem.expiryStatusFor', () {
    test('retorna none si no hi ha data de caducitat', () {
      final item = makeItem(dataCaducitat: null);
      expect(item.expiryStatusFor(5), ExpiryStatus.none);
    });

    test('retorna expired si caducat == true', () {
      final item = makeItem(
        dataCaducitat: DateTime.now().add(const Duration(days: 10)),
        caducat: true,
      );
      expect(item.expiryStatusFor(5), ExpiryStatus.expired);
    });

    test('retorna expired si daysUntilExpiry < 0', () {
      final item = makeItem(
        dataCaducitat: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(item.expiryStatusFor(5), ExpiryStatus.expired);
    });

    test('retorna urgent si caduca avui (0 dies)', () {
      final today = DateTime.now();
      final item = makeItem(
        dataCaducitat: DateTime(today.year, today.month, today.day),
      );
      expect(item.expiryStatusFor(5), ExpiryStatus.urgent);
    });

    test('retorna urgent si caduca en 1 dia', () {
      final item = makeItem(
        dataCaducitat: DateTime.now().add(const Duration(days: 1)),
      );
      expect(item.expiryStatusFor(5), ExpiryStatus.urgent);
    });

    test('retorna urgent si caduca en 2 dies', () {
      final item = makeItem(
        dataCaducitat: DateTime.now().add(const Duration(days: 2)),
      );
      expect(item.expiryStatusFor(5), ExpiryStatus.urgent);
    });

    test('retorna soon si caduca dins del període d\'avís', () {
      final item = makeItem(
        dataCaducitat: DateTime.now().add(const Duration(days: 4)),
      );
      expect(item.expiryStatusFor(5), ExpiryStatus.soon);
    });

    test('retorna fresh si caduca molt més tard', () {
      final item = makeItem(
        dataCaducitat: DateTime.now().add(const Duration(days: 30)),
      );
      expect(item.expiryStatusFor(5), ExpiryStatus.fresh);
    });

    test('soon respecta el paràmetre diesAvis personalitzat', () {
      final item = makeItem(
        dataCaducitat: DateTime.now().add(const Duration(days: 8)),
      );
      expect(item.expiryStatusFor(10), ExpiryStatus.soon);
      expect(item.expiryStatusFor(5), ExpiryStatus.fresh);
    });
  });

  group('InventoryItem.expiryStatus (getter per defecte, diesAvis=5)', () {
    test('retorna fresh per a producte amb 10 dies restants', () {
      final item = makeItem(
        dataCaducitat: DateTime.now().add(const Duration(days: 10)),
      );
      expect(item.expiryStatus, ExpiryStatus.fresh);
    });

    test('retorna soon per a producte amb 4 dies restants', () {
      final item = makeItem(
        dataCaducitat: DateTime.now().add(const Duration(days: 4)),
      );
      expect(item.expiryStatus, ExpiryStatus.soon);
    });
  });
}