import time
import requests
from django.core.management.base import BaseCommand
from myapp.models import Categoria, Producte

EMOJI_MAP = {
    # Verdures i hortalisses
    "tomàquet": "🍅", "tomato": "🍅",
    "ceba": "🧅", "onion": "🧅",
    "all": "🧄", "garlic": "🧄",
    "pastanaga": "🥕", "carrot": "🥕",
    "patata": "🥔", "potato": "🥔",
    "pebrot": "🫑", "pepper": "🫑",
    "carbassó": "🥒", "zucchini": "🥒",
    "albergínia": "🍆", "eggplant": "🍆",
    "espinacs": "🥬", "spinach": "🥬",
    "enciam": "🥬", "lettuce": "🥬",
    "bròquil": "🥦", "broccoli": "🥦",
    "coliflor": "🥦", "cauliflower": "🥦",
    "api": "🌿", "celery": "🌿",
    "cogombre": "🥒", "cucumber": "🥒",
    "bolet": "🍄", "mushroom": "🍄",
    "porro": "🧅", "leek": "🧅",
    "espàrrec": "🌿", "asparagus": "🌿",
    "carxofa": "🌿", "artichoke": "🌿",
    "pèsols": "🫛", "peas": "🫛",
    "blat de moro": "🌽", "corn": "🌽",
    # Fruites
    "poma": "🍎", "apple": "🍎",
    "plàtan": "🍌", "banana": "🍌",
    "taronja": "🍊", "orange": "🍊",
    "llimona": "🍋", "lemon": "🍋",
    "maduixa": "🍓", "strawberry": "🍓",
    "raïm": "🍇", "grape": "🍇",
    "préssec": "🍑", "peach": "🍑",
    "pera": "🍐", "pear": "🍐",
    "síndria": "🍉", "watermelon": "🍉",
    "meló": "🍈", "melon": "🍈",
    "pinya": "🍍", "pineapple": "🍍",
    "mango": "🥭", "kiwi": "🥝",
    "cirera": "🍒", "cherry": "🍒",
    "pruna": "🍑", "plum": "🍑",
    "albercoc": "🍑", "apricot": "🍑",
    "gerd": "🫐", "raspberry": "🫐",
    "nabiu": "🫐", "blueberry": "🫐",
    "figa": "🍈", "fig": "🍈",
    "magrana": "🍎", "pomegranate": "🍎",
    # Carns
    "pit de pollastre": "🍗", "chicken breast": "🍗",
    "cuixa de pollastre": "🍗", "chicken thigh": "🍗",
    "carn picada de vedella": "🥩", "ground beef": "🥩",
    "filet de vedella": "🥩", "beef steak": "🥩",
    "llom de porc": "🥩", "pork loin": "🥩",
    "xai": "🥩", "lamb": "🥩",
    "gall dindi": "🦃", "turkey": "🦃",
    "bacon": "🥓", "pernil": "🥩", "ham": "🥩",
    "xoriço": "🌭", "chorizo": "🌭",
    "salsitxa": "🌭", "sausage": "🌭",
    "vedella": "🥩", "veal": "🥩",
    "ànec": "🍗", "duck": "🍗",
    "conill": "🥩", "rabbit": "🥩",
    "aletes de pollastre": "🍗", "chicken wings": "🍗",
    # Peix i marisc
    "salmó": "🐟", "salmon": "🐟",
    "tonyina": "🐟", "tuna": "🐟",
    "bacallà": "🐟", "cod": "🐟",
    "gamba": "🦐", "shrimp": "🦐",
    "sardina": "🐟", "sardine": "🐟",
    "llobarro": "🐟", "sea bass": "🐟",
    "truita": "🐟", "trout": "🐟",
    "pop": "🐙", "octopus": "🐙",
    "calamar": "🦑", "squid": "🦑",
    "cloïssa": "🦪", "clam": "🦪",
    "musclo": "🦪", "mussel": "🦪",
    "anxova": "🐟", "anchovy": "🐟",
    "lluç": "🐟", "hake": "🐟",
    "cranc": "🦀", "crab": "🦀",
    # Làctics i ous
    "ou": "🥚", "egg": "🥚",
    "llet": "🥛", "milk": "🥛",
    "mantega": "🧈", "butter": "🧈",
    "formatge": "🧀", "cheese": "🧀",
    "iogurt": "🍶", "yogurt": "🍶",
    "nata": "🥛", "cream": "🥛",
    "mozzarella": "🧀", "parmesà": "🧀", "parmesan": "🧀",
    "cheddar": "🧀", "formatge cremós": "🧀", "cream cheese": "🧀",
    # Cereals i llegums
    "arròs": "🍚", "rice": "🍚",
    "pasta": "🍝",
    "farina": "🌾", "flour": "🌾",
    "pa": "🍞", "bread": "🍞",
    "civada": "🌾", "oats": "🌾",
    "llenties": "🫘", "lentils": "🫘",
    "cigrons": "🫘", "chickpeas": "🫘",
    "mongetes negres": "🫘", "black beans": "🫘",
    "mongetes vermelles": "🫘", "kidney beans": "🫘",
    "quinoa": "🌾", "cuscús": "🌾", "couscous": "🌾",
    "farina de blat de moro": "🌽", "corn flour": "🌽",
    "pa ratllat": "🍞", "breadcrumbs": "🍞",
    # Olis i condiments
    "oli d'oliva": "🫙", "olive oil": "🫙",
    "oli de gira-sol": "🫙", "sunflower oil": "🫙",
    "vinagre": "🫙", "vinegar": "🫙",
    "salsa de soja": "🫙", "soy sauce": "🫙",
    "mostassa": "🫙", "mustard": "🫙",
    "ketchup": "🍅",
    "maionesa": "🫙", "mayonnaise": "🫙",
    "mel": "🍯", "honey": "🍯",
    "sucre": "🧂", "sugar": "🧂",
    "sal": "🧂", "salt": "🧂",
    "pebre negre": "🌶️", "black pepper": "🌶️",
    "pebre vermell": "🌶️", "paprika": "🌶️",
    "comí": "🌿", "cumin": "🌿",
    "orenga": "🌿", "oregano": "🌿",
    "farigola": "🌿", "thyme": "🌿",
    "romaní": "🌿", "rosemary": "🌿",
    "llorer": "🌿", "bay leaf": "🌿",
    "canyella": "🌿", "cinnamon": "🌿",
    "cúrcuma": "🌿", "turmeric": "🌿",
    "bitxo": "🌶️", "chili flakes": "🌶️",
    # Fruits secs
    "ametlla": "🌰", "almonds": "🌰",
    "nous": "🌰", "walnuts": "🌰",
    "avellana": "🌰", "hazelnuts": "🌰",
    "cacauet": "🥜", "peanuts": "🥜",
    "anacard": "🌰", "cashews": "🌰",
    "pinyó": "🌰", "pine nuts": "🌰",
    "llavors de sèsam": "🌰", "sesame seeds": "🌰",
    "pansa": "🍇", "raisins": "🍇",
    # Begudes
    "aigua": "💧", "water": "💧",
    "suc de taronja": "🍊", "orange juice": "🍊",
    "vi": "🍷", "wine": "🍷",
    "cervesa": "🍺", "beer": "🍺",
    "cafè": "☕", "coffee": "☕",
    "te": "🍵", "tea": "🍵",
    "brou de verdures": "🫙", "vegetable broth": "🫙",
    "brou de pollastre": "🫙", "chicken broth": "🫙",
    "llet de coco": "🥥", "coconut milk": "🥥",
    # Conserves
    "tomàquet en conserva": "🥫", "canned tomato": "🥫",
    "tonyina en conserva": "🥫", "canned tuna": "🥫",
    "cigrons en conserva": "🥫", "canned chickpeas": "🥫",
    "concentrat de tomàquet": "🥫", "tomato paste": "🥫",
    "crema de coco": "🥥", "coconut cream": "🥥",
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

CATEGORIES = [
    ("Verdures i hortalisses", [
        "tomato", "onion", "garlic", "carrot", "potato", "pepper", "zucchini",
        "eggplant", "spinach", "lettuce", "broccoli", "cauliflower", "celery",
        "cucumber", "mushroom", "leek", "asparagus", "artichoke", "peas", "corn"
    ]),
    ("Fruites", [
        "apple", "banana", "orange", "lemon", "strawberry", "grape", "peach",
        "pear", "watermelon", "melon", "pineapple", "mango", "kiwi", "cherry",
        "plum", "apricot", "raspberry", "blueberry", "fig", "pomegranate"
    ]),
    ("Carns", [
        "chicken breast", "chicken thigh", "ground beef", "beef steak", "pork loin",
        "lamb", "turkey", "bacon", "ham", "chorizo", "sausage", "veal", "duck",
        "rabbit", "chicken wings"
    ]),
    ("Peix i marisc", [
        "salmon", "tuna", "cod", "shrimp", "sardine", "sea bass", "trout",
        "octopus", "squid", "clam", "mussel", "anchovy", "hake", "sole", "crab"
    ]),
    ("Làctics i ous", [
        "egg", "milk", "butter", "cheese", "yogurt", "cream", "mozzarella",
        "parmesan", "cheddar", "cream cheese", "sour cream", "whipped cream"
    ]),
    ("Cereals i llegums", [
        "rice", "pasta", "flour", "bread", "oats", "lentils", "chickpeas",
        "black beans", "kidney beans", "quinoa", "couscous", "corn flour",
        "breadcrumbs", "semolina", "whole wheat flour"
    ]),
    ("Olis i condiments", [
        "olive oil", "sunflower oil", "vinegar", "soy sauce", "mustard",
        "ketchup", "mayonnaise", "honey", "sugar", "salt", "black pepper",
        "paprika", "cumin", "oregano", "thyme", "rosemary", "bay leaf",
        "cinnamon", "turmeric", "chili flakes"
    ]),
    ("Fruits secs i llavors", [
        "almonds", "walnuts", "hazelnuts", "peanuts", "cashews", "pine nuts",
        "sesame seeds", "sunflower seeds", "pumpkin seeds", "flaxseed", "raisins"
    ]),
    ("Begudes", [
        "water", "milk", "orange juice", "wine", "beer", "coffee", "tea",
        "vegetable broth", "chicken broth", "coconut milk"
    ]),
    ("Conserves i envasos", [
        "canned tomato", "canned tuna", "canned chickpeas", "canned corn",
        "tomato paste", "coconut cream", "canned beans", "canned sardines"
    ]),
]


def traduir_al_catala(text_en):
    try:
        from deep_translator import GoogleTranslator
        resultat = GoogleTranslator(source='en', target='ca').translate(text_en)
        return resultat.capitalize() if resultat else text_en.capitalize()
    except Exception:
        return text_en.capitalize()


def get_emoji(nom_ca, nom_en, categoria_nom):
    nom_ca_lower = nom_ca.lower()
    nom_en_lower = nom_en.lower()
    return (
        EMOJI_MAP.get(nom_ca_lower)
        or EMOJI_MAP.get(nom_en_lower)
        or CATEGORY_EMOJI.get(categoria_nom, "🛒")
    )


class Command(BaseCommand):
    help = 'Pobla la BD amb productes de Spoonacular traduïts al català amb emojis'

    def add_arguments(self, parser):
        parser.add_argument('--api-key', type=str, help='Spoonacular API key')
        parser.add_argument('--dry-run', action='store_true', help='Sense escriure a la BD')

    def handle(self, *args, **options):
        import os
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
        total_creats = 0
        total_existents = 0

        for categoria_nom, queries in CATEGORIES:
            self.stdout.write(f'\n📂 {categoria_nom}')

            if not dry_run:
                categoria, _ = Categoria.objects.get_or_create(nom=categoria_nom)

            vistos = set()

            for query in queries:
                try:
                    resp = requests.get(
                        'https://api.spoonacular.com/food/ingredients/search',
                        params={
                            'apiKey': api_key,
                            'query': query,
                            'number': 5,
                            'language': 'en',
                            'metaInformation': True,
                        },
                        timeout=10,
                    )
                    resp.raise_for_status()

                    for item in resp.json().get('results', []):
                        nom_en = item['name']
                        spoonacular_id = item['id']

                        if nom_en in vistos:
                            continue
                        vistos.add(nom_en)

                        nom_ca = traduir_al_catala(nom_en)
                        emoji = get_emoji(nom_ca, nom_en, categoria_nom)

                        if dry_run:
                            self.stdout.write(f'  [DRY] {emoji} {nom_ca} (en: {nom_en}, id: {spoonacular_id})')
                            total_creats += 1
                        else:
                            _, creat = Producte.objects.get_or_create(
                                nom=nom_ca,
                                defaults={
                                    'categoria': categoria,
                                    'emoji': emoji,
                                    'alias_api': {'spoonacular_id': spoonacular_id, 'nom_en': nom_en},
                                }
                            )
                            if creat:
                                total_creats += 1
                                self.stdout.write(f'  ✓ {emoji} {nom_ca}')
                            else:
                                total_existents += 1

                    time.sleep(0.5)

                except requests.exceptions.HTTPError as e:
                    if e.response.status_code == 402:
                        self.stderr.write(self.style.ERROR(
                            'Límit diari de la API assolit. Torna-ho a intentar demà.'
                        ))
                        self.stdout.write(f'\nResum parcial: {total_creats} creats, {total_existents} ja existien.')
                        return
                    self.stderr.write(self.style.WARNING(f'  Error HTTP per "{query}": {e}'))
                except requests.exceptions.RequestException as e:
                    self.stderr.write(self.style.WARNING(f'  Error de xarxa per "{query}": {e}'))

        prefix = '[DRY RUN] ' if dry_run else ''
        self.stdout.write(self.style.SUCCESS(
            f'\n{prefix}Fet! {total_creats} productes nous, {total_existents} ja existien.'
        ))