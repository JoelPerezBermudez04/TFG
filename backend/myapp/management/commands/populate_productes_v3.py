import time
import requests
import os
from django.core.management.base import BaseCommand
from myapp.models import Categoria, Producte

SPOONACULAR_IMG_BASE = 'https://img.spoonacular.com/ingredients_100x100/'

EMOJI_MAP = {
    # Condiments i espècies
    "sal": "🧂", "salt": "🧂",
    "pebre blanc": "🌶️", "white pepper": "🌶️",
    "pebre negre": "🌶️", "black pepper": "🌶️",
    "pebre": "🌶️", "pepper": "🌶️",
    "farina": "🌾", "flour": "🌾",
    "farina blanca": "🌾", "white flour": "🌾",
    "farina integral": "🌾", "whole wheat flour": "🌾",
    "salsa d'ostres": "🫙", "oyster sauce": "🫙",
    "xarop d'auró": "🍯", "maple syrup": "🍯",
    "oli de coco": "🫙", "coconut oil": "🫙",
    "oli de llavors de raïm": "🫙", "grapeseed oil": "🫙",
    "oli de sèsam": "🫙", "sesame oil": "🫙",
    "oli de sèsam torrat": "🫙", "toasted sesame oil": "🫙",
    "passata": "🥫", "passata di pomodoro": "🥫",
    "salsa": "🫙",
    # Herbes fresques
    "sàlvia": "🌿", "sage": "🌿",
    "anet": "🌿", "dill": "🌿",
    # Làctics
    "feta": "🧀", "feta cheese": "🧀",
    "ricotta": "🧀",
    "nata agra": "🥛", "sour cream": "🥛",
    # Fruites i verdures
    "llima": "🍋", "lime": "🍋",
    "tomatillo": "🍅",
    "pebrot verd": "🫑", "green pepper": "🫑",
    "ceba vermella": "🧅", "red onion": "🧅",
    "alvocat": "🥑", "avocado": "🥑",
    "mora": "🫐", "blackberry": "🫐", "blackberries": "🫐",
    # Fruits secs i llavors
    "nous de pecan": "🌰", "pecan": "🌰", "pecans": "🌰",
    "llavors de xia": "🌱", "chia seeds": "🌱",
    "llavors de lli": "🌱", "flaxseed": "🌱", "flax seed": "🌱",
    "nabiu sec": "🍇", "dried cranberry": "🍇", "dried cranberries": "🍇",
    "panses de nabiu": "🍇", "cranberries": "🍇",
    # Cereals
    "sèmola": "🌾", "semolina": "🌾",
    "midó de blat de moro": "🌾", "cornstarch": "🌾",
    # Conserves
    "tomàquet pebrot": "🥫", "peperoncini": "🥫",
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
}

# Productes detectats al JSON d'ingredients_no_trobats que realment falten a la BD.
# Agrupats per categoria i ordenats per freqüència d'aparició.
CATEGORIES = [
    ("Olis i condiments", [
        # Molt freqüents al JSON
        "salt",           # apareix ~30 vegades com "salt to taste", "1 tsp salt", etc.
        "black pepper",   # apareix ~10 vegades com "pepper to taste", "1 tsp pepper"
        "white pepper",
        "flour",          # apareix ~8 vegades: "1 cup flour", "2 cups flour", etc.
        # Condiments específics que falten
        "oyster sauce",
        "maple syrup",
        "grapeseed oil",
        "coconut oil",
        "toasted sesame oil",
        "passata",        # tomàquet triturat/passat (diferent de tomato paste)
        "salsa",          # salsa mexicana/picant
        "italian seasoning",
        "greek seasoning",
        "white flour",
    ]),
    ("Verdures i hortalisses", [
        "tomatillo",
        "green pepper",   # pebrot verd (diferent de bell pepper/pebrot genèric)
        "red onion",
        "pea greens",     # brots de pèsol
        "brussels sprouts",
    ]),
    ("Fruites", [
        "lime",
        "blackberries",
        "dried cranberries",
    ]),
    ("Làctics i ous", [
        "feta cheese",
        "sour cream",
    ]),
    ("Fruits secs i llavors", [
        "pecans",
        "chia seeds",
        "flaxseed",
        "almond slivers",  # ametlles laminades
    ]),
    ("Conserves i envasos", [
        "passata",         # per si no es troba a condiments
        "peperoncini",
        "plum tomatoes",   # tomàquets en conserva sencers
    ]),
    ("Olis i condiments", [
        "fresh sage",
        "fresh dill",
    ]),
]

# Noms genèrics que volem guardar amb un nom net a la BD.
# Quan l'API retorna molts resultats per "salt", agafem el primer i el guardem com "Sal".
NOM_FORCAT = {
    "salt": "Sal",
    "black pepper": "Pebre negre",
    "white pepper": "Pebre blanc",
    "pepper": "Pebre",
    "flour": "Farina",
    "white flour": "Farina blanca",
    "oil": "Oli",
    "water": "Aigua",
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
    help = 'Afegeix els productes detectats com a "no trobats" al JSON d\'ingredients'

    def add_arguments(self, parser):
        parser.add_argument('--api-key', type=str)
        parser.add_argument('--dry-run', action='store_true')
        parser.add_argument('--force', action='store_true',
                            help='Reprocessa les queries encara que el producte ja existeixi')

    def handle(self, *args, **options):
        api_key = options.get('api_key') or os.environ.get('SPOONACULAR_API_KEY')
        if not api_key:
            self.stderr.write(self.style.ERROR(
                'Cal una API key. Usa --api-key o defineix SPOONACULAR_API_KEY al .env'
            ))
            return

        try:
            from deep_translator import GoogleTranslator
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

        # Deduplicar queries entre categories per no cridar l'API dues vegades
        queries_processades = set()

        for categoria_nom, queries in CATEGORIES:
            self.stdout.write(f'\n📂 {categoria_nom}')

            if not dry_run:
                categoria, _ = Categoria.objects.get_or_create(
                    nom=categoria_nom,
                    defaults={'emoji': CATEGORY_EMOJI.get(categoria_nom, "🛒")}
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

                # Per productes genèrics com "salt", agafem només el primer resultat
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
                        self.stdout.write(f'  ⚠️  "{query}" (sense resultats a l\'API)')
                        continue

                    # Per productes genèrics, forcem el nom català
                    for item in resultats:
                        nom_en = item['name']
                        spoonacular_id = item['id']
                        image_filename = item.get('image')
                        imatge_url = build_imatge_url(image_filename)

                        if nom_en in vistos:
                            continue
                        vistos.add(nom_en)

                        # Si tenim un nom forçat per aquest query, l'usem directament
                        nom_ca = NOM_FORCAT.get(query) or traduir_al_catala(nom_en)
                        emoji = get_emoji(nom_ca, nom_en, categoria_nom)

                        if dry_run:
                            img_info = f' | 🖼️  {imatge_url}' if imatge_url else ' | (sense imatge)'
                            self.stdout.write(f'  [DRY] {emoji} {nom_ca} (← "{nom_en}"){img_info}')
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
                                        'nom_en_query': query,  # query original per fer matching
                                        'image_filename': image_filename,
                                    },
                                }
                            )
                            if creat:
                                total_creats += 1
                                img_info = '🖼️' if imatge_url else '(sense imatge)'
                                self.stdout.write(f'  ✓ {emoji} {nom_ca} (← "{nom_en}") {img_info}')
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
                    self.stderr.write(self.style.WARNING(f'  ❌ Error HTTP per "{query}": {e}'))
                except requests.exceptions.RequestException as e:
                    self.stderr.write(self.style.WARNING(f'  ❌ Error de xarxa per "{query}": {e}'))

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