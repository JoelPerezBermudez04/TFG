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
    #"beef stew", "beef burger", "meatballs tomato sauce",
    "pork tenderloin", #"lamb chops",
    # Peix
    "salmon fillet", #"tuna salad", "shrimp garlic", "baked cod",
    # Vegetarians
    "vegetable soup", "lentil soup", "chickpea curry", "vegetable stir fry",
    "caprese salad", #"greek salad", 
    #"guacamole", "hummus",
    # Ous i làctics
    #"omelette", "scrambled eggs", "frittata", "quiche",
    # Sopes i cremes
    "tomato soup", "minestrone", "gazpacho", #"potato soup",
    # Postres
    #"chocolate cake", "pancakes", "banana bread", "apple pie",
    # Esmorzars
    #"overnight oats", "smoothie bowl", "avocado toast",
    # Snacks i aperitius
    #"bruschetta", "spring rolls", "nachos",
    #  ── Receptes catalanes ──────────────────────────────────────────
    "escalivada", "pa amb tomàquet", "esqueixada", "botifarra",
    "calcots", "coca de recapte", "fideuà", "crema catalana",
    "suquet de peix", "conill a la xocolata", "mongetes amb botifarra",
    "pan con tomate", "escalivada amb botifarra",
    # ── Receptes espanyoles ──────────────────────────────────────────
    "gazpacho andaluz", "salmorejo", "espinacas con garbanzos",
    "bacalao a la vizcaina", "caldo gallego", "pulpo a la gallega",
    "rabo de toro", "pan tumaca", "jamón ibérico",
    "chorizo a la sidra", "fabada asturiana", "morcilla",
    "croquetas jamón", "patatas bravas", "ali oli",
    "esqueixada", "espaguetis a banda", "arroz a banda",
    "all i pebre", "esgarraet", "buñuelos", "torrijas",
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
 
# Paraules clau que indiquen que un pas és una instrucció de cuina real
_COOKING_KEYWORDS = re.compile(
    r'\b(heat|cook|bake|boil|fry|mix|stir|add|place|preheat|season|'
    r'combine|chop|slice|dice|pour|cover|remove|serve|prepare|cut|'
    r'bring|reduce|simmer|roast|grill|drain|rinse|whisk|fold|toss|'
    r'spread|sprinkle|top|transfer|set|let|allow|rest|cool|melt|'
    r'sauté|saute|blend|pulse|process|squeeze|brush|coat|roll|press|'
    r'marinate|season|taste|adjust|garnish|arrange|layer|repeat|continue|'
    r'meanwhile|next|then|finally|once|until|when)\b',
    re.IGNORECASE
)
 
# Longitud mínima i màxima d'un pas vàlid (en caràcters)
_MIN_STEP_LEN = 20
_MAX_STEP_LEN = 1500
 
# Si un pas conté massa paraules d'ingredient (llista d'ingredients colada), descarta'l
_INGREDIENT_LIST_RE = re.compile(
    r'^\s*(\d[^.]*\n){3,}',  # 3+ línies que comencen per número = llista
)
 
 
def _es_pas_valid(text: str) -> bool:
    """Retorna True si el text sembla una instrucció de cuina real."""
    if len(text) < _MIN_STEP_LEN or len(text) > _MAX_STEP_LEN:
        return False
    # Ha de tenir almenys una paraula clau de cuina
    if not _COOKING_KEYWORDS.search(text):
        return False
    return True
 
 
def extreure_instruccions(data):
    analyzed = data.get('analyzedInstructions', [])
    if analyzed:
        passos = []
        num = 1
        for bloc in analyzed:
            for step in bloc.get('steps', []):
                text = step.get('step', '').strip()
                if text and _es_pas_valid(text):
                    passos.append({'num': num, 'text': text})
                    num += 1
        if passos:
            return passos
 
    # Fallback: instruccions en HTML → text pla, partir per punts/salts de línia
    instruccions_html = data.get('instructions', '') or ''
    text_pla = re.sub(r'<[^>]+>', ' ', instruccions_html).strip()
    text_pla = re.sub(r'\s+', ' ', text_pla)
    if text_pla and _es_pas_valid(text_pla):
        return [{'num': 1, 'text': text_pla}]
 
    return None
 
 
# ── Neteja i normalització de noms d'ingredients ─────────────────────────────
 
# Ingredients que no volem vincular a cap producte perquè són massa genèrics
# o no aporten valor a la llista de la compra (quantitats mínimes, "to taste"...).
# Afegeix aquí qualsevol ingredient que vulguis ignorar globalment.
INGREDIENTS_IGNORATS = {
    # Genèrics sense valor informatiu (ice sí, però water NO: pot estar a la BD)
    'ice', 'ice water',
    # Salses i condiments de marca / molt específics
    'homemade sauce',
    # Descripcions, no ingredients
    'sauce', 'seasoning', 'spices', 'mixed spices', 'seasonings',
    # Fragments de text que no són ingredients reals
    'or', 'to serve', 'to taste',
    # Text de blog colat per error
    'do you love greek salads',
    # Nota: '. bacon into pieces' i 'lots of pepper' s'han eliminat d'aquí
    # perquè ara els patrons de neteja els converteixen en 'bacon' i 'pepper'
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
    # "lots of X" → X  (ex: "lots of pepper" → "pepper")
    r'^lots\s+of\s+',
    # Números i fraccions al principi PRIMER (ex: "2 oz." → "oz.")
    r'^[\d\s/¼½¾⅓⅔⅛⅜⅝⅞]+',
    # Unitats al principi, inclou oz. amb punt (ex: "oz. bacon" → "bacon")
    r'^(teaspoon|tablespoon|cup|ounce|pound|gram|tsp|tbsp|oz\.?|lb|g|ml|liter|l)\b\.?\s*',
    # Punt o espais residuals al principi (restes de "oz." → ". bacon" → "bacon")
    r'^[.\s]+',
    # "X into pieces/strips/chunks" al final (ex: "bacon into pieces" → "bacon")
    r'\s+into\s+\w+(\s+\w+)?$',
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
 
    # Dues passades per eliminar restes encadenades
    # (ex: "2 oz. bacon into pieces" → passa 1: "oz. bacon" → passa 2: "bacon")
    for _ in range(2):
        for pattern in _SOROLL_RE:
            nom = pattern.sub(' ', nom)
        nom = re.sub(r'\s+', ' ', nom).strip()
 
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
        # Afegeix sinonims (nou camp)
        sinonims = (p.sinonims or []) if p.sinonims else []
        for sin in sinonims:
            noms.append(sin.lower())
        # Afegeix alias_api (nom_en i nom_en_query)
        if p.alias_api and isinstance(p.alias_api, dict):
            for camp in ('nom_en', 'nom_en_query'):
                val = p.alias_api.get(camp, '')
                if val:
                    noms.append(val.lower())
        cache.append((p, noms))
    return cache
 
 
def buscar_producte_per_audit(nom_original: str, cache: list):
    """
    Cerca estricta per a l'audit: NOMÉS cerca exacta i parcial contra
    sinònims i alias en anglès. NO fa fuzzy ni compara contra noms catalans.
 
    Estratègia:
      1. Neteja el nom_original (elimina quantitats, adjectius, etc.)
      2. Cerca exacta per alias_api i sinònims anglesos
      3. Cerca parcial NOMÉS si el sinònim del producte és prou llarg (>= 6 chars)
         i el nom_net el conté exactament com a paraula, no com a subcadena arbitrària.
         Això evita "pepper" (6c) fent match dins "pepper jack cheese" quan
         "pepper jack cheese" és el producte correcte.
 
    Retorna (producte, motiu) o (None, None).
    """
    nom_lower = nom_original.lower().strip()
    nom_net = netejar_nom_ingredient(nom_lower)
 
    if not nom_net or len(nom_net) < 2:
        return None, None
    if nom_net in INGREDIENTS_IGNORATS:
        return None, None
 
    # ── Cerca exacta per alias_api (nom_en / nom_en_query) ──────────────────
    for cerca in (nom_net, nom_lower):
        p = (
            Producte.objects.filter(alias_api__nom_en__iexact=cerca).first()
            or Producte.objects.filter(alias_api__nom_en_query__iexact=cerca).first()
        )
        if p:
            return p, f'alias exacte "{cerca}"'
 
    # ── Cerca exacta per sinònims (anglesos i catalans) ─────────────────────
    for producte, noms_producte in cache:
        for nom_p in noms_producte[1:]:  # [0] és el nom català, saltem-lo
            for cerca in (nom_net, nom_lower):
                if cerca == nom_p:
                    return producte, f'sinònim exacte "{cerca}"'
 
    # ── Cerca parcial per alias_api (nom_net dins alias) ────────────────────
    if len(nom_net) >= 4:
        p = (
            Producte.objects.filter(alias_api__nom_en__icontains=nom_net).first()
            or Producte.objects.filter(alias_api__nom_en_query__icontains=nom_net).first()
        )
        if p:
            return p, f'alias parcial "{nom_net}"'
 
    # ── Cerca parcial per sinònims ───────────────────────────────────────────
    # Regles per evitar falsos positius:
    #   - El sinònim del producte ha de tenir >= 6 caràcters (evita "pepper" ⊂ "pepper jack")
    #   - El sinònim ha d'estar contingut en nom_net (no a l'inrevés)
    #     Això fa que "pepper jack cheese" trobi "pepperjack cheese" però
    #     NO que "pepper" trobi "pepper jack cheese"
    import re as _re
    if len(nom_net) >= 4:
        for producte, noms_producte in cache:
            for nom_p in noms_producte[1:]:  # saltem nom català
                if len(nom_p) < 8:
                    continue  # sinònim massa curt, massa propens a falsos positius (ex: "pepper" ⊂ "pepper jack cheese")
                # El sinònim del producte ha d'estar contingut en el nom netejat
                if nom_p in nom_net:
                    return producte, f'sinònim parcial "{nom_p}" ⊂ "{nom_net}"'
 
    return None, None
 
 
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
        parser.add_argument('--audit', action='store_true',
                            help='Revisa tots els vincles existents i detecta assignacions '
                                 'sospitoses comparant nom_original amb el producte assignat. '
                                 'No modifica res.')
        parser.add_argument('--fix-audit', action='store_true',
                            help='Com --audit però corregeix automàticament els vincles '
                                 'sospitosos si troba un producte millor. '
                                 'Mou els ingredients no resolts a ingredients_no_vinculats.')
 
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
        audit = options['audit']
        fix_audit = options['fix_audit']
 
        stats = {'creades': 0, 'actualitzades': 0, 'saltades': 0, 'descartades': 0}
        ids_processats = set()
        no_trobats_global = _carregar_no_trobats()
 
        self.stdout.write('⏳ Carregant cache de productes...')
        cache_productes = _carregar_cache_productes()
        self.stdout.write(f'✓ {len(cache_productes)} productes carregats a la cache\n')
 
        if relink:
            self._relink_receptes(cache_productes, fuzzy_threshold, dry_run)
            return
 
        if audit or fix_audit:
            self._audit_vincles(cache_productes, fuzzy_threshold, fix=fix_audit)
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
                    ingredients_no_vinculats_map = {}  # nom_ing → {quantitat, unitat}
 
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
                            nom_no_trobat = netejar_nom_ingredient(nom_ing) or nom_ing
                            ingredients_no_trobats.append(nom_no_trobat)
                            # Guarda per poder fer relink sense cridar l'API
                            if nom_ing not in ingredients_no_vinculats_map:
                                ingredients_no_vinculats_map[nom_ing] = {
                                    'quantitat': quantitat_final,
                                    'unitat': unitat,
                                }
 
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
 
                    # Guarda els ingredients no vinculats per poder fer relink futur
                    ingredients_no_vinculats_json = [
                        {
                            'nom': nom_ing_raw,
                            'quantitat': ing_raw_data['quantitat'],
                            'unitat': ing_raw_data['unitat'],
                        }
                        for nom_ing_raw, ing_raw_data in ingredients_no_vinculats_map.items()
                    ]
 
                    existia = Recepta.objects.filter(pk=recepta_id).exists()
                    recepta, _ = Recepta.objects.update_or_create(
                        id_api=recepta_id,
                        defaults={
                            'nom': nom,
                            'nom_en': nom,               # original anglès
                            'descripcio': resum_net[:2000],
                            'descripcio_en': resum_net[:2000],  # original anglès
                            'imatge_url': imatge,
                            'temps_preparacio': temps,
                            'porcions': porcions,
                            'instruccions': instruccions,
                            'instruccions_en': instruccions,    # original anglès
                            'dietes': dietes,
                            'dietes_en': dietes,                # original anglès
                            'intolerancias': intolerancias,
                            'intolerancias_en': intolerancias,  # original anglès
                            'ingredients_no_vinculats': ingredients_no_vinculats_json,
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
        # Re-vincula ingredients de totes les receptes sense cridar l'API.
        # Per poder re-vincular els que mai es van trobar, llegeix el camp
        # `ingredients_no_vinculats` que es guarda des d'ara a la Recepta.
        from myapp.models import Recepta as R
        no_trobats_global = {}
        total_receptes = 0
        total_nous_vincles = 0
        total_no_trobats = 0
 
        self.stdout.write(self.style.SUCCESS("🔗 Mode relink — sense crides a l'API\n"))
 
        total_receptes_bd = R.objects.count()
 
        for i, recepta in enumerate(
            R.objects.prefetch_related('ingredientrecepta_set__producte').all(), start=1
        ):
            self.stdout.write(f'\n[{i}/{total_receptes_bd}] 🍽️  "{recepta.nom}"')
 
            ingredients_actuals = list(
                recepta.ingredientrecepta_set.select_related('producte').all()
            )
            ingredients_nous = []
            ingredients_no_trobats = []
            nous_vincles_detall = []  # ingredients nous trobats en aquest relink
 
            # ── Conserva els que ja estaven vinculats (sense re-cercar) ──────
            # No cal tornar a fer buscar_producte: ja estan vinculats correctament.
            # Re-cercar-los amb nom_original llarg ("2 large eggs at room temp")
            # causaria falsos no-trobats.
            for ing in ingredients_actuals:
                ingredients_nous.append({
                    'producte': ing.producte,
                    'quantitat': ing.quantitat,
                    'unitat': ing.unitat,
                    'nom_original': ing.nom_original,
                })
 
            # ── Intenta vincular els que NO es van trobar inicialment ─────────
            # Aquests sí que cal cercar-los perquè ara potser tenim nous productes
            # o sinonims que abans no existien.
            no_vinculats = recepta.ingredients_no_vinculats or []
            self.stdout.write(
                f'   Ing. actuals: {len(ingredients_actuals)} | '
                f'Pendent vincular: {len(no_vinculats)}'
            )
 
            for item in no_vinculats:
                nom_original = item.get('nom', '')
                if not nom_original:
                    continue
                producte_nou = buscar_producte(nom_original, cache_productes, fuzzy_threshold)
                if producte_nou:
                    ingredients_nous.append({
                        'producte': producte_nou,
                        'quantitat': item.get('quantitat', 1.0),
                        'unitat': item.get('unitat', 'unitat'),
                        'nom_original': nom_original,
                    })
                    nous_vincles_detall.append((nom_original, producte_nou.nom))
                else:
                    ingredients_no_trobats.append(nom_original)
 
            # ── Informa dels nous vincles trobats ──────────────────────────────
            if nous_vincles_detall:
                self.stdout.write(
                    self.style.SUCCESS(f'   ✅ {len(nous_vincles_detall)} nous vincles:')
                )
                for nom_ing, nom_prod in nous_vincles_detall:
                    self.stdout.write(
                        self.style.SUCCESS(f'      + "{nom_ing}" → {nom_prod}')
                    )
            if ingredients_no_trobats:
                self.stdout.write(
                    f'   ⚠️  Encara sense vincle: '
                    f'{", ".join(ingredients_no_trobats[:5])}'
                    + (' ...' if len(ingredients_no_trobats) > 5 else '')
                )
 
            if ingredients_no_trobats:
                _registrar_no_trobats(
                    no_trobats_global, recepta.nom, recepta.id_api, ingredients_no_trobats
                )
 
            ids_actuals = {ing.producte_id for ing in ingredients_actuals}
            ids_nous = {d['producte'].pk for d in ingredients_nous}
            hi_ha_canvis = ids_actuals != ids_nous
 
            if not dry_run:
                if hi_ha_canvis:
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
                    # Actualitza el camp: elimina els que ja s'han pogut vincular
                    nous_no_vinculats = [
                        item for item in no_vinculats
                        if item.get('nom', '') in ingredients_no_trobats
                    ]
                    recepta.ingredients_no_vinculats = nous_no_vinculats
                    recepta.save(update_fields=['ingredients_no_vinculats'])
                    total_nous_vincles += 1
                    self.stdout.write(
                        self.style.SUCCESS(
                            f'   💾 Guardat — total ing: {len(finals)}'
                        )
                    )
                else:
                    self.stdout.write('   ↩️  Sense canvis, no cal guardar')
            else:
                # dry_run: informa del que es faria
                if hi_ha_canvis:
                    self.stdout.write(
                        self.style.WARNING(
                            f'   [DRY] S\'actualitzaria: {len(ids_nous)} ing '
                            f'(abans {len(ids_actuals)})'
                        )
                    )
                    total_nous_vincles += 1
                else:
                    self.stdout.write('   [DRY] Sense canvis')
 
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
 
 
    def _audit_vincles(self, cache_productes, fuzzy_threshold, fix=False):
        """
        Revisa tots els IngredientRecepta existents i detecta assignacions sospitoses:
        el nom_original netejat no coincideix prou amb el producte assignat.
 
        Si fix=True, corregeix automaticament:
          - Si troba un producte millor -> reassigna
          - Si no en troba cap -> mou a ingredients_no_vinculats de la recepta
        """
        from thefuzz import fuzz
        from myapp.models import IngredientRecepta
 
        MODE = "\U0001f527 Fix-audit" if fix else "\U0001f50d Audit"
        self.stdout.write(self.style.SUCCESS(f"{MODE} — revisant vincles existents\n"))
 
        LLINDAR_ACCEPTABLE = 50
        total = 0
        sospitosos = 0
        corregits = 0
        saltats_fix = 0  # ingredients que tenia alternativa però has dit que no
        eliminats = 0
 
        tots = (
            IngredientRecepta.objects
            .select_related("recepta", "producte")
            .all()
        )
        n_total = tots.count()
 
        for ing in tots.iterator():
            total += 1
            nom_original = ing.nom_original or ""
            nom_net = netejar_nom_ingredient(nom_original) or nom_original.lower().strip()
            nom_producte = ing.producte.nom.lower()
 
            score_actual = max(
                fuzz.token_set_ratio(nom_net, nom_producte),
                fuzz.token_set_ratio(nom_net, nom_producte.split()[0]),
            )
            sinonims = [s.lower() for s in (ing.producte.sinonims or [])]
            for sin in sinonims:
                score_actual = max(score_actual, fuzz.token_set_ratio(nom_net, sin))
 
            if score_actual >= LLINDAR_ACCEPTABLE:
                continue
 
            sospitosos += 1
            # Usa cerca estricta (només sinònims/alias anglesos, sense fuzzy català)
            # per evitar falsos positius com "pepper" → "Pepperoni"
            producte_millor, motiu_millor = buscar_producte_per_audit(nom_original, cache_productes)
 
            if producte_millor and producte_millor.pk != ing.producte_id:
                self.stdout.write(
                    self.style.WARNING(
                        f"  \u26a0\ufe0f  [{ing.recepta.nom[:40]}]\n"
                        f"      nom_original: \"{nom_original}\"\n"
                        f"      assignat:     {ing.producte.nom!r} (score={score_actual})\n"
                        f"      millor:       {producte_millor.nom!r} ({motiu_millor})"
                    )
                )
                if fix:
                    resposta = input(
                        f"      Confirmes canviar a {producte_millor.nom!r}? (s/n): "
                    ).strip().lower()
                    if resposta == 's':
                        ja_existeix = IngredientRecepta.objects.filter(
                            recepta=ing.recepta, producte=producte_millor
                        ).exists()
                        if ja_existeix:
                            ing.delete()
                            self.stdout.write(
                                self.style.SUCCESS(
                                    f"      ✓ Eliminat (ja hi havia {producte_millor.nom})"
                                )
                            )
                        else:
                            ing.producte = producte_millor
                            ing.save(update_fields=["producte"])
                            self.stdout.write(
                                self.style.SUCCESS(f"      ✓ Corregit a {producte_millor.nom!r}")
                            )
                        corregits += 1
                    else:
                        self.stdout.write(f"      ⊘ Saltat")
                        saltats_fix += 1
 
            elif not producte_millor:
                self.stdout.write(
                    self.style.WARNING(
                        f"  \u26a0\ufe0f  [{ing.recepta.nom[:40]}]\n"
                        f"      nom_original: \"{nom_original}\"\n"
                        f"      assignat:     {ing.producte.nom!r} (score={score_actual})\n"
                        f"      millor:       (cap producte trobat)"
                    )
                )
                if fix:
                    recepta = ing.recepta
                    no_vinculats = recepta.ingredients_no_vinculats or []
                    noms_ja = {i.get("nom", "") for i in no_vinculats}
                    if nom_original not in noms_ja:
                        no_vinculats.append({
                            "nom": nom_original,
                            "quantitat": ing.quantitat,
                            "unitat": ing.unitat,
                        })
                        recepta.ingredients_no_vinculats = no_vinculats
                        recepta.save(update_fields=["ingredients_no_vinculats"])
                    ing.delete()
                    self.stdout.write(
                        self.style.SUCCESS("      \u2192 Mogut a ingredients_no_vinculats")
                    )
                    eliminats += 1
            else:
                self.stdout.write(
                    self.style.WARNING(
                        f"  \u26a0\ufe0f  [{ing.recepta.nom[:40]}] \"{nom_original}\" \u2192 "
                        f"{ing.producte.nom!r} (score={score_actual}, sense alternativa)"
                    )
                )
 
        self.stdout.write(self.style.SUCCESS(f"\n\u2705 Audit fet!"))
        self.stdout.write(
            f"\n\U0001f4ca Resum:\n"
            f"  \U0001f517 {total}/{n_total} vincles revisats\n"
            f"  \u26a0\ufe0f  {sospitosos} sospitosos (score < {LLINDAR_ACCEPTABLE})\n"
        )
        if fix:
            self.stdout.write(
                f"  \u2705 {corregits} corregits\n"
                f"  \U0001f5d1\ufe0f  {eliminats} moguts a no_vinculats\n"
            )
        else:
            self.stdout.write(
                "  \u2192 Executa --fix-audit per corregir-los automaticament\n"
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