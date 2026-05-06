import json
import os
import re
import time
from pathlib import Path

import requests
from django.core.management.base import BaseCommand

from myapp.models import IngredientRecepta, Producte, Recepta

SPOONACULAR_IMG_BASE = 'https://img.spoonacular.com/recipes/'

INGREDIENTS_NO_TROBATS_PATH = Path('ingredients_no_trobats.json')

RECIPE_QUERIES = [
    # Pasta i arròs
    "pasta carbonara", "pasta bolognese", "pasta arrabiata",
    "risotto mushroom", "paella", "fried rice",
    # Carns
    "chicken curry", "roast chicken", "chicken stir fry",
    "beef stew", "beef burger", "meatballs tomato sauce",
    "pork tenderloin", "lamb chops",
    # Peix
    "salmon fillet", "tuna salad", "shrimp garlic", "baked cod",
    # Vegetarians
    "vegetable soup", "lentil soup", "chickpea curry", "vegetable stir fry",
    "caprese salad", "greek salad", "guacamole", "hummus",
    # Ous i làctics
    "omelette", "scrambled eggs", "frittata", "quiche",
    # Sopes i cremes
    "tomato soup", "minestrone", "gazpacho", "potato soup",
    # Postres
    "chocolate cake", "pancakes", "banana bread", "apple pie",
    # Esmorzars
    "overnight oats", "smoothie bowl", "avocado toast",
    # Snacks i aperitius
    "bruschetta", "spring rolls", "nachos",
]

# ── Unitats ───────────────────────────────────────────────────────────────────

UNIT_MAP = {
    'gram': 'g', 'grams': 'g', 'g': 'g',
    'kilogram': 'kg', 'kilograms': 'kg', 'kg': 'kg',
    'ounce': 'g', 'ounces': 'g', 'oz': 'g',
    'pound': 'kg', 'pounds': 'kg', 'lb': 'kg', 'lbs': 'kg',
    'milliliter': 'ml', 'milliliters': 'ml', 'ml': 'ml',
    'liter': 'L', 'liters': 'L', 'l': 'L',
    'cup': 'ml', 'cups': 'ml',
    'tablespoon': 'ml', 'tablespoons': 'ml', 'tbsp': 'ml',
    'teaspoon': 'ml', 'teaspoons': 'ml', 'tsp': 'ml',
    'fluid ounce': 'ml', 'fluid ounces': 'ml', 'fl oz': 'ml',
}

UNIT_FACTORS = {
    'cup': 240, 'cups': 240,
    'tablespoon': 15, 'tablespoons': 15, 'tbsp': 15,
    'teaspoon': 5, 'teaspoons': 5, 'tsp': 5,
    'fluid ounce': 30, 'fluid ounces': 30, 'fl oz': 30,
    'ounce': 28, 'ounces': 28, 'oz': 28,
    'pound': 0.45, 'pounds': 0.45, 'lb': 0.45, 'lbs': 0.45,
}

UNITATS_COMPTABLES = {
    'large', 'small', 'medium', 'whole', 'slice', 'slices',
    'clove', 'cloves', 'pinch', 'pinches', 'bunch', 'head',
    'sprig', 'sprigs', 'leaf', 'leaves', 'serving', 'servings',
    'piece', 'pieces', 'stalk', 'stalks', 'can', 'cans',
}


def normalitzar_unitat_i_quantitat(unit_raw, quantitat):
    unit_lower = (unit_raw or '').lower().strip()
    if not unit_lower or unit_lower in UNITATS_COMPTABLES:
        return 'unitat', quantitat
    factor = UNIT_FACTORS.get(unit_lower, 1)
    unitat = UNIT_MAP.get(unit_lower, 'unitat')
    quantitat_ajustada = round(quantitat * factor, 2) if factor != 1 else quantitat
    return unitat, quantitat_ajustada


# ── Dietes i intoleràncies ────────────────────────────────────────────────────

DIETES_CAMPS = [
    ('vegetarian', 'vegetarian'),
    ('vegan', 'vegan'),
    ('glutenFree', 'gluten free'),
    ('dairyFree', 'dairy free'),
    ('veryHealthy', 'very healthy'),
    ('cheap', 'cheap'),
    ('veryPopular', 'very popular'),
    ('sustainable', 'sustainable'),
    ('lowFodmap', 'low fodmap'),
    ('ketogenic', 'ketogenic'),
    ('whole30', 'whole30'),
]


def extreure_dietes(data):
    return [label for camp, label in DIETES_CAMPS if data.get(camp, False)]


def extreure_intolerancias(data):
    return data.get('diets', [])


# ── Instruccions ──────────────────────────────────────────────────────────────

def extreure_instruccions(data):
    analyzed = data.get('analyzedInstructions', [])
    if analyzed:
        passos = []
        num = 1
        for bloc in analyzed:
            for step in bloc.get('steps', []):
                text = step.get('step', '').strip()
                if text:
                    passos.append({'num': num, 'text': text})
                    num += 1
        if passos:
            return passos

    instruccions_html = data.get('instructions', '') or ''
    text_pla = re.sub(r'<[^>]+>', ' ', instruccions_html).strip()
    text_pla = re.sub(r'\s+', ' ', text_pla)
    if text_pla:
        return [{'num': 1, 'text': text_pla}]

    return None


# ── Neteja i normalització de noms d'ingredients ─────────────────────────────

# Ingredients que no volem vincular a cap producte perquè són massa genèrics
# o no aporten valor a la llista de la compra (quantitats mínimes, "to taste"...).
# Afegeix aquí qualsevol ingredient que vulguis ignorar globalment.
INGREDIENTS_IGNORATS = {
    # Genèrics sense valor informatiu
    'water', 'ice', 'ice water',
    # Salses i condiments de marca / molt específics
    'homemade sauce',
    # Descripcions, no ingredients
    'sauce', 'seasoning', 'spices', 'mixed spices',
}

# Paraules soroll que apareixen als noms d'ingredients de l'API i que
# convé eliminar abans de fer el matching per millorar els resultats.
_SOROLL_PATTERNS = [
    # Adjectius de temperatura i preparació
    r'\b(fresh|frozen|thawed|room temperature|cold|warm|hot)\b',
    # Adjectius de tall
    r'\b(chopped|diced|sliced|minced|grated|shredded|peeled|seeded|'
    r'quartered|halved|cubed|mashed|crushed|ground|beaten|whisked)\b',
    # Adjectius de qualitat/tipus genèrics
    r'\b(large|small|medium|big|whole|lean|thick|thin|'
    r'ripe|firm|raw|cooked|dried|canned|organic|plain|'
    r'good.quality|good quality|best quality)\b',
    # Frases de quantitat al final
    r',\s*(to taste|according to taste|adjust to taste|as needed|as required|'
    r'or to taste|at room temperature|if needed|optional).*$',
    # Frases amb "to taste" sense coma
    r'\s+to taste$',
    # Números i fraccions al principi (per si arriba el nom_original)
    r'^[\d\s/¼½¾⅓⅔⅛⅜⅝⅞]+',
    # Unitats al principi (per si arriba el nom_original)
    r'^(teaspoon|tablespoon|cup|ounce|pound|gram|tsp|tbsp|oz|lb|g|ml|liter|l)\b\s*',
    # Parèntesis i el seu contingut
    r'\([^)]*\)',
    # Asterisc i el que ve després
    r'\*.*$',
]
_SOROLL_RE = [re.compile(p, re.IGNORECASE) for p in _SOROLL_PATTERNS]


def netejar_nom_ingredient(nom_raw: str) -> str:
    """
    Elimina soroll del nom d'un ingredient per millorar el matching.

    Exemples:
      "2 large eggs, beaten"          → "eggs"
      "salt to taste"                 → "salt"
      "Salt to taste"                 → "salt"
      "1/2 teaspoon salt"             → "salt"
      "3 carrots cut into cubes"      → "carrots"
      "fresh basil, chopped"          → "basil"
      "1 Bay Leaf"                    → "bay leaf"
      "½ pound ground pork *see notes"→ "pork"
    """
    nom = nom_raw.strip()

    # Aplica tots els patrons de soroll
    for pattern in _SOROLL_RE:
        nom = pattern.sub(' ', nom)

    # Elimina espais múltiples i caràcters residuals
    nom = re.sub(r'[\s,]+$', '', nom)   # coma o espai al final
    nom = re.sub(r'\s+', ' ', nom)
    nom = nom.strip().lower()

    return nom


# ── Cache de productes ────────────────────────────────────────────────────────

def _carregar_cache_productes():
    cache = []
    for p in Producte.objects.all():
        noms = [p.nom.lower()]
        if p.alias_api and isinstance(p.alias_api, dict):
            # Indexem tant nom_en com nom_en_query (guardat per v4)
            for camp in ('nom_en', 'nom_en_query'):
                val = p.alias_api.get(camp, '')
                if val:
                    noms.append(val.lower())
        cache.append((p, noms))
    return cache


def buscar_producte(nom_ingredient: str, cache: list, fuzzy_threshold: int = 75):
    """
    Cerca el producte a la BD pel nom o alias_api.

    Passos:
      0. Ignora ingredients de la blocklist
      1. Cerca exacta pel nom net (català i anglès)
      2. Cerca exacta pel nom en brut (per compatibilitat)
      3. Cerca parcial (icontains)
      4. Fuzzy matching amb token_set_ratio
      5. Reintenta amb el nom netejat si el nom original no ha funcionat

    Retorna el Producte trobat o None.
    """
    from thefuzz import fuzz

    nom_lower = nom_ingredient.lower().strip()

    # ── Pas 0: blocklist ─────────────────────────────────────────────────────
    if nom_lower in INGREDIENTS_IGNORATS:
        return None

    # Neteja el nom per millorar el matching
    nom_net = netejar_nom_ingredient(nom_lower)

    # Si el nom net és buit o massa curt, descarta
    if len(nom_net) < 2:
        return None

    # Ignora també el nom net si és a la blocklist
    if nom_net in INGREDIENTS_IGNORATS:
        return None

    def _cerca_exacta(nom):
        try:
            return Producte.objects.get(nom__iexact=nom)
        except Producte.DoesNotExist:
            return None
        except Producte.MultipleObjectsReturned:
            return Producte.objects.filter(nom__iexact=nom).first()

    def _cerca_alias(nom):
        return (
            Producte.objects.filter(alias_api__nom_en__iexact=nom).first()
            or Producte.objects.filter(alias_api__nom_en_query__iexact=nom).first()
        )

    def _cerca_parcial(nom):
        return (
            Producte.objects.filter(nom__icontains=nom).first()
            or Producte.objects.filter(alias_api__nom_en__icontains=nom).first()
            or Producte.objects.filter(alias_api__nom_en_query__icontains=nom).first()
        )

    # ── Pas 1 & 2: cerca exacta (nom net i nom original) ────────────────────
    for nom in (nom_net, nom_lower):
        p = _cerca_exacta(nom) or _cerca_alias(nom)
        if p:
            return p

    # ── Pas 3: cerca parcial (nom net primer, després original) ─────────────
    for nom in (nom_net, nom_lower):
        if len(nom) >= 3:
            p = _cerca_parcial(nom)
            if p:
                return p

    # ── Pas 4: fuzzy sobre el nom net ────────────────────────────────────────
    millor_producte, millor_score = None, 0
    for producte, noms_producte in cache:
        for nom_p in noms_producte:
            # Compara tant el nom net com l'original contra cada nom del producte
            score = max(
                fuzz.token_set_ratio(nom_net, nom_p),
                fuzz.token_set_ratio(nom_lower, nom_p),
            )
            if score > millor_score:
                millor_score = score
                millor_producte = producte

    return millor_producte if millor_score >= fuzzy_threshold else None


# ── Lògica de quines receptes necessiten crida a l'API ───────────────────────

def _recepta_necessita_actualitzacio(recepta_id):
    try:
        r = Recepta.objects.get(pk=recepta_id)
    except Recepta.DoesNotExist:
        return True

    manca_instruccions = r.instruccions is None
    manca_dietes = r.dietes is None
    manca_intolerancias = r.intolerancias is None
    manca_porcions = r.porcions == 1
    manca_ingredients = not r.ingredientrecepta_set.exists()

    return any([manca_instruccions, manca_dietes, manca_intolerancias,
                manca_porcions, manca_ingredients])


# ── Gestió del fitxer d'ingredients no trobats ───────────────────────────────

def _carregar_no_trobats():
    if INGREDIENTS_NO_TROBATS_PATH.exists():
        with open(INGREDIENTS_NO_TROBATS_PATH, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {}


def _guardar_no_trobats(data):
    with open(INGREDIENTS_NO_TROBATS_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def _registrar_no_trobats(no_trobats_global, recepta_nom, recepta_id, ingredients):
    if not ingredients:
        return
    no_trobats_global[recepta_id] = {
        'recepta': recepta_nom,
        'ingredients_no_trobats': ingredients,
    }


# ── Command principal ─────────────────────────────────────────────────────────

class Command(BaseCommand):
    help = 'Pobla la BD amb receptes de Spoonacular i les vincula als productes existents'

    def add_arguments(self, parser):
        parser.add_argument('--api-key', type=str, help='Spoonacular API key')
        parser.add_argument('--dry-run', action='store_true', help='Mostra el resultat sense guardar')
        parser.add_argument('--force', action='store_true',
                            help='Força la recrida a l\'API i actualitza totes les receptes')
        parser.add_argument('--number', type=int, default=3,
                            help='Receptes per query (default: 3)')
        parser.add_argument('--min-ingredients', type=int, default=3,
                            help='Mínim d\'ingredients vinculats per guardar la recepta (default: 3)')
        parser.add_argument('--fuzzy-threshold', type=int, default=75,
                            help='Llindar de similitud fuzzy 0-100 (default: 75)')
        parser.add_argument('--relink', action='store_true',
                            help='Re-vincula ingredients de totes les receptes existents '
                                 'amb la cache de productes actualitzada. '
                                 'No fa cap crida a l\'API.')

    def handle(self, *args, **options):
        api_key = options.get('api_key') or os.environ.get('SPOONACULAR_API_KEY')
        if not api_key:
            self.stderr.write(self.style.ERROR(
                'Cal una API key. Usa --api-key o defineix SPOONACULAR_API_KEY al .env'
            ))
            return

        dry_run = options['dry_run']
        force = options['force']
        number = options['number']
        min_ingredients = options['min_ingredients']
        fuzzy_threshold = options['fuzzy_threshold']
        relink = options['relink']

        stats = {'creades': 0, 'actualitzades': 0, 'saltades': 0, 'descartades': 0}
        ids_processats = set()
        no_trobats_global = _carregar_no_trobats()

        self.stdout.write('⏳ Carregant cache de productes...')
        cache_productes = _carregar_cache_productes()
        self.stdout.write(f'✓ {len(cache_productes)} productes carregats a la cache\n')

        if relink:
            self._relink_receptes(cache_productes, fuzzy_threshold, dry_run)
            return

        self.stdout.write(self.style.SUCCESS(
            f'🍽️  Iniciant càrrega de receptes ({len(RECIPE_QUERIES)} queries, {number} per query)\n'
        ))

        for query in RECIPE_QUERIES:
            self.stdout.write(f'\n🔍 Query: "{query}"')

            try:
                resp = requests.get(
                    'https://api.spoonacular.com/recipes/complexSearch',
                    params={
                        'apiKey': api_key,
                        'query': query,
                        'number': number,
                        'language': 'en',
                    },
                    timeout=15,
                )
                resp.raise_for_status()
                resultats_basics = resp.json().get('results', [])

                if not resultats_basics:
                    self.stdout.write('  (sense resultats)')
                    continue

                for recepta_basica in resultats_basics:
                    recepta_id = str(recepta_basica['id'])
                    nom_basic = recepta_basica.get('title', '')

                    if recepta_id in ids_processats:
                        continue
                    ids_processats.add(recepta_id)

                    if not force and not _recepta_necessita_actualitzacio(recepta_id):
                        self.stdout.write(f'  ✓ "{nom_basic}" (completa, saltant)')
                        stats['saltades'] += 1
                        continue

                    time.sleep(0.3)
                    resp2 = requests.get(
                        f'https://api.spoonacular.com/recipes/{recepta_id}/information',
                        params={
                            'apiKey': api_key,
                            'includeNutrition': False,
                        },
                        timeout=15,
                    )
                    if resp2.status_code == 402:
                        self.stderr.write(self.style.ERROR(
                            '\n💳 Límit diari de la API assolit. Torna a executar l\'script demà.'
                        ))
                        self._resum(stats, dry_run, no_trobats_global)
                        return
                    resp2.raise_for_status()
                    recepta_data = resp2.json()

                    nom = recepta_data.get('title', nom_basic)

                    imatge = recepta_data.get('image', '')
                    temps = recepta_data.get('readyInMinutes', 0)
                    porcions = recepta_data.get('servings', 1) or 1
                    resum_net = re.sub(r'<[^>]+>', '', recepta_data.get('summary', '')).strip()

                    dietes = extreure_dietes(recepta_data)
                    intolerancias = extreure_intolerancias(recepta_data)
                    instruccions = extreure_instruccions(recepta_data)

                    ingredients_raw = recepta_data.get('extendedIngredients', [])
                    ingredients_vinculats = []
                    ingredients_no_trobats = []

                    for ing in ingredients_raw:
                        # L'API retorna "name" (nom net) i "original" (amb quantitat i unitat).
                        # Usem "name" com a base però li apliquem la neteja igualment per
                        # eliminar adjectius com "fresh", "large", "chopped", etc.
                        nom_ing = ing.get('name', '')
                        quantitat = ing.get('amount', 1.0) or 1.0
                        unit_raw = ing.get('unit', '')
                        nom_original = ing.get('original', nom_ing)

                        producte = buscar_producte(nom_ing, cache_productes, fuzzy_threshold)
                        unitat, quantitat_final = normalitzar_unitat_i_quantitat(unit_raw, quantitat)

                        if producte:
                            ingredients_vinculats.append({
                                'producte': producte,
                                'quantitat': quantitat_final,
                                'unitat': unitat,
                                'nom_original': nom_original[:255],
                            })
                        else:
                            # Guarda el nom net (no l'original) per facilitar la revisió
                            nom_no_trobat = netejar_nom_ingredient(nom_ing) or nom_ing
                            ingredients_no_trobats.append(nom_no_trobat)

                    if len(ingredients_vinculats) < min_ingredients:
                        self.stdout.write(
                            f'  ⏭️  "{nom}" — massa pocs ingredients a la BD '
                            f'({len(ingredients_vinculats)}/{len(ingredients_raw)}), descartant...'
                        )
                        stats['descartades'] += 1
                        continue

                    _registrar_no_trobats(
                        no_trobats_global, nom, recepta_id, ingredients_no_trobats
                    )

                    if dry_run:
                        te_instruccions = '✓' if instruccions else '✗'
                        self.stdout.write(
                            f'  [DRY] "{nom}" | ⏱️ {temps}min | 👥 {porcions}p | '
                            f'🔗 {len(ingredients_vinculats)}/{len(ingredients_raw)} ing | '
                            f'📋 instruccions:{te_instruccions} | '
                            f'🥗 {", ".join(dietes) or "cap dieta"}'
                        )
                        if ingredients_no_trobats:
                            self.stdout.write(
                                f'       ⚠️  No trobats: {", ".join(ingredients_no_trobats[:5])}'
                                + (' ...' if len(ingredients_no_trobats) > 5 else '')
                            )
                        stats['creades'] += 1
                        continue

                    existia = Recepta.objects.filter(pk=recepta_id).exists()
                    recepta, _ = Recepta.objects.update_or_create(
                        id_api=recepta_id,
                        defaults={
                            'nom': nom,
                            'descripcio': resum_net[:2000],
                            'imatge_url': imatge,
                            'temps_preparacio': temps,
                            'porcions': porcions,
                            'instruccions': instruccions,
                            'dietes': dietes,
                            'intolerancias': intolerancias,
                        }
                    )

                    vistos_producte_ids = set()
                    ingredients_finals = []
                    for ing_data in ingredients_vinculats:
                        pid = ing_data['producte'].pk
                        if pid not in vistos_producte_ids:
                            vistos_producte_ids.add(pid)
                            ingredients_finals.append(ing_data)

                    IngredientRecepta.objects.filter(recepta=recepta).delete()
                    for ing_data in ingredients_finals:
                        IngredientRecepta.objects.create(
                            recepta=recepta,
                            producte=ing_data['producte'],
                            quantitat=ing_data['quantitat'],
                            unitat=ing_data['unitat'],
                            nom_original=ing_data['nom_original'],
                        )

                    estat = '↺ Actualitzada' if existia else '✓ Nova'
                    if existia:
                        stats['actualitzades'] += 1
                    else:
                        stats['creades'] += 1

                    te_instruccions = f"{len(instruccions)}p" if instruccions else '✗'
                    self.stdout.write(
                        f'  {estat}: "{nom}" | ⏱️ {temps}min | 👥 {porcions}p | '
                        f'🔗 {len(ingredients_vinculats)}/{len(ingredients_raw)} ing | '
                        f'📋 {te_instruccions} | 🥗 {", ".join(dietes) or "—"}'
                    )
                    if ingredients_no_trobats:
                        self.stdout.write(
                            f'       ⚠️  No trobats: {", ".join(ingredients_no_trobats[:5])}'
                            + (' ...' if len(ingredients_no_trobats) > 5 else '')
                        )

                time.sleep(0.5)

            except requests.exceptions.HTTPError as e:
                if e.response.status_code == 402:
                    self.stderr.write(self.style.ERROR(
                        '\n💳 Límit diari de la API assolit. Torna a executar l\'script demà.'
                    ))
                    self._resum(stats, dry_run, no_trobats_global)
                    return
                self.stderr.write(self.style.WARNING(f'  ❌ Error HTTP per "{query}": {e}'))
            except requests.exceptions.RequestException as e:
                self.stderr.write(self.style.WARNING(f'  ❌ Error de xarxa per "{query}": {e}'))

        prefix = '[DRY RUN] ' if dry_run else ''
        self.stdout.write(self.style.SUCCESS(f'\n{prefix}✅ Fet!'))
        self._resum(stats, dry_run, no_trobats_global)

    def _relink_receptes(self, cache_productes, fuzzy_threshold, dry_run):
        from myapp.models import Recepta as R
        no_trobats_global = {}
        total_receptes = 0
        total_nous_vincles = 0
        total_no_trobats = 0

        self.stdout.write(self.style.SUCCESS("🔗 Mode relink — sense crides a l'API\n"))

        for recepta in R.objects.prefetch_related('ingredientrecepta_set__producte').all():
            ingredients_actuals = list(
                recepta.ingredientrecepta_set.select_related('producte').all()
            )

            ingredients_nous = []
            ingredients_no_trobats = []

            for ing in ingredients_actuals:
                nom_original = ing.nom_original or ing.producte.nom
                producte_nou = buscar_producte(nom_original, cache_productes, fuzzy_threshold)
                if producte_nou:
                    ingredients_nous.append({
                        'producte': producte_nou,
                        'quantitat': ing.quantitat,
                        'unitat': ing.unitat,
                        'nom_original': ing.nom_original,
                    })
                else:
                    nom_no_trobat = netejar_nom_ingredient(nom_original) or nom_original
                    ingredients_no_trobats.append(nom_no_trobat)

            if ingredients_no_trobats:
                _registrar_no_trobats(
                    no_trobats_global, recepta.nom, recepta.id_api, ingredients_no_trobats
                )

            if not dry_run:
                ids_actuals = {ing.producte_id for ing in ingredients_actuals}
                ids_nous = {d['producte'].pk for d in ingredients_nous}
                if ids_actuals != ids_nous:
                    vistos = set()
                    finals = []
                    for d in ingredients_nous:
                        if d['producte'].pk not in vistos:
                            vistos.add(d['producte'].pk)
                            finals.append(d)
                    recepta.ingredientrecepta_set.all().delete()
                    for d in finals:
                        recepta.ingredientrecepta_set.create(
                            producte=d['producte'],
                            quantitat=d['quantitat'],
                            unitat=d['unitat'],
                            nom_original=d['nom_original'],
                        )
                    total_nous_vincles += 1

            total_receptes += 1
            total_no_trobats += len(ingredients_no_trobats)

        if not dry_run:
            _guardar_no_trobats(no_trobats_global)

        prefix = '[DRY RUN] ' if dry_run else ''
        self.stdout.write(self.style.SUCCESS(f'\n{prefix}✅ Relink fet!'))
        self.stdout.write(
            f'\n📊 Resum:\n'
            f'  🔗 {total_receptes} receptes processades\n'
            f'  ↺  {total_nous_vincles} receptes amb vincles actualitzats\n'
            f'  ⚠️  {total_no_trobats} ingredients encara no trobats\n'
            f'     → Consulta {INGREDIENTS_NO_TROBATS_PATH} per revisar-los\n'
        )

    def _resum(self, stats, dry_run, no_trobats_global):
        if not dry_run:
            _guardar_no_trobats(no_trobats_global)
            n_receptes_amb_no_trobats = len(no_trobats_global)
            n_total_no_trobats = sum(
                len(v['ingredients_no_trobats']) for v in no_trobats_global.values()
            )

        self.stdout.write(
            f'\n📊 Resum:\n'
            f'  ✓ {stats["creades"]} receptes noves\n'
            f'  ↺ {stats["actualitzades"]} receptes actualitzades\n'
            f'  ✓ {stats["saltades"]} receptes ja completes (sense crida API)\n'
            f'  ⏭️  {stats["descartades"]} descartades (pocs ingredients)\n'
        )
        if not dry_run:
            self.stdout.write(
                f'  ⚠️  {n_total_no_trobats} ingredients no trobats en '
                f'{n_receptes_amb_no_trobats} receptes\n'
                f'     → Consulta {INGREDIENTS_NO_TROBATS_PATH} per revisar-los\n'
            )