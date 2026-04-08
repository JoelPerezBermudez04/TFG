from django.core.management.base import BaseCommand
from myapp.models import Producte


EMOJI_MAP = {
    # Verdures
    "blat de moro": "🌽",
    "tomàquet cherry": "🍅",
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
    "corn": "🌽",
    # Fruites
    "llimona": "🍋", "lemon": "🍋",
    "taronja": "🍊", "orange": "🍊",
    "maduixa": "🍓", "strawberry": "🍓",
    "plàtan": "🍌", "banana": "🍌",
    "poma": "🍎", "apple": "🍎",
    "raïm": "🍇", "grape": "🍇",
    "préssec": "🍑", "peach": "🍑",
    "pera": "🍐", "pear": "🍐",
    "síndria": "🍉", "watermelon": "🍉",
    "meló": "🍈", "melon": "🍈",
    "pinya": "🍍", "pineapple": "🍍",
    "mango": "🥭",
    "kiwi": "🥝",
    "cirera": "🍒", "cherry": "🍒",
    "pruna": "🍑", "plum": "🍑",
    "albercoc": "🍑", "apricot": "🍑",
    "gerd": "🫐", "raspberry": "🫐",
    "nabiu": "🫐", "blueberry": "🫐",
    "figa": "🍈", "fig": "🍈",
    "magrana": "🍎", "pomegranate": "🍎",
    # Carns
    "pollastre": "🍗", "chicken": "🍗",
    "vedella": "🥩", "beef": "🥩",
    "porc": "🥩", "pork": "🥩",
    "xai": "🥩", "lamb": "🥩",
    "gall dindi": "🦃", "turkey": "🦃",
    "bacon": "🥓",
    "pernil": "🥩", "ham": "🥩",
    "xoriço": "🌭", "chorizo": "🌭",
    "salsitxa": "🌭", "sausage": "🌭",
    "ànec": "🍗", "duck": "🍗",
    "conill": "🥩", "rabbit": "🥩",
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
    "mozzarella": "🧀",
    "parmesà": "🧀", "parmesan": "🧀",
    "cheddar": "🧀",
    # Cereals i llegums
    "arròs": "🍚", "rice": "🍚",
    "pasta": "🍝",
    "farina": "🌾", "flour": "🌾",
    "pa": "🍞", "bread": "🍞",
    "civada": "🌾", "oats": "🌾",
    "llenties": "🫘", "lentils": "🫘",
    "cigrons": "🫘", "chickpeas": "🫘",
    "mongetes": "🫘", "beans": "🫘",
    "quinoa": "🌾",
    "cuscús": "🌾", "couscous": "🌾",
    # Olis i condiments
    "oli": "🫙", "oil": "🫙",
    "vinagre": "🫙", "vinegar": "🫙",
    "salsa de soja": "🫙", "soy sauce": "🫙",
    "mostassa": "🫙", "mustard": "🫙",
    "ketchup": "🍅",
    "maionesa": "🫙", "mayonnaise": "🫙",
    "mel": "🍯", "honey": "🍯",
    "sucre": "🧂", "sugar": "🧂",
    "sal": "🧂", "salt": "🧂",
    "pebre": "🌶️", "pepper": "🌶️",
    "paprika": "🌶️",
    "comí": "🌿", "cumin": "🌿",
    "orenga": "🌿", "oregano": "🌿",
    "farigola": "🌿", "thyme": "🌿",
    "romaní": "🌿", "rosemary": "🌿",
    "llorer": "🌿", "bay": "🌿",
    "canyella": "🌿", "cinnamon": "🌿",
    "cúrcuma": "🌿", "turmeric": "🌿",
    "bitxo": "🌶️", "chili": "🌶️",
    # Fruits secs
    "ametlla": "🌰", "almond": "🌰",
    "nous": "🌰", "walnut": "🌰",
    "avellana": "🌰", "hazelnut": "🌰",
    "cacauet": "🥜", "peanut": "🥜",
    "anacard": "🌰", "cashew": "🌰",
    "pinyó": "🌰", "pine nut": "🌰",
    "sèsam": "🌰", "sesame": "🌰",
    "pansa": "🍇", "raisin": "🍇",
    "coco": "🥥", "coconut": "🥥",
    # Begudes
    "aigua": "💧", "water": "💧",
    "vi": "🍷", "wine": "🍷",
    "cervesa": "🍺", "beer": "🍺",
    "cafè": "☕", "coffee": "☕",
    "te": "🍵", "tea": "🍵",
    "brou": "🫙", "broth": "🫙", "stock": "🫙",
    # Conserves
    "conserva": "🥫", "canned": "🥫",
    "concentrat": "🥫", "paste": "🥫",
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


def get_emoji_intelligent(nom_ca, nom_en, categoria_nom):
    nom_ca_l = nom_ca.lower()
    nom_en_l = nom_en.lower() if nom_en else ""

    if nom_ca_l in EMOJI_MAP:
        return EMOJI_MAP[nom_ca_l]
    if nom_en_l in EMOJI_MAP:
        return EMOJI_MAP[nom_en_l]

    claus_ordenades = sorted(EMOJI_MAP.keys(), key=len, reverse=True)
    for clau in claus_ordenades:
        if clau in nom_ca_l or (nom_en_l and clau in nom_en_l):
            return EMOJI_MAP[clau]

    return CATEGORY_EMOJI.get(categoria_nom, "🛒")


class Command(BaseCommand):
    def add_arguments(self, parser):
        parser.add_argument('--dry-run', action='store_true',
                            help='Mostra els canvis sense aplicar-los')

    def handle(self, *args, **options):
        dry_run = options['dry_run']
        canviats = 0
        sense_canvi = 0

        productes = Producte.objects.select_related('categoria').all()
        self.stdout.write(f'Analitzant {productes.count()} productes...\n')

        for p in productes:
            nom_en = (p.alias_api or {}).get('nom_en', '')
            categoria_nom = p.categoria.nom
            emoji_correcte = get_emoji_intelligent(p.nom, nom_en, categoria_nom)

            if emoji_correcte != p.emoji:
                if dry_run:
                    self.stdout.write(f'  {p.emoji} → {emoji_correcte}  {p.nom}')
                else:
                    p.emoji = emoji_correcte
                    p.save(update_fields=['emoji'])
                    self.stdout.write(f'  ✓ {emoji_correcte}  {p.nom}')
                canviats += 1
            else:
                sense_canvi += 1

        prefix = '[DRY RUN] ' if dry_run else ''
        self.stdout.write(self.style.SUCCESS(
            f'\n{prefix}{canviats} emojis corregits, {sense_canvi} ja eren correctes.'
        ))