import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/receptes/providers/receptes_provider.dart';

void main() {
  // ─────────────────────────────────────────────
  // IngredientRecepta
  // ─────────────────────────────────────────────
  group('IngredientRecepta.fromJson', () {
    test('parseja tots els camps correctament', () {
      final json = {
        'producte': 3,
        'producte_nom': 'Ou',
        'producte_emoji': '🥚',
        'producte_imatge_url': 'https://example.com/ou.png',
        'quantitat': 2.0,
        'unitat': 'unitats',
        'nom_original': 'eggs',
      };
      final ing = IngredientRecepta.fromJson(json);

      expect(ing.producte, 3);
      expect(ing.producteNom, 'Ou');
      expect(ing.producteEmoji, '🥚');
      expect(ing.producteImatgeUrl, 'https://example.com/ou.png');
      expect(ing.quantitat, 2.0);
      expect(ing.unitat, 'unitats');
      expect(ing.nomOriginal, 'eggs');
    });

    test('usa valors per defecte quan els camps opcionals manquen', () {
      final json = {
        'producte': 5,
        'quantitat': 100,
        'unitat': 'g',
      };
      final ing = IngredientRecepta.fromJson(json);

      expect(ing.producteNom, '');
      expect(ing.producteEmoji, '🛒');
      expect(ing.producteImatgeUrl, isNull);
      expect(ing.nomOriginal, '');
    });

    test('parseja quantitat int com double', () {
      final json = {'producte': 1, 'quantitat': 3, 'unitat': 'unitat'};
      final ing = IngredientRecepta.fromJson(json);

      expect(ing.quantitat, 3.0);
      expect(ing.quantitat, isA<double>());
    });
  });

  // ─────────────────────────────────────────────
  // Recepta
  // ─────────────────────────────────────────────
  group('Recepta.fromJson', () {
    final jsonMinim = {
      'id_api': 'rec-001',
      'nom': 'Truita de patates',
      'temps_preparacio': 30,
      'porcions': 2,
      'ingredients': <dynamic>[],
    };

    test('parseja camps bàsics correctament', () {
      final r = Recepta.fromJson(jsonMinim);

      expect(r.idApi, 'rec-001');
      expect(r.nom, 'Truita de patates');
      expect(r.tempsPreparacio, 30);
      expect(r.porcions, 2);
      expect(r.ingredients, isEmpty);
    });

    test('camps opcionals són null quan manquen', () {
      final r = Recepta.fromJson(jsonMinim);

      expect(r.descripcio, isNull);
      expect(r.imatgeUrl, isNull);
      expect(r.instruccions, isNull);
      expect(r.dietes, isNull);
      expect(r.intolerancias, isNull);
    });

    test('parseja llista d\'ingredients', () {
      final json = {
        ...jsonMinim,
        'ingredients': [
          {'producte': 1, 'quantitat': 3, 'unitat': 'unitats'},
          {'producte': 2, 'quantitat': 200, 'unitat': 'g'},
        ],
      };
      final r = Recepta.fromJson(json);

      expect(r.ingredients, hasLength(2));
      expect(r.ingredients[0].producte, 1);
      expect(r.ingredients[1].producte, 2);
    });

    test('numIngredients ve de num_ingredients si existeix', () {
      final json = {
        ...jsonMinim,
        'num_ingredients': 5,
        'ingredients': [
          {'producte': 1, 'quantitat': 1.0, 'unitat': 'unitat'},
        ],
      };
      final r = Recepta.fromJson(json);

      expect(r.numIngredients, 5);
    });

    test('numIngredients es calcula des dels ingredients si no hi ha num_ingredients', () {
      final json = {
        ...jsonMinim,
        'ingredients': [
          {'producte': 1, 'quantitat': 1.0, 'unitat': 'unitat'},
          {'producte': 2, 'quantitat': 2.0, 'unitat': 'g'},
        ],
      };
      final r = Recepta.fromJson(json);

      expect(r.numIngredients, 2);
    });

    test('instruccions com strings es parsegen directament', () {
      final json = {
        ...jsonMinim,
        'instruccions': ['Pas 1: tallar', 'Pas 2: fregir'],
      };
      final r = Recepta.fromJson(json);

      expect(r.instruccions, ['Pas 1: tallar', 'Pas 2: fregir']);
    });

    test('instruccions com objectes extreuen el text', () {
      final json = {
        ...jsonMinim,
        'instruccions': [
          {'text': 'Pas 1: bullir aigua'},
          {'pas': 'Pas 2: afegir pasta'},
          {'step': 'Step 3: drain'},
        ],
      };
      final r = Recepta.fromJson(json);

      expect(r.instruccions, [
        'Pas 1: bullir aigua',
        'Pas 2: afegir pasta',
        'Step 3: drain',
      ]);
    });

    test('dietes i intolerancias es parsegen com List<String>', () {
      final json = {
        ...jsonMinim,
        'dietes': ['vegetariana', 'vegana'],
        'intolerancias': ['gluten'],
      };
      final r = Recepta.fromJson(json);

      expect(r.dietes, ['vegetariana', 'vegana']);
      expect(r.intolerancias, ['gluten']);
    });
  });

  // ─────────────────────────────────────────────
  // Recomanacio
  // ─────────────────────────────────────────────
  group('Recomanacio.fromJson', () {
    final jsonRec = {
      'id_api': 'rec-042',
      'nom': 'Arròs amb verdures',
      'imatge_url': 'https://example.com/arros.jpg',
      'temps_preparacio': 20,
      'porcions': 4,
      'dietes': ['vegetariana'],
      'intolerancias': <String>[],
      'score': 0.85,
      'ingredients_coberts': 5,
      'total_ingredients': 6,
    };

    test('parseja tots els camps', () {
      final rec = Recomanacio.fromJson(jsonRec);

      expect(rec.idApi, 'rec-042');
      expect(rec.nom, 'Arròs amb verdures');
      expect(rec.score, 0.85);
      expect(rec.ingredientsCoberts, 5);
      expect(rec.totalIngredients, 6);
      expect(rec.dietes, ['vegetariana']);
      expect(rec.intolerancias, isEmpty);
    });

    test('parseja score com int (cast a double)', () {
      final json = {...jsonRec, 'score': 1};
      final rec = Recomanacio.fromJson(json);

      expect(rec.score, 1.0);
      expect(rec.score, isA<double>());
    });

    test('imatge_url pot ser null', () {
      final json = {...jsonRec, 'imatge_url': null};
      final rec = Recomanacio.fromJson(json);

      expect(rec.imatgeUrl, isNull);
    });
  });

  // ─────────────────────────────────────────────
  // Recomanacio.toRecepta
  // ─────────────────────────────────────────────
  group('Recomanacio.toRecepta', () {
    test('converteix correctament a Recepta', () {
      final rec = Recomanacio.fromJson({
        'id_api': 'rec-099',
        'nom': 'Sopa de verdures',
        'imatge_url': null,
        'temps_preparacio': 45,
        'porcions': 3,
        'dietes': ['vegana'],
        'intolerancias': <String>[],
        'score': 0.6,
        'ingredients_coberts': 3,
        'total_ingredients': 5,
      });

      final recepta = rec.toRecepta();

      expect(recepta.idApi, rec.idApi);
      expect(recepta.nom, rec.nom);
      expect(recepta.tempsPreparacio, rec.tempsPreparacio);
      expect(recepta.porcions, rec.porcions);
      expect(recepta.dietes, rec.dietes);
      expect(recepta.numIngredients, rec.totalIngredients);
      expect(recepta.ingredients, isEmpty);
    });
  });

  // ─────────────────────────────────────────────
  // FavoritItem
  // ─────────────────────────────────────────────
  group('FavoritItem.fromJson', () {
    test('parseja tots els camps correctament', () {
      final json = {
        'id': 99,
        'recepta': 'rec-001',
        'recepta_nom': 'Truita de patates',
        'recepta_imatge_url': 'https://example.com/truita.jpg',
        'recepta_temps_preparacio': 30,
        'recepta_dietes': ['vegetariana'],
      };
      final fav = FavoritItem.fromJson(json);

      expect(fav.id, 99);
      expect(fav.receptaId, 'rec-001');
      expect(fav.receptaNom, 'Truita de patates');
      expect(fav.receptaImatgeUrl, 'https://example.com/truita.jpg');
      expect(fav.receptaTempsPreparacio, 30);
      expect(fav.receptaDietes, ['vegetariana']);
    });

    test('usa valors per defecte quan els camps opcionals manquen', () {
      final json = {'id': 1, 'recepta': null};
      final fav = FavoritItem.fromJson(json);

      expect(fav.receptaId, '');
      expect(fav.receptaNom, '');
      expect(fav.receptaImatgeUrl, isNull);
      expect(fav.receptaTempsPreparacio, 0);
      expect(fav.receptaDietes, isNull);
    });

    test('recepta amb valor int es converteix a String', () {
      final json = {
        'id': 2,
        'recepta': 12345,
        'recepta_nom': 'Test',
        'recepta_temps_preparacio': 10,
      };
      final fav = FavoritItem.fromJson(json);

      expect(fav.receptaId, '12345');
    });
  });
}