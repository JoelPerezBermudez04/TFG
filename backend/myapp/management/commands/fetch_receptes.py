"""
Management command: fetch_receptes_spoonacular
==============================================
Importa receptes de l'API de Spoonacular de forma incremental,
respectant el límit diari de punts i evitant duplicats.

Col·loca aquest fitxer a:
  <app>/management/commands/fetch_receptes_spoonacular.py

Ús:
  python manage.py fetch_receptes_spoonacular
  python manage.py fetch_receptes_spoonacular --compte 0        # usa el 1r compte
  python manage.py fetch_receptes_spoonacular --min-receptes 5  # mínim per ingredient
  python manage.py fetch_receptes_spoonacular --max-punts 50    # límit de punts del dia
  python manage.py fetch_receptes_spoonacular --dry-run         # mostra el pla sense fer res

Lògica de punts Spoonacular:
  - findByIngredients  → 1 punt per crida (retorna fins a 10 receptes)
  - getRecipeInformation → 1 punt per recepta
  - Exemple: 10 ingredients (5 lots de 2) + 10 receptes detall = 15 punts
"""

import json
import os
import time
import logging
from django.core.management.base import BaseCommand
from django.db import transaction

import requests

# Canvia 'api' pel nom real de la teva app Django
from myapp.models import Producte, Recepta, IngredientRecepta

logger = logging.getLogger(__name__)


# ─── Configuració dels comptes ───────────────────────────────────────────────
# Llegeix la API key del fitxer .env / variables d'entorn.
# Si tens múltiples comptes, pots afegir SPOONACULAR_API_KEY_2, etc.
def _carregar_api_keys() -> list[str]:
    keys = []
    # Clau principal
    key = os.environ.get("SPOONACULAR_API_KEY", "").strip()
    if key:
        keys.append(key)
    # Claus addicionals opcionals (SPOONACULAR_API_KEY_2 .. _4)
    for i in range(2, 5):
        key = os.environ.get(f"SPOONACULAR_API_KEY_{i}", "").strip()
        if key:
            keys.append(key)
    if not keys:
        raise ValueError(
            "No s'ha trobat cap SPOONACULAR_API_KEY al fitxer .env o les variables d'entorn."
        )
    return keys

API_KEYS = _carregar_api_keys()

MAX_PUNTS_PER_COMPTE = 50       # Punts disponibles per compte i dia
MIN_RECEPTES_PER_INGREDIENT = 3 # Mínim de receptes que ha de tenir cada ingredient
INGREDIENTS_PER_LOT = 1         # Quants ingredients per crida a findByIngredients
RECEPTES_PER_LOT = 5            # Quantes receptes demanem per crida (màx 10)
PAUSA_ENTRE_CRIDES = 1.0        # Segons entre crides (evita rate limiting)
MIN_INGREDIENTS_VINCULATS = 1   # Mínim d'ingredients vinculats per guardar una recepta

BASE_URL = "https://api.spoonacular.com"


# ─── Helpers ─────────────────────────────────────────────────────────────────

class LimitEpuisatError(Exception):
    """Tots els comptes han esgotat els punts del dia."""


class PaymentRequiredError(Exception):
    """API key ha esgotat els punts (HTTP 402)."""


class SpoonacularClient:
    """
    Client que gestiona múltiples API keys i controla el consum de punts.
    Rota automàticament al següent compte quan s'esgoten els punts.
    """

    def __init__(self, api_keys: list[str], max_punts: int, dry_run: bool = False):
        self.api_keys = api_keys
        self.max_punts = max_punts
        self.dry_run = dry_run
        self.compte_actual = 0
        # Punts consumits per compte en aquesta execució
        self.punts_usats = [0] * len(api_keys)

    @property
    def api_key(self) -> str:
        return self.api_keys[self.compte_actual]

    @property
    def punts_restants(self) -> int:
        return self.max_punts - self.punts_usats[self.compte_actual]

    @property
    def punts_totals_restants(self) -> int:
        return sum(
            self.max_punts - usats
            for usats in self.punts_usats
        )

    def _consumir_punts(self, n: int):
        self.punts_usats[self.compte_actual] += n
        if self.punts_usats[self.compte_actual] >= self.max_punts:
            self._rotar_compte()

    def _rotar_compte(self):
        """Passa al següent compte amb punts disponibles."""
        for i, usats in enumerate(self.punts_usats):
            if usats < self.max_punts:
                self.compte_actual = i
                logger.info(f"🔄 Rotant al compte #{i+1} ({self.max_punts - usats} punts restants)")
                return
        raise LimitEpuisatError("Tots els comptes han esgotat els punts del dia.")

    def _get(self, endpoint: str, params: dict) -> dict:
        if self.punts_restants <= 0:
            self._rotar_compte()
        if self.dry_run:
            return {}
        params["apiKey"] = self.api_key
        time.sleep(PAUSA_ENTRE_CRIDES)
        resp = requests.get(f"{BASE_URL}{endpoint}", params=params, timeout=15)
        
        # Detectar 402 (Payment Required) - API key sense punts
        if resp.status_code == 402:
            raise PaymentRequiredError(
                f"❌ Compte #{self.compte_actual + 1} ha esgotat els punts."
            )
        
        resp.raise_for_status()
        return resp.json()

    def find_by_ingredients(self, ingredients: list[str]) -> list[dict]:
        """
        Cerca receptes que continguin almenys algun dels ingredients indicats.
        Consumeix 1 punt.
        Retorna: llista de receptes amb usedIngredients / missedIngredients.
        """
        self._consumir_punts(1)
        data = self._get("/recipes/findByIngredients", {
            "ingredients": ",".join(ingredients),
            "number": RECEPTES_PER_LOT,
            "ranking": 1,           # Maximitza ingredients usats
            "ignorePantry": True,
        })
        return data if isinstance(data, list) else []

    def get_recipe_info(self, recipe_id: int) -> dict:
        """
        Obté el detall complet d'una recepta (ingredients, instruccions, dietes...).
        Consumeix 1 punt.
        """
        self._consumir_punts(1)
        return self._get(f"/recipes/{recipe_id}/information", {
            "includeNutrition": False,
        })


# ─── Lògica de mapping ────────────────────────────────────────────────────────

def alias_api_del_producte(producte: Producte) -> list[str]:
    """
    Retorna la llista de noms en anglès del producte per enviar a Spoonacular.
    alias_api és un dict amb la clau 'nom_en' (p.ex. {"nom_en": "coffee", ...}).
    Si no existeix, usa el nom del producte directament.
    """
    if producte.alias_api:
        if isinstance(producte.alias_api, dict):
            nom_en = producte.alias_api.get("nom_en")
            if nom_en:
                return [nom_en]
        if isinstance(producte.alias_api, list):
            return producte.alias_api
        if isinstance(producte.alias_api, str):
            return [producte.alias_api]
    return [producte.nom]


def receptes_actuals_per_producte(producte: Producte) -> int:
    """Compta quantes receptes té associades un producte."""
    return IngredientRecepta.objects.filter(producte=producte).count()


def productes_que_necessiten_mes_receptes(min_receptes: int) -> list[Producte]:
    """
    Retorna els productes que encara no han assolit el mínim de receptes,
    ordenats per nombre de receptes actuals (els menys coberts primer).
    """
    from django.db.models import Count
    productes = (
        Producte.objects
        .annotate(num_receptes=Count('ingredientrecepta'))
        .filter(num_receptes__lt=min_receptes)
        .order_by('num_receptes')
    )
    return list(productes)


def construir_lots(productes: list[Producte], mida_lot: int) -> list[list[Producte]]:
    """Divideix la llista de productes en lots de mida_lot."""
    return [productes[i:i+mida_lot] for i in range(0, len(productes), mida_lot)]


# ─── Guardat a BD ─────────────────────────────────────────────────────────────

# Factor de conversió a unitats mètriques (quantitat * factor = quantitat mètrica)
# (unitat_spoonacular_lowercase) -> (unitat_bd, factor)
_CONVERSIONS: dict[str, tuple[str, float]] = {
    # ── Ja en sistema mètric ──────────────────────────────────────────────────
    "g": ("g", 1.0), "gram": ("g", 1.0), "grams": ("g", 1.0),
    "kg": ("kg", 1.0), "kilogram": ("kg", 1.0), "kilograms": ("kg", 1.0),
    "ml": ("ml", 1.0), "milliliter": ("ml", 1.0), "milliliters": ("ml", 1.0),
    "l": ("L", 1.0), "liter": ("L", 1.0), "liters": ("L", 1.0),
    # ── Pes imperial ─────────────────────────────────────────────────────────
    "oz": ("g", 28.3495), "ounce": ("g", 28.3495), "ounces": ("g", 28.3495),
    "lb": ("kg", 0.453592), "lbs": ("kg", 0.453592),
    "pound": ("kg", 0.453592), "pounds": ("kg", 0.453592),
    # ── Volum imperial ────────────────────────────────────────────────────────
    "tsp": ("ml", 4.92892), "teaspoon": ("ml", 4.92892), "teaspoons": ("ml", 4.92892),
    "tbsp": ("ml", 14.7868), "tablespoon": ("ml", 14.7868), "tablespoons": ("ml", 14.7868),
    "fl oz": ("ml", 29.5735), "fluid ounce": ("ml", 29.5735), "fluid ounces": ("ml", 29.5735),
    "cup": ("ml", 236.588), "cups": ("ml", 236.588),
    "pint": ("ml", 473.176), "pints": ("ml", 473.176),
    "quart": ("L", 0.946353), "quarts": ("L", 0.946353),
    "gallon": ("L", 3.78541), "gallons": ("L", 3.78541),
    # ── Unitats comptables ────────────────────────────────────────────────────
    "": ("unitat", 1.0),
}


def normalitzar_unitat(unitat: str) -> str:
    """Retorna la unitat de la BD corresponent a la unitat de Spoonacular."""
    unitat_bd, _ = _CONVERSIONS.get(unitat.lower().strip(), ("unitat", 1.0))
    return unitat_bd


def convertir_quantitat(quantitat: float, unitat: str) -> tuple[float, str]:
    """
    Converteix una quantitat de Spoonacular al sistema mètric.
    Retorna (quantitat_convertida, unitat_bd).
    Exemples:
      (2, "cups")  -> (473.18, "ml")
      (1, "oz")    -> (28.35, "g")
      (3, "tbsp")  -> (44.36, "ml")
    """
    unitat_bd, factor = _CONVERSIONS.get(unitat.lower().strip(), ("unitat", 1.0))
    quantitat_convertida = round(quantitat * factor, 2)
    # Si el resultat en ml és >= 1000, passa a litres per llegibilitat
    if unitat_bd == "ml" and quantitat_convertida >= 1000:
        return round(quantitat_convertida / 1000, 3), "L"
    # Si el resultat en g és >= 1000, passa a kg
    if unitat_bd == "g" and quantitat_convertida >= 1000:
        return round(quantitat_convertida / 1000, 3), "kg"
    return quantitat_convertida, unitat_bd


def _alias_coincideix(alias, nom_lower: str) -> bool:
    """Comprova si l'alias (dict, llista o string) conté el nom."""
    if isinstance(alias, dict):
        return alias.get("nom_en", "").lower() == nom_lower
    if isinstance(alias, list):
        return any(a.lower() == nom_lower for a in alias if isinstance(a, str))
    if isinstance(alias, str):
        return alias.lower() == nom_lower
    return False


def _sinonims_coincideixen(sinonims, nom_lower: str) -> bool:
    """Comprova si la llista de sinònims conté el nom."""
    if not isinstance(sinonims, list):
        return False
    return any(s.lower() == nom_lower for s in sinonims if isinstance(s, str))


def _buscar_per_alias(nom_lower: str) -> Producte | None:
    for producte in Producte.objects.exclude(alias_api=None):
        if _alias_coincideix(producte.alias_api, nom_lower):
            return producte
    return None


def _buscar_per_sinonims(nom_lower: str) -> Producte | None:
    for producte in Producte.objects.exclude(sinonims=None):
        if _sinonims_coincideixen(producte.sinonims, nom_lower):
            return producte
    return None


def _buscar_per_nom(nom_lower: str) -> Producte | None:
    try:
        return Producte.objects.get(nom__iexact=nom_lower)
    except Producte.DoesNotExist:
        pass
    coincidencies = Producte.objects.filter(nom__icontains=nom_lower)
    return coincidencies.first() if coincidencies.count() == 1 else None


def trobar_producte_per_nom(nom_ingredient: str) -> Producte | None:
    """
    Intenta trobar un Producte de la nostra BD que correspongui
    a un ingredient de Spoonacular, buscant per alias_api.nom_en, sinonims o nom.
    """
    nom_lower = nom_ingredient.lower().strip()

    return (
        _buscar_per_alias(nom_lower)
        or _buscar_per_sinonims(nom_lower)
        or _buscar_per_nom(nom_lower)
    )


@transaction.atomic
def guardar_recepta(info: dict) -> tuple[Recepta, bool]:
    """
    Guarda o actualitza una Recepta i els seus IngredientRecepta.
    Retorna (recepta, creada_nova).
    """
    id_api = str(info.get("id", ""))
    if not id_api:
        return None, False

    # Evitar duplicats: si ja existeix, no la tornem a processar
    if Recepta.objects.filter(id_api=id_api).exists():
        return Recepta.objects.get(id_api=id_api), False

    # ── Instruccions ──
    instruccions_en = []
    for step_group in info.get("analyzedInstructions", []):
        for step in step_group.get("steps", []):
            instruccions_en.append({
                "num": step.get("number"),
                "text": step.get("step", ""),
            })

    # ── Dietes i intoleràncies (en anglès, per traduir més tard) ──
    dietes_en = info.get("diets", [])
    intolerancias_en = list(info.get("dishTypes", []))

    recepta = Recepta.objects.create(
        id_api=id_api,
        nom=info.get("title", ""),
        nom_en=info.get("title", ""),
        descripcio="",           # Es pot traduir en un pas posterior
        descripcio_en=info.get("summary", ""),  # ← Sempre string buit, mai NULL
        imatge_url=info.get("image", ""),
        temps_preparacio=info.get("readyInMinutes", 0),
        porcions=info.get("servings", 1),
        instruccions=None,       # Es pot traduir en un pas posterior
        instruccions_en=instruccions_en if instruccions_en else [],  # ← Lista buida, mai NULL
        dietes=None,
        dietes_en=dietes_en if dietes_en else [],  # ← Lista buida, mai NULL
        intolerancias=None,
        intolerancias_en=intolerancias_en if intolerancias_en else [],  # ← Lista buida, mai NULL
        ingredients_no_vinculats=[],
    )

    # ── Ingredients ──
    no_vinculats = []
    for ing in info.get("extendedIngredients", []):
        nom_ing = ing.get("name", "")
        producte = trobar_producte_per_nom(nom_ing)

        if producte:
            q, u = convertir_quantitat(ing.get("amount", 0), ing.get("unit", ""))
            IngredientRecepta.objects.get_or_create(
                recepta=recepta,
                producte=producte,
                defaults={
                    "quantitat": q,
                    "unitat": u,
                    "nom_original": ing.get("originalName", nom_ing),
                }
            )
        else:
            q, u = convertir_quantitat(ing.get("amount", 0), ing.get("unit", ""))
            no_vinculats.append({
                "nom": nom_ing,
                "quantitat": q,
                "unitat": u,
                "original": ing.get("originalName", nom_ing),
            })

    # Comprovem si té prou ingredients vinculats
    num_vinculats = recepta.ingredientrecepta_set.count()
    if num_vinculats < MIN_INGREDIENTS_VINCULATS:
        recepta.delete()
        return None, False

    # Guardem els ingredients que no hem pogut vincular
    recepta.ingredients_no_vinculats = no_vinculats
    recepta.save(update_fields=["ingredients_no_vinculats"])

    return recepta, True


# ─── Command principal ────────────────────────────────────────────────────────

class Command(BaseCommand):
    help = (
        "Importa receptes de Spoonacular per als productes que no arriben "
        "al mínim de receptes configurat. Gestiona múltiples API keys."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--compte", type=int, default=None,
            help="Índex del compte a usar (0-3). Per defecte rota automàticament.",
        )
        parser.add_argument(
            "--min-receptes", type=int, default=MIN_RECEPTES_PER_INGREDIENT,
            help=f"Mínim de receptes per ingredient (defecte: {MIN_RECEPTES_PER_INGREDIENT}).",
        )
        parser.add_argument(
            "--max-punts", type=int, default=MAX_PUNTS_PER_COMPTE,
            help=f"Punts disponibles per compte (defecte: {MAX_PUNTS_PER_COMPTE}).",
        )
        parser.add_argument(
            "--dry-run", action="store_true",
            help="Mostra el pla sense fer crides ni guardar res.",
        )

    def handle(self, *args, **options):
        min_receptes = options["min_receptes"]
        max_punts    = options["max_punts"]
        dry_run      = options["dry_run"]

        self._escriure_capcalera(min_receptes, max_punts, dry_run)

        client = self._inicialitzar_client(max_punts, dry_run, options["compte"])

        productes_pendents = productes_que_necessiten_mes_receptes(min_receptes)
        total_pendents     = len(productes_pendents)
        self._escriure_resum_pendents(productes_pendents, min_receptes)

        if not productes_pendents:
            self.stdout.write(self.style.SUCCESS("✅ Tots els productes ja tenen prou receptes!"))
            return

        if dry_run:
            self._mostrar_dry_run(productes_pendents, min_receptes)
            return

        receptes_creades, receptes_duplicades, errors = self._processar_lots(
            productes_pendents, min_receptes, client
        )

        productes_complets = len(productes_que_necessiten_mes_receptes(min_receptes))
        self._escriure_resum_final(
            receptes_creades, receptes_duplicades, errors,
            productes_complets, total_pendents, client
        )


    # ── Helpers d'inicialització i presentació ───────────────────────────────────

    def _escriure_capcalera(self, min_receptes, max_punts, dry_run):
        self.stdout.write(self.style.SUCCESS(
            f"\n{'='*60}\n"
            f"  fetch_receptes_spoonacular\n"
            f"  Mínim receptes/ingredient : {min_receptes}\n"
            f"  Punts per compte          : {max_punts}\n"
            f"  Punts totals disponibles  : {max_punts * len(API_KEYS)}\n"
            f"  Dry-run                   : {dry_run}\n"
            f"{'='*60}\n"
        ))


    def _inicialitzar_client(self, max_punts, dry_run, compte_inicial):
        client = SpoonacularClient(API_KEYS, max_punts, dry_run)
        if compte_inicial is not None:
            client.compte_actual = compte_inicial
            self.stdout.write(f"Usant compte #{compte_inicial + 1} com a inicial.\n")
        return client


    def _escriure_resum_pendents(self, productes_pendents, min_receptes):
        total = len(productes_pendents)
        self.stdout.write(
            f"📋 Productes que necessiten més receptes: {total}\n"
            f"   Mínim de receptes per ingredient    : {min_receptes}\n"
            f"   Punts estimats necessaris: ~{total * 2} "
            f"(1 cerca + ~1 detall per lot)\n\n"
        )


    def _mostrar_dry_run(self, productes_pendents, min_receptes):
        self.stdout.write("🔍 DRY-RUN: Els primers 10 productes pendents:")
        for p in productes_pendents[:10]:
            n = receptes_actuals_per_producte(p)
            self.stdout.write(
                f"   - {p} | receptes: {n}/{min_receptes} | "
                f"alias_api: {alias_api_del_producte(p)}"
            )


    def _escriure_resum_final(self, creades, duplicades, errors,
                            complets, total_pendents, client):
        self.stdout.write(self.style.SUCCESS(
            f"\n{'='*60}\n"
            f"  RESUM\n"
            f"  Receptes creades       : {creades}\n"
            f"  Receptes ja existents  : {duplicades}\n"
            f"  Errors                 : {errors}\n"
            f"  Productes pendents     : {complets}/{total_pendents}\n"
            f"  Punts usats per compte : {client.punts_usats}\n"
            f"{'='*60}\n"
        ))


    # ── Processament de lots ──────────────────────────────────────────────────────

    def _processar_lots(self, productes_pendents, min_receptes, client):
        lots = construir_lots(productes_pendents, INGREDIENTS_PER_LOT)
        receptes_creades = receptes_duplicades = errors = 0

        try:
            for i, lot in enumerate(lots):
                creades, duplicades, lot_errors, stop = self._processar_lot(
                    i, lot, lots, min_receptes, client
                )
                receptes_creades    += creades
                receptes_duplicades += duplicades
                errors              += lot_errors
                if stop:
                    break
        except KeyboardInterrupt:
            self.stdout.write(self.style.WARNING("\n\n⚠️  Interromput per l'usuari."))

        return receptes_creades, receptes_duplicades, errors


    def _processar_lot(self, i, lot, lots, min_receptes, client):
        """Retorna (creades, duplicades, errors, stop)."""
        lot_filtrat = [p for p in lot if receptes_actuals_per_producte(p) < min_receptes]
        if not lot_filtrat:
            return 0, 0, 0, False

        noms_lot = [nom for p in lot_filtrat for nom in alias_api_del_producte(p)]
        self.stdout.write(
            f"[{i+1}/{len(lots)}] 🔎 Lot: {[p.nom for p in lot_filtrat]} | "
            f"Punts restants: {client.punts_totals_restants}"
        )

        resultats, stop = self._cercar_resultats(client, noms_lot)
        if stop:
            return 0, 0, 0, True
        if resultats is None:
            return 0, 0, 1, False
        if not resultats:
            self.stdout.write("   ℹ️  Cap resultat per aquest lot.")
            return 0, 0, 0, False

        creades, duplicades, errors, stop = self._processar_resultats(
            resultats, lot_filtrat, client
        )
        return creades, duplicades, errors, stop


    def _cercar_resultats(self, client, noms_lot):
        """Retorna (resultats | None, stop)."""
        try:
            return client.find_by_ingredients(noms_lot), False
        except PaymentRequiredError as e:
            self._escriure_error_quota(str(e))
            return None, True
        except LimitEpuisatError:
            self._escriure_error_limit()
            return None, True
        except requests.RequestException as e:
            self.stdout.write(self.style.WARNING(f"   ⚠️  Error de xarxa: {e}"))
            return None, False


    def _processar_resultats(self, resultats, lot_filtrat, client):
        """Retorna (creades, duplicades, errors, stop)."""
        creades = duplicades = errors = 0
        for resultat in resultats:
            recipe_id = resultat.get("id")
            if not recipe_id:
                continue

            if Recepta.objects.filter(id_api=str(recipe_id)).exists():
                self.stdout.write(f"   ↩️  Recepta {recipe_id} ja existeix, vinculant...")
                duplicades += 1
                recepta_existent = Recepta.objects.get(id_api=str(recipe_id))
                self._vincular_recepta_a_lot(recepta_existent, lot_filtrat)
                continue

            info, stop = self._obtenir_info_recepta(client, recipe_id)
            if stop:
                return creades, duplicades, errors, True
            if info is None:
                errors += 1
                continue

            nova_creada, duplicada = self._guardar_i_reportar(info, recipe_id)
            creades    += nova_creada
            duplicades += duplicada

        return creades, duplicades, errors, False


    def _obtenir_info_recepta(self, client, recipe_id):
        """Retorna (info | None, stop)."""
        try:
            return client.get_recipe_info(recipe_id), False
        except PaymentRequiredError as e:
            self._escriure_error_quota(str(e))
            return None, True
        except LimitEpuisatError:
            self._escriure_error_limit()
            return None, True
        except requests.RequestException as e:
            self.stdout.write(self.style.WARNING(
                f"   ⚠️  Error obtenint recepta {recipe_id}: {e}"
            ))
            return None, False


    def _guardar_i_reportar(self, info, recipe_id):
        """Retorna (creades, duplicades) com a enters 0/1."""
        recepta, creada = guardar_recepta(info)
        if creada:
            self.stdout.write(
                f"   ✅ Guardada: {recepta.nom} "
                f"({recepta.ingredientrecepta_set.count()} vinculats / "
                f"{len(recepta.ingredients_no_vinculats or [])} sense vincular)"
            )
            return 1, 0
        if recepta is None:
            self.stdout.write(
                f"   ⏭️  Recepta {info.get('title', recipe_id)} descartada "
                f"(0 ingredients vinculats)"
            )
            return 0, 0
        return 0, 1


    # ── Missatges d'error reutilitzables ─────────────────────────────────────────

    def _escriure_error_quota(self, missatge):
        self.stdout.write(self.style.ERROR(f"\n{missatge}"))
        self.stdout.write(self.style.ERROR("⛔ API key sense punts. Torna-ho a executar demà.\n"))


    def _escriure_error_limit(self):
        self.stdout.write(self.style.ERROR(
            "\n⛔ Tots els punts del dia esgotats. Torna-ho a executar demà.\n"
        ))

    def _vincular_recepta_a_lot(self, recepta: Recepta, lot: list[Producte]):
        """
        Intenta crear IngredientRecepta per als productes del lot
        que ja estiguin als ingredients_no_vinculats de la recepta.
        """
        no_vinculats = recepta.ingredients_no_vinculats or []
        vinculats_nous = []

        for no_vinculat in no_vinculats:
            nom_ing = no_vinculat.get("nom", "")
            producte = trobar_producte_per_nom(nom_ing)
            if producte and producte in lot:
                # Les quantitats de no_vinculats ja estan en mètric (guardades per guardar_recepta)
                _, creat = IngredientRecepta.objects.get_or_create(
                    recepta=recepta,
                    producte=producte,
                    defaults={
                        "quantitat": no_vinculat.get("quantitat", 0),
                        "unitat": no_vinculat.get("unitat", "unitat"),
                        "nom_original": no_vinculat.get("original", nom_ing),
                    }
                )
                if creat:
                    vinculats_nous.append(nom_ing)

        if vinculats_nous:
            # Elimina els ja vinculats de la llista
            recepta.ingredients_no_vinculats = [
                nv for nv in no_vinculats
                if nv.get("nom") not in vinculats_nous
            ]
            recepta.save(update_fields=["ingredients_no_vinculats"])