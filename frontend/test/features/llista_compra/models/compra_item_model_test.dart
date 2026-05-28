import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/llista_compra/models/compra_item_model.dart';

void main() {
  final jsonComplet = {
    'id': 1,
    'usuari': 42,
    'producte': 7,
    'producte_nom': 'Pasta',
    'producte_emoji': '🍝',
    'producte_imatge_url': 'https://example.com/pasta.png',
    'categoria_id': 3,
    'categoria_nom': 'Cereals',
    'categoria_emoji': '🌾',
    'quantitat': 500.0,
    'unitat': 'g',
    'comprat': false,
    'data_afegit': '2024-03-15T10:30:00Z',
  };

  group('CompraItem.fromJson', () {
    test('parseja tots els camps correctament', () {
      final item = CompraItem.fromJson(jsonComplet);

      expect(item.id, 1);
      expect(item.usuari, 42);
      expect(item.producte, 7);
      expect(item.producteNom, 'Pasta');
      expect(item.producteEmoji, '🍝');
      expect(item.producteImatgeUrl, 'https://example.com/pasta.png');
      expect(item.categoriaId, 3);
      expect(item.categoriaNom, 'Cereals');
      expect(item.categoriaEmoji, '🌾');
      expect(item.quantitat, 500.0);
      expect(item.unitat, 'g');
      expect(item.comprat, isFalse);
      expect(item.dataAfegit, DateTime.parse('2024-03-15T10:30:00Z'));
    });

    test('parseja quantitat com int (cast a double)', () {
      final json = {...jsonComplet, 'quantitat': 2};
      final item = CompraItem.fromJson(json);

      expect(item.quantitat, 2.0);
      expect(item.quantitat, isA<double>());
    });

    test('comprat per defecte és false quan el camp manca', () {
      final json = Map<String, dynamic>.from(jsonComplet)..remove('comprat');
      final item = CompraItem.fromJson(json);

      expect(item.comprat, isFalse);
    });

    test('camps opcionals de producte poden ser null', () {
      final json = {
        'id': 2,
        'usuari': 1,
        'producte': 5,
        'quantitat': 1.0,
        'unitat': 'unitat',
        'comprat': true,
        'data_afegit': '2024-01-01T00:00:00Z',
      };
      final item = CompraItem.fromJson(json);

      expect(item.producteNom, isNull);
      expect(item.producteEmoji, isNull);
      expect(item.producteImatgeUrl, isNull);
      expect(item.categoriaId, isNull);
      expect(item.categoriaNom, isNull);
      expect(item.categoriaEmoji, isNull);
    });
  });

  group('CompraItem.copyWith', () {
    test('canvia comprat i conserva la resta de camps', () {
      final original = CompraItem.fromJson(jsonComplet);
      final copiat = original.copyWith(comprat: true);

      expect(copiat.comprat, isTrue);
      expect(copiat.id, original.id);
      expect(copiat.usuari, original.usuari);
      expect(copiat.producte, original.producte);
      expect(copiat.producteNom, original.producteNom);
      expect(copiat.quantitat, original.quantitat);
      expect(copiat.unitat, original.unitat);
      expect(copiat.dataAfegit, original.dataAfegit);
    });

    test('sense arguments conserva el valor original de comprat', () {
      final original = CompraItem.fromJson({...jsonComplet, 'comprat': true});
      final copiat = original.copyWith();

      expect(copiat.comprat, isTrue);
    });
  });
}