import time
from django.core.management.base import BaseCommand
from myapp.models import Recepta

try:
    from deep_translator import GoogleTranslator
    HAS_TRANSLATOR = True
except ImportError:
    HAS_TRANSLATOR = False


class Command(BaseCommand):
    help = 'Tradueix les receptes de l\'anglès al català i guarda els originals als camps _en'

    def add_arguments(self, parser):
        parser.add_argument('--dry-run', action='store_true',
                            help='Mostra les traduccions sense guardar')
        parser.add_argument('--force', action='store_true',
                            help='Retraddueix les receptes ja traduïdes')
        parser.add_argument('--recepta-id', type=str,
                            help='Tradueix només una recepta per ID (ex: 654005)')

    def handle(self, *args, **options):
        if not HAS_TRANSLATOR:
            self.stderr.write(self.style.ERROR(
                'Cal instal·lar deep_translator: pip install deep-translator'
            ))
            return

        dry_run = options['dry_run']
        force = options['force']
        recepta_id = options.get('recepta_id')

        translator = GoogleTranslator(source='en', target='ca')

        if recepta_id:
            receptes = Recepta.objects.filter(id_api=recepta_id)
        elif force:
            receptes = Recepta.objects.all()
        else:
            # Salta les que ja estan traduïdes.
            # Una recepta NO està traduïda si nom == nom_en (tots dos en anglès)
            # o si nom_en és buit (receptes carregades abans d'afegir el camp).
            from django.db.models import Q, F
            receptes = Recepta.objects.filter(
                Q(nom_en='') | Q(nom=F('nom_en'))
            )

        if not receptes.exists():
            self.stdout.write('Cap recepta per traduir.')
            return

        total = receptes.count()
        errors = 0

        self.stdout.write(self.style.SUCCESS(f'🌐 Traduint {total} receptes\n'))

        for recepta in receptes:
            try:
                self.stdout.write(f'\n📖 {recepta.nom}')

                # ── Desa els originals en anglès (si no estan ja guardats) ──
                # Si nom_en ja té valor (execució anterior) el conservem.
                nom_en = recepta.nom_en or recepta.nom
                descripcio_en = recepta.descripcio_en or recepta.descripcio
                instruccions_en = recepta.instruccions_en or recepta.instruccions
                dietes_en = recepta.dietes_en or recepta.dietes
                intolerancias_en = recepta.intolerancias_en or recepta.intolerancias

                # ── Tradueix nom ─────────────────────────────────────────────
                nom_ca = traduir(nom_en, translator)
                self.stdout.write(f'   Nom: {nom_en} → {nom_ca}')

                # ── Tradueix descripció ──────────────────────────────────────
                descripcio_ca = ''
                if descripcio_en:
                    descripcio_ca = traduir(descripcio_en, translator)
                    preview = descripcio_ca[:80] + '...' if len(descripcio_ca) > 80 else descripcio_ca
                    self.stdout.write(f'   Descripció: {preview}')

                # ── Tradueix instruccions [{num, text}] ──────────────────────
                instruccions_ca = None
                if instruccions_en:
                    instruccions_ca = []
                    for pas in instruccions_en:
                        text_ca = traduir(pas.get('text', ''), translator)
                        instruccions_ca.append({'num': pas.get('num'), 'text': text_ca})
                    self.stdout.write(f'   Instruccions: {len(instruccions_ca)} passos traduïts')

                # ── Tradueix dietes ["vegetarian", ...] ──────────────────────
                dietes_ca = None
                if dietes_en:
                    dietes_ca = [traduir(d, translator) for d in dietes_en]
                    self.stdout.write(f'   Dietes: {", ".join(dietes_ca)}')

                # ── Tradueix intoleràncies ["dairy", ...] ─────────────────────
                intolerancias_ca = None
                if intolerancias_en:
                    intolerancias_ca = [traduir(i, translator) for i in intolerancias_en]
                    self.stdout.write(f'   Intolerancies: {", ".join(intolerancias_ca)}')

                if not dry_run:
                    recepta.nom_en = nom_en
                    recepta.descripcio_en = descripcio_en
                    recepta.instruccions_en = instruccions_en
                    recepta.dietes_en = dietes_en
                    recepta.intolerancias_en = intolerancias_en

                    recepta.nom = nom_ca
                    recepta.descripcio = descripcio_ca
                    if instruccions_ca is not None:
                        recepta.instruccions = instruccions_ca
                    if dietes_ca is not None:
                        recepta.dietes = dietes_ca
                    if intolerancias_ca is not None:
                        recepta.intolerancias = intolerancias_ca

                    recepta.save()
                    self.stdout.write(self.style.SUCCESS('   ✓ Guardat'))
                else:
                    self.stdout.write('   [DRY RUN - no guardat]')

                time.sleep(0.5)

            except Exception as e:
                errors += 1
                self.stderr.write(self.style.ERROR(f'   ✗ Error: {e}'))

        prefix = '[DRY RUN] ' if dry_run else ''
        self.stdout.write(self.style.SUCCESS(f'\n{prefix}✅ Fet!'))
        self.stdout.write(f'  ✓ {total - errors} receptes traduïdes\n  ✗ {errors} errors')


def traduir(text: str, translator) -> str:
    if not text or not isinstance(text, str):
        return text or ''
    text = text.strip()
    if not text:
        return text
    try:
        return translator.translate(text) or text
    except Exception as e:
        raise ValueError(f"Error traduint '{text[:50]}': {e}")