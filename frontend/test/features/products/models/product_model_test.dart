import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/products/models/product_model.dart';

void main() {
  group('Category.fromJson', () {
    test('parseja tots els camps correctament', () {
      final json = {'id': 1, 'nom': 'Fruites', 'emoji': '🍎'};
      final cat = Category.fromJson(json);

      expect(cat.id, 1);
      expect(cat.nom, 'Fruites');
      expect(cat.emoji, '🍎');
    });

    test('usa emoji per defecte quan el camp manca', () {
      final json = {'id': 2, 'nom': 'Verdures'};
      final cat = Category.fromJson(json);

      expect(cat.emoji, '🛒');
    });

    test('usa emoji per defecte quan el camp és null', () {
      final json = {'id': 3, 'nom': 'Làctics', 'emoji': null};
      final cat = Category.fromJson(json);

      expect(cat.emoji, '🛒');
    });
  });

  group('Product.fromJson', () {
    test('parseja tots els camps correctament', () {
      final json = {
        'id': 10,
        'nom': 'Tomàquet',
        'categoria': 5,
        'categoria_nom': 'Verdures',
        'emoji': '🍅',
        'imatge_url': 'https://example.com/tomaquet.png',
        'dies_caducitat_aprox': 7,
      };
      final p = Product.fromJson(json);

      expect(p.id, 10);
      expect(p.nom, 'Tomàquet');
      expect(p.categoriaId, 5);
      expect(p.categoriaNom, 'Verdures');
      expect(p.emoji, '🍅');
      expect(p.imatgeUrl, 'https://example.com/tomaquet.png');
      expect(p.diesCaducitatAprox, 7);
    });

    test('camps opcionals poden ser null', () {
      final json = {
        'id': 11,
        'nom': 'Pa',
        'categoria': 3,
        'emoji': '🍞',
      };
      final p = Product.fromJson(json);

      expect(p.categoriaNom, isNull);
      expect(p.imatgeUrl, isNull);
      expect(p.diesCaducitatAprox, isNull);
    });

    test('usa emoji per defecte quan el camp és null', () {
      final json = {
        'id': 12,
        'nom': 'Iogurt',
        'categoria': 2,
        'emoji': null,
      };
      final p = Product.fromJson(json);

      expect(p.emoji, '🛒');
    });
  });

  group('Product.suggestedExpiryDate', () {
    test('retorna null si diesCaducitatAprox és null', () {
      final json = {'id': 1, 'nom': 'Test', 'categoria': 1, 'emoji': '🛒'};
      final p = Product.fromJson(json);

      expect(p.suggestedExpiryDate, isNull);
    });

    test('retorna una data futura aproximada quan hi ha dies', () {
      final json = {
        'id': 1,
        'nom': 'Llet',
        'categoria': 1,
        'emoji': '🥛',
        'dies_caducitat_aprox': 5,
      };
      final p = Product.fromJson(json);
      final ara = DateTime.now();
      final suggerida = p.suggestedExpiryDate!;

      // Ha d'estar a 5 dies aproximadament (marge d'1 segon per execució lenta)
      expect(suggerida.isAfter(ara.add(const Duration(days: 4))), isTrue);
      expect(suggerida.isBefore(ara.add(const Duration(days: 6))), isTrue);
    });
  });
}