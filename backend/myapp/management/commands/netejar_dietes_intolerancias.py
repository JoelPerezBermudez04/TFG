"""
Management command: netejar_dietes_intolerancias
================================================
Corregeix els camps dietes i intolerancias de totes les receptes existents.

Problema detectat:
  - intolerancias_en contenia dishTypes (tipus de plat: lunch, dinner...),
    no al·lèrgens. Per tant intolerancias (traducció) també era incorrecte.
  - dietes estava a NULL en moltes receptes (la traducció no s'havia executat
    o dietes_en estava buit).

Solució:
  1. Buida intolerancias i intolerancias_en (eren dishTypes, incorrecte).
  2. Marca les receptes com a "no traduïdes" (nom = nom_en) perquè
     translate_receptes les torni a processar i regeneri dietes correctament.

Ús:
  python manage.py netejar_dietes_intolerancias
  python manage.py netejar_dietes_intolerancias --dry-run

Després d'executar aquest script, torna a córrer:
  python manage.py translate_receptes
"""

from django.core.management.base import BaseCommand
from myapp.models import Recepta


class Command(BaseCommand):
    help = (
        "Buida intolerancias (eren dishTypes incorrectes) i força la "
        "retraducció de dietes via translate_receptes."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run", action="store_true",
            help="Mostra els canvis sense guardar res.",
        )

    def handle(self, *args, **options):
        dry_run = options["dry_run"]

        if dry_run:
            self.stdout.write(self.style.WARNING("🔍 DRY-RUN activat, no es guardarà res.\n"))

        total = Recepta.objects.count()
        self.stdout.write(f"📋 Processant {total} receptes...\n")

        actualitzades = 0
        ja_netes = 0

        for recepta in Recepta.objects.all().iterator():
            intols_incorrectes = recepta.intolerancias_en or []
            dietes_en = recepta.dietes_en or []

            # Si no hi havia intolerancias_en ni dietes, no cal fer res
            if not intols_incorrectes and recepta.dietes:
                ja_netes += 1
                continue

            if dry_run:
                self.stdout.write(
                    f"  {recepta.nom[:50]}\n"
                    f"    intolerancias_en (incorrecte) : {intols_incorrectes}\n"
                    f"    intolerancias → []\n"
                    f"    dietes_en                     : {dietes_en}\n"
                    f"    dietes → (es regenerarà via translate_receptes)\n"
                )
            else:
                recepta.intolerancias_en = []
                recepta.intolerancias = []
                # Força retraducció: si nom == nom_en translate_receptes la reprocesarà
                # Si nom_en és buit, posem el nom actual com a nom_en
                if not recepta.nom_en:
                    recepta.nom_en = recepta.nom
                # Marca com a pendent de traducció
                recepta.nom = recepta.nom_en
                recepta.dietes = []
                recepta.save(update_fields=[
                    "intolerancias_en", "intolerancias",
                    "dietes", "nom", "nom_en"
                ])

            actualitzades += 1

        self.stdout.write(self.style.SUCCESS(
            f"\n{'='*50}\n"
            f"  RESUM {'(DRY-RUN)' if dry_run else ''}\n"
            f"  Receptes processades : {total}\n"
            f"  Actualitzades        : {actualitzades}\n"
            f"  Ja netes             : {ja_netes}\n"
            f"{'='*50}\n"
        ))

        if not dry_run:
            self.stdout.write(self.style.WARNING(
                "\n⚠️  Ara executa:\n"
                "   python manage.py translate_receptes\n"
                "   per regenerar dietes en català correctament.\n"
            ))