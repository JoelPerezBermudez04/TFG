from django.core.management.base import BaseCommand
from myapp.models import Producte


EMOJI_MAP = {
    # Herbes fresques
    "julivert": "🌿", "parsley": "🌿",
    "alfàbrega": "🌿", "basil": "🌿",
    "coriandre": "🌿", "cilantro": "🌿",
    "cebollí": "🌿", "chives": "🌿",
    "estragó": "🌿", "tarragon": "🌿",
    "menta": "🌿", "mint": "🌿",
    "marduix": "🌿", "marjoram": "🌿",
    # Espècies
    "gingebre": "🫚", "ginger": "🫚",
    "pebre de caiena": "🌶️", "cayenne pepper": "🌶️",
    "xili en pols": "🌶️", "chili powder": "🌶️",
    "curry en pols": "🫙", "curry powder": "🫙",
    "coriandre mòlt": "🌿", "ground coriander": "🌿",
    "gingebre mòlt": "🫚", "ground ginger": "🫚",
    "garam masala": "🫙",
    "cardamom": "🌿",
    "nou moscada": "🌿", "nutmeg": "🌿",
    "extracte de vainilla": "🍶", "vanilla extract": "🍶",
    "llevat en pols": "🌾", "baking powder": "🌾",
    "bicarbonat": "🌾", "baking soda": "🌾",
    "midó de blat de moro": "🌾", "cornstarch": "🌾",
    "cacau en pols": "🍫", "cocoa powder": "🍫",
    # Verdures noves
    "carbassa": "🎃", "butternut squash": "🎃",
    "moniato": "🍠", "sweet potato": "🍠",
    "col": "🥬", "cabbage": "🥬",
    "col rizada": "🥬", "kale": "🥬",
    "mongeta verda": "🫘", "green beans": "🫘",
    "nap": "🌿", "turnip": "🌿",
    "ceba tendra": "🧅", "green onion": "🧅",
    "escalunya": "🧅", "shallot": "🧅",
    "xili": "🌶️", "chili pepper": "🌶️",
    "jalapeño": "🌶️", "jalapeno": "🌶️",
    "alvocat": "🥑", "avocado": "🥑",
    # Fruites noves
    "llima": "🍋", "lime": "🍋",
    # Làctics nous
    "ricotta": "🧀",
    "ghee": "🧈",
    # Cereals i llegums nous
    "mongetes blanques": "🫘", "cannellini beans": "🫘",
    "macarrons": "🍝", "macaroni": "🍝",
    "civada (flocs)": "🌾", "oatmeal": "🌾",
    "granola": "🌾",
    # Condiments nous
    "vinagre balsàmic": "🫙", "balsamic vinegar": "🫙",
    "salsa worcestershire": "🫙", "worcestershire sauce": "🫙",
    "pasta de miso": "🫙", "miso paste": "🫙",
    "salsa teriyaki": "🫙", "teriyaki sauce": "🫙",
    "salsa sriracha": "🌶️", "sriracha": "🌶️",
    "olives": "🫒",
    "olives kalamata": "🫒", "kalamata olives": "🫒",
    "tàperes": "🫙", "capers": "🫙",
    # Brous nous
    "brou de vedella": "🫙", "beef broth": "🫙",
    "brou de pollastre (tetrabrik)": "🫙", "chicken stock": "🫙",
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