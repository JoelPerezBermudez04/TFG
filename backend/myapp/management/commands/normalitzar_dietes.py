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


# Mapeig complet: valor actual (en qualsevol forma) → valor normalitzat
# Qualsevol valor que no aparegui aquí s'ELIMINA (no és una dieta real)
NORMALITZACIO = {
    # Vegetarià/vegà
    'vegetarian':               'Vegetarià',
    'vegetariana':              'Vegetarià',
    'vegetarià':                'Vegetarià',
    'vegan':                    'Vegà',
    'vegà':                     'Vegà',
    'lacto ovo vegetarian':     'Lacto-ovo-vegetarià',
    'lacto ovo vegetarià':      'Lacto-ovo-vegetarià',
    'lacto-ovo-vegetarià':      'Lacto-ovo-vegetarià',
    'lacto vegetarian':         'Lacto-ovo-vegetarià',
    'ovo vegetarian':           'Lacto-ovo-vegetarià',

    # Pescatari
    'pescatarian':              'Pescatarià',
    'pescatarià':               'Pescatarià',
    'pescatari':                'Pescatarià',

    # Sense gluten / làctics
    'gluten free':              'Sense gluten',
    'sense gluten':             'Sense gluten',
    'dairy free':               'Sense làctics',
    'lliure de lactis':         'Sense làctics',
    'sense làctics':            'Sense làctics',

    # FODMAP
    'low fodmap':               'Baix en FODMAP',
    'mapa fodmap baix':         'Baix en FODMAP',
    'baix en fodmap':           'Baix en FODMAP',
    'fodmap friendly':          'Compatible amb FODMAP',
    'amigable amb fodmap':      'Compatible amb FODMAP',
    'compatible amb fodmap':    'Compatible amb FODMAP',

    # Altres dietes
    'ketogenic':                'Cetogènica',
    'cetogènics':               'Cetogènica',
    'cetogènica':               'Cetogènica',
    'paleo':                    'Paleolítica',
    'paleolithic':              'Paleolítica',
    'paleolític':               'Paleolítica',
    'paleolítica':              'Paleolítica',
    'primal':                   'Primal',
    'primordial':               'Primal',
    'whole30':                  'Whole30',
    'whole 30':                 'Whole30',
    'sencer 30':                'Whole30',

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