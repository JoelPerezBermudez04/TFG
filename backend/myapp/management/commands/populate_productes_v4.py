import time
import requests
import os
from django.core.management.base import BaseCommand
from myapp.models import Categoria, Producte

SPOONACULAR_IMG_BASE = 'https://img.spoonacular.com/ingredients_100x100/'

EMOJI_MAP = {
    "salsitxes picants": "🌭", "spicy sausages": "🌭",
    "amanida de primavera": "🥗", "spring salad": "🥗",
    "xoriços": "🌭", "chorizos": "🌭",
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
    ("Carns", [
        "spicy sausages",
        "chorizos",
    ]),
    ("Fruites", [
    ]),
    ("Verdures i hortalisses", [
        "spring salad",
    ]),
    ("Peix i marisc", [
        
    ]),
    ("Cereals i llegums", [
        
    ]),
    ("Olis i condiments", [
        
    ]),
    ("Begudes", [
        
    ]),
]

# Sinonims a afegir a productes ja existents (sense cridar l'API)
SINONIMS = {
    
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

        # ── Afegeix sinonims a productes existents (sense API) ────────────────
        self.stdout.write('\n🔗 Afegint sinonims a productes existents...')
        for nom_ca, nous_sinonims in SINONIMS.items():
            try:
                p = Producte.objects.get(nom__iexact=nom_ca)
                sinonims_actuals = p.sinonims or []
                nous = [s for s in nous_sinonims if s not in sinonims_actuals]
                if nous:
                    if not dry_run:
                        p.sinonims = sinonims_actuals + nous
                        p.save()
                    prefix = '[DRY] ' if dry_run else ''
                    self.stdout.write(f'  {prefix}✓ {nom_ca} → +{nous}')
                else:
                    self.stdout.write(f'  ⏭️  {nom_ca} (sinonims ja existeixen)')
            except Producte.DoesNotExist:
                self.stderr.write(self.style.WARNING(f'  ✗ No trobat: {nom_ca}'))

        # ── Afegeix productes nous ────────────────────────────────────────────
        self.stdout.write('\n📦 Afegint productes nous...')
        for categoria_nom, queries in CATEGORIES:
            self.stdout.write(f'\n {categoria_nom}')

            if not dry_run:
                categoria, _ = Categoria.objects.get_or_create(
                    nom=categoria_nom,
                    defaults={'emoji': CATEGORY_EMOJI.get(categoria_nom, "🛒")}
                )

            vistos = set()

            for query in queries:
                if not force and Producte.objects.filter(
                    alias_api__nom_en__iexact=query
                ).exists():
                    self.stdout.write(f'  ⏭️  "{query}" (ja existeix, saltant...)')
                    total_saltats += 1
                    continue

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
                        image_filename = item.get('image')
                        imatge_url = build_imatge_url(image_filename)

                        if nom_en in vistos:
                            continue
                        vistos.add(nom_en)

                        nom_ca = traduir_al_catala(nom_en)
                        emoji = get_emoji(nom_ca, nom_en, categoria_nom)

                        if dry_run:
                            img_info = '🖼️' if imatge_url else '(sense imatge)'
                            self.stdout.write(f'  [DRY] {emoji} {nom_ca} ({nom_en}) {img_info}')
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
                                        'image_filename': image_filename,
                                    },
                                }
                            )
                            if creat:
                                total_creats += 1
                                img_info = '🖼️' if imatge_url else '(sense imatge)'
                                self.stdout.write(f'  ✓ {emoji} {nom_ca} ({nom_en}) {img_info}')
                            else:
                                total_existents += 1

                    time.sleep(0.5)

                except requests.exceptions.HTTPError as e:
                    if e.response.status_code == 402:
                        self.stderr.write(self.style.ERROR(
                            '\n💳 Límit diari de la API assolit.'
                            '\nTorna a executar l\'script demà.'
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
            f'  ⏭️  {saltats} ja existien (saltats sense cridar l\'API)\n'
            f'  = {existents} duplicats per nom català ignorats\n'
        )