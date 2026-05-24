"""
Management command: normalitzar_dietes
=======================================
Normalitza els valors del camp `dietes` de totes les receptes:
  - Elimina etiquetes que no són dietes (very popular, very healthy...)
  - Corregeix traduccions inconsistents (pescatari/pescatarià, etc.)
  - Usa un diccionari fix en lloc de Google Translate per les dietes

Col·loca aquest fitxer a:
  myapp/management/commands/normalitzar_dietes.py

Ús:
  python manage.py normalitzar_dietes
  python manage.py normalitzar_dietes --dry-run
"""

from django.core.management.base import BaseCommand
from myapp.models import Recepta


# Dietes normalitzades compartides per evitar duplicació.
VEGETARIA = 'Vegetarià'
VEGA = 'Vegà'
LACTO_OVO_VEGETARIA = 'Lacto-ovo-vegetarià'
PESCATARIA = 'Pescatarià'
SENSE_GLUTEN = 'Sense gluten'
SENSE_LACTICS = 'Sense làctics'
BAIX_EN_FODMAP = 'Baix en FODMAP'
COMPATIBLE_AMB_FODMAP = 'Compatible amb FODMAP'
CETOGENICA = 'Cetogènica'
PALEOLITICA = 'Paleolítica'
PRIMAL = 'Primal'
WHOLE30 = 'Whole30'


# Mapeig complet: valor actual (en qualsevol forma) → valor normalitzat
# Qualsevol valor que no aparegui aquí s'ELIMINA (no és una dieta real)
NORMALITZACIO = {
    # Vegetarià/vegà
    'vegetarian':               VEGETARIA,
    'vegetariana':              VEGETARIA,
    'vegetarià':                VEGETARIA,
    'vegan':                    VEGA,
    'vegà':                     VEGA,
    'lacto ovo vegetarian':     LACTO_OVO_VEGETARIA,
    'lacto ovo vegetarià':      LACTO_OVO_VEGETARIA,
    'lacto-ovo-vegetarià':      LACTO_OVO_VEGETARIA,
    'lacto vegetarian':         LACTO_OVO_VEGETARIA,
    'ovo vegetarian':           LACTO_OVO_VEGETARIA,

    # Pescatari
    'pescatarian':              PESCATARIA,
    'pescatarià':               PESCATARIA,
    'pescatari':                PESCATARIA,

    # Sense gluten / làctics
    'gluten free':              SENSE_GLUTEN,
    'sense gluten':             SENSE_GLUTEN,
    'dairy free':               SENSE_LACTICS,
    'lliure de lactis':         SENSE_LACTICS,
    'sense làctics':            SENSE_LACTICS,

    # FODMAP
    'low fodmap':               BAIX_EN_FODMAP,
    'mapa fodmap baix':         BAIX_EN_FODMAP,
    'baix en fodmap':           BAIX_EN_FODMAP,
    'fodmap friendly':          COMPATIBLE_AMB_FODMAP,
    'amigable amb fodmap':      COMPATIBLE_AMB_FODMAP,
    'compatible amb fodmap':    COMPATIBLE_AMB_FODMAP,

    # Altres dietes
    'ketogenic':                CETOGENICA,
    'cetogènics':               CETOGENICA,
    'cetogènica':               CETOGENICA,
    'paleo':                    PALEOLITICA,
    'paleolithic':              PALEOLITICA,
    'paleolític':               PALEOLITICA,
    'paleolítica':              PALEOLITICA,
    'primal':                   PRIMAL,
    'primordial':               PRIMAL,
    'whole30':                  WHOLE30,
    'whole 30':                 WHOLE30,
    'sencer 30':                WHOLE30,

    # ── Valors a ELIMINAR (no són dietes) ──────────────────────────────
    # very popular, very healthy → no s'afegeixen al mapeig → s'eliminen
}

# Valors explícitament ignorats (per logs més nets)
IGNORATS = {
    'very popular', 'molt popular',
    'very healthy', 'molt saludable',
}


def normalitzar(dietes_actuals: list) -> list:
    """Retorna la llista de dietes normalitzada, sense duplicats."""
    result = []
    seen = set()
    for d in (dietes_actuals or []):
        clau = d.lower().strip()
        normalitzat = NORMALITZACIO.get(clau)
        if normalitzat and normalitzat not in seen:
            result.append(normalitzat)
            seen.add(normalitzat)
        # Si no és al mapeig i no és ignorat explícitament → s'elimina igualment
    return result


class Command(BaseCommand):
    help = "Normalitza els valors de dietes de totes les receptes."

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run', action='store_true',
            help='Mostra els canvis sense guardar res.',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']

        if dry_run:
            self.stdout.write(self.style.WARNING("🔍 DRY-RUN activat, no es guardarà res.\n"))

        total = Recepta.objects.count()
        actualitzades = 0
        sense_canvis = 0

        for recepta in Recepta.objects.all().iterator():
            dietes_actuals = recepta.dietes or []
            dietes_noves = normalitzar(dietes_actuals)

            if sorted(dietes_actuals) == sorted(dietes_noves):
                sense_canvis += 1
                continue

            if dry_run:
                self.stdout.write(
                    f"  {recepta.nom[:55]}\n"
                    f"    abans : {dietes_actuals}\n"
                    f"    després: {dietes_noves}\n"
                )
            else:
                recepta.dietes = dietes_noves
                recepta.save(update_fields=['dietes'])

            actualitzades += 1

        self.stdout.write(self.style.SUCCESS(
            f"\n{'='*50}\n"
            f"  RESUM {'(DRY-RUN)' if dry_run else ''}\n"
            f"  Total receptes      : {total}\n"
            f"  Actualitzades       : {actualitzades}\n"
            f"  Sense canvis        : {sense_canvis}\n"
            f"{'='*50}\n"
        ))

        if not dry_run:
            self._mostrar_resum_final()

    def _mostrar_resum_final(self):
        from django.db.models import Q
        dietes = set()
        for r in Recepta.objects.exclude(Q(dietes=None) | Q(dietes=[])):
            dietes.update(r.dietes or [])

        self.stdout.write("\n📊 Dietes úniques resultants:")
        for d in sorted(dietes):
            self.stdout.write(f"  - {d}")