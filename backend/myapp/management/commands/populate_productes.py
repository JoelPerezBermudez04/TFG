import time
import requests
from django.core.management.base import BaseCommand
from myapp.models import Categoria, Producte

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


class Command(BaseCommand):
    help = 'Pobla la base de dades amb productes de Spoonacular'

    def add_arguments(self, parser):
        parser.add_argument(
            '--api-key',
            type=str,
            help='Spoonacular API key (opcional si ja està al .env)',
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Mostra el que faria sense escriure a la BD',
        )

    def handle(self, *args, **options):
        import os
        api_key = options.get('api_key') or os.environ.get('SPOONACULAR_API_KEY')
        if not api_key:
            self.stderr.write(self.style.ERROR(
                'Cal una API key. Usa --api-key o defineix SPOONACULAR_API_KEY al .env'
            ))
            return

        dry_run = options['dry_run']
        total_creats = 0
        total_existents = 0

        for categoria_nom, queries in CATEGORIES:
            self.stdout.write(f'\n {categoria_nom}')

            if not dry_run:
                categoria, _ = Categoria.objects.get_or_create(nom=categoria_nom)

            productes_categoria = set()

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
                    data = resp.json()

                    for item in data.get('results', []):
                        nom = item['name'].capitalize()
                        spoonacular_id = item['id']

                        if nom in productes_categoria:
                            continue
                        productes_categoria.add(nom)

                        if dry_run:
                            self.stdout.write(f'  [DRY] {nom} (id: {spoonacular_id})')
                            total_creats += 1
                        else:
                            _, creat = Producte.objects.get_or_create(
                                nom=nom,
                                defaults={
                                    'categoria': categoria,
                                    'alias_api': {'spoonacular_id': spoonacular_id},
                                }
                            )
                            if creat:
                                total_creats += 1
                                self.stdout.write(f'  ✓ {nom}')
                            else:
                                total_existents += 1

                    # Respecta el rate limit (150 req/dia pla gratuït)
                    time.sleep(0.5)

                except requests.exceptions.HTTPError as e:
                    if e.response.status_code == 402:
                        self.stderr.write(self.style.ERROR(
                            f'  Límit diari de la API assolit. Torna-ho a intentar demà.'
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