import time
import requests
import os
from django.core.management.base import BaseCommand
from myapp.models import Categoria, Producte

SPOONACULAR_IMG_BASE = 'https://img.spoonacular.com/ingredients_100x100/'

# ──────────────────────────────────────────────────────────────────────────────
# Ingredients nous detectats al JSON ingredients_no_trobats.json (v5)
#
# DESCARTATS (no són ingredients reals o ja cobertes per versions anteriors):
#   "to", "or", "to serve", "sized onions very"          → fragments de text
#   "do you love greek salads...", "bet you'll love it"   → text narratiu de recepta
#   "you can use regular basil"                           → instrucció de recepta
#   "es round spring roll wrappers"                       → text truncat/malformat
#   "chili paste depending on your taste pref"            → text truncat/malformat
#   "additional scallion tops", "green onions white part" → variants de scallions (ja a v4)
#   "needles removed from springs of rosemary"            → rosemary ja existeix
#   "rind of two lemons"                                  → lemon ja existeix
#   "freshly peas"                                        → peas ja existeix
#   "spring salad", "veggies"                             → genèrics no vinculables
#   "meatballs", "sauce", "easy black bean soup"          → plats preparats, no ingredients
#   "seasoning", "seasonings"                             → ja a v4 com a genèric
#   "spicy sausages"                                      → sausage ja existeix
#   "pea tendrils", "pea greens"                          → ja a v4
#   "fried tofu each piece"                               → tofu ja a v4
#   ".2 lb beef mince"                                    → text mal parsejat
#   "pimenton de la vera"                                 → smoked paprika ja a v4
# ──────────────────────────────────────────────────────────────────────────────

EMOJI_MAP = {
    # Edulcorants alternatius
    "nèctar d'atzavara": "🍯", "agave nectar": "🍯",
    "stevia": "🌿",

    # Làctics
    "half-and-half": "🥛", "meitat i meitat": "🥛",

    # Begudes i licors
    "brandy": "🥃",

    # Condiments i salses
    "salsa de xili": "🌶️", "chili sauce": "🌶️",
    "salsa marinara": "🥫", "marinara sauce": "🥫",
    "nuoc cham": "🫙",

    # Conserves i verdures en conserva
    "peperoncini": "🫙",
    "tomàquets pruna": "🥫", "plum tomatoes": "🥫",

    # Aperitius i snacks
    "nachos de tortilla": "🫔", "tortilla chips": "🫔",

    # Altres
    "cubets de gel": "🧊", "ice cubes": "🧊",
    "fulles de paper d'arròs": "🫔", "spring roll wrappers": "🫔",
    "pomes mcintosh": "🍎", "mcintosh apples": "🍎",
    "bitxos llargs": "🌶️", "long chillies": "🌶️",
}

CATEGORY_EMOJI = {
    "Verdures i hortalisses": "🥦",
    "Fruites": "🍎",
    "Carns": "🥩",
    "Peix i marisc": "🐟",
    "Làctics i ous": "🥛",
    "Cereals i llegums": "🌾",
    "Olis i condiments": "🫙",
    "Fruits secs i llavors": "🌰",
    "Begudes": "🥤",
    "Conserves i envasos": "🥫",
    "Pa i rebosteria": "🍞",
    "Aperitius i snacks": "🫔",
}

# Ingredients nous, agrupats per categoria i ordenats de més a menys freqüència al JSON.
CATEGORIES = [
    ("Olis i condiments", [
        "agave nectar",       # edulcorant natural vegà (recepta: Chocolatey Overnight Oats)
        "stevia",             # edulcorant sense calories (recepta: Chicken Spring Rolls)
        "chili sauce",        # salsa de xili (recepta: Chicken Spring Rolls)
        "nuoc cham",          # salsa vietnamita (recepta: Easy To Make Spring Rolls)
        "long chillies",      # bitxos llargs frescos (recepta: Loaded Paleo Nachos)
    ]),
    ("Làctics i ous", [
        "half-and-half",      # barreja llet i nata (recepta: Overnight Oatmeal)
    ]),
    ("Begudes", [
        "brandy",             # licor de raïm (recepta: Apple Pie Honey Wheat Scones)
    ]),
    ("Conserves i envasos", [
        "marinara sauce",     # salsa marinara en pot (recepta: Baked Italian Nachos)
        "peperoncini",        # pebrets italians en vinagre (recepta: Spanish Meatballs)
        "plum tomatoes",      # tomàquets pruna en conserva (recepta: Simple Roast Chicken)
    ]),
    ("Aperitius i snacks", [
        "tortilla chips",     # nachos de blat de moro (recepta: Nachos Grande)
        "spring roll wrappers",  # fulles de paper d'arròs (recepta: Easy To Make Spring Rolls)
    ]),
    ("Fruites", [
        "mcintosh apples",    # varietat de poma (recepta: Apple Pie Bars)
    ]),
]

# Noms forçats per evitar traduccions incorrectes de termes específics
NOM_FORCAT = {
    "agave nectar": "Nèctar d'atzavara",
    "stevia": "Estèvia",
    "half-and-half": "Half-and-half (llet i nata)",
    "brandy": "Brandy",
    "chili sauce": "Salsa de xili",
    "nuoc cham": "Nuoc cham",
    "long chillies": "Bitxos llargs",
    "marinara sauce": "Salsa marinara",
    "peperoncini": "Peperoncini",
    "plum tomatoes": "Tomàquets pruna",
    "tortilla chips": "Nachos de tortilla",
    "spring roll wrappers": "Fulles per spring rolls",
    "mcintosh apples": "Pomes McIntosh",
}


def traduir_al_catala(text_en):
    try:
        from deep_translator import GoogleTranslator
        resultat = GoogleTranslator(source='en', target='ca').translate(text_en)
        return resultat.capitalize() if resultat else text_en.capitalize()
    except Exception:
        return text_en.capitalize()


def get_emoji(nom_ca, nom_en, categoria_nom):
    return (
        EMOJI_MAP.get(nom_ca.lower())
        or EMOJI_MAP.get(nom_en.lower())
        or CATEGORY_EMOJI.get(categoria_nom, "🛒")
    )


def build_imatge_url(image_filename):
    if image_filename:
        return f'{SPOONACULAR_IMG_BASE}{image_filename}'
    return None


class Command(BaseCommand):
    help = (
        'Afegeix els productes nous detectats al JSON ingredients_no_trobats.json (v5). '
        'Cobreix els ingredients vàlids que no estaven a les versions anteriors.'
    )

    def add_arguments(self, parser):
        parser.add_argument('--api-key', type=str)
        parser.add_argument('--dry-run', action='store_true')
        parser.add_argument(
            '--force',
            action='store_true',
            help='Reprocessa les queries encara que el producte ja existeixi',
        )

    def handle(self, *args, **options):
        api_key = options.get('api_key') or os.environ.get('SPOONACULAR_API_KEY')
        if not api_key:
            self.stderr.write(self.style.ERROR(
                'Cal una API key. Usa --api-key o defineix SPOONACULAR_API_KEY al .env'
            ))
            return

        try:
            from deep_translator import GoogleTranslator  # noqa: F401
        except ImportError:
            self.stderr.write(self.style.ERROR(
                'Instal·la deep-translator: pip install deep-translator'
            ))
            return

        dry_run = options['dry_run']
        force = options['force']
        total_creats = 0
        total_saltats = 0
        total_existents = 0

        queries_processades = set()

        for categoria_nom, queries in CATEGORIES:
            self.stdout.write(f'\n📂 {categoria_nom}')

            if not dry_run:
                categoria, _ = Categoria.objects.get_or_create(
                    nom=categoria_nom,
                    defaults={'emoji': CATEGORY_EMOJI.get(categoria_nom, '🛒')}
                )

            vistos = set()

            for query in queries:
                if query in queries_processades:
                    continue
                queries_processades.add(query)

                # Comprova si ja existeix per nom_en — salta sense cridar l'API
                if not force and Producte.objects.filter(
                    alias_api__nom_en__iexact=query
                ).exists():
                    self.stdout.write(f'  ⏭️  "{query}" (ja existeix, saltant...)')
                    total_saltats += 1
                    continue

                # Per productes amb nom forçat busquem només 1 resultat
                nombre_resultats = 1 if query in NOM_FORCAT else 3

                try:
                    resp = requests.get(
                        'https://api.spoonacular.com/food/ingredients/search',
                        params={
                            'apiKey': api_key,
                            'query': query,
                            'number': nombre_resultats,
                            'language': 'en',
                            'metaInformation': True,
                        },
                        timeout=10,
                    )
                    resp.raise_for_status()

                    resultats = resp.json().get('results', [])
                    if not resultats:
                        self.stdout.write(
                            f'  ⚠️  "{query}" (sense resultats a l\'API, es crearà sense spoonacular_id)'
                        )
                        nom_ca = NOM_FORCAT.get(query, query.capitalize())
                        emoji = get_emoji(nom_ca, query, categoria_nom)
                        if dry_run:
                            self.stdout.write(
                                f'  [DRY] {emoji} {nom_ca} (← "{query}") | (sense imatge)'
                            )
                            total_creats += 1
                        else:
                            _, creat = Producte.objects.get_or_create(
                                nom=nom_ca,
                                defaults={
                                    'categoria': categoria,
                                    'emoji': emoji,
                                    'imatge_url': None,
                                    'alias_api': {
                                        'spoonacular_id': None,
                                        'nom_en': query,
                                        'nom_en_query': query,
                                        'image_filename': None,
                                    },
                                }
                            )
                            if creat:
                                total_creats += 1
                                self.stdout.write(
                                    f'  ✓ {emoji} {nom_ca} (← "{query}") (sense imatge)'
                                )
                            else:
                                total_existents += 1
                                self.stdout.write(f'  = {nom_ca} (ja existia)')
                        continue

                    for item in resultats:
                        nom_en = item['name']
                        spoonacular_id = item['id']
                        image_filename = item.get('image')
                        imatge_url = build_imatge_url(image_filename)

                        if nom_en in vistos:
                            continue
                        vistos.add(nom_en)

                        nom_ca = NOM_FORCAT.get(query) or traduir_al_catala(nom_en)
                        emoji = get_emoji(nom_ca, nom_en, categoria_nom)

                        if dry_run:
                            img_info = f' | 🖼️  {imatge_url}' if imatge_url else ' | (sense imatge)'
                            self.stdout.write(
                                f'  [DRY] {emoji} {nom_ca} (← "{nom_en}"){img_info}'
                            )
                            total_creats += 1
                        else:
                            _, creat = Producte.objects.get_or_create(
                                nom=nom_ca,
                                defaults={
                                    'categoria': categoria,
                                    'emoji': emoji,
                                    'imatge_url': imatge_url,
                                    'alias_api': {
                                        'spoonacular_id': spoonacular_id,
                                        'nom_en': nom_en,
                                        'nom_en_query': query,
                                        'image_filename': image_filename,
                                    },
                                }
                            )
                            if creat:
                                total_creats += 1
                                img_info = '🖼️' if imatge_url else '(sense imatge)'
                                self.stdout.write(
                                    f'  ✓ {emoji} {nom_ca} (← "{nom_en}") {img_info}'
                                )
                            else:
                                total_existents += 1
                                self.stdout.write(f'  = {nom_ca} (ja existia)')

                    time.sleep(0.5)

                except requests.exceptions.HTTPError as e:
                    if e.response.status_code == 402:
                        self.stderr.write(self.style.ERROR(
                            '\n💳 Límit diari de la API assolit.'
                            '\nTorna a executar l\'script demà — saltarà els que ja estan carregats.'
                        ))
                        self._resum(total_creats, total_saltats, total_existents)
                        return
                    self.stderr.write(
                        self.style.WARNING(f'  ❌ Error HTTP per "{query}": {e}')
                    )
                except requests.exceptions.RequestException as e:
                    self.stderr.write(
                        self.style.WARNING(f'  ❌ Error de xarxa per "{query}": {e}')
                    )

        prefix = '[DRY RUN] ' if dry_run else ''
        self.stdout.write(self.style.SUCCESS(f'\n{prefix}✅ Fet!'))
        self._resum(total_creats, total_saltats, total_existents)

    def _resum(self, creats, saltats, existents):
        self.stdout.write(
            f'\n📊 Resum:\n'
            f'  ✓ {creats} productes nous creats\n'
            f'  ⏭️  {saltats} productes ja existents (saltats sense cridar l\'API)\n'
            f'  = {existents} productes duplicats ignorats'
        )