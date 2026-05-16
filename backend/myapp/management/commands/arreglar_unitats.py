"""
Script de migració: converteix les unitats imperials existents a la BD al sistema mètric.

Executa des del shell de Django:
  python manage.py shell < migrar_unitats_metriques.py

O copia el contingut al shell interactiu:
  python manage.py shell
"""

from myapp.models import IngredientRecepta, Recepta
from myapp.management.commands.fetch_receptes import convertir_quantitat

# Unitats que NO són mètriques i cal convertir
UNITATS_IMPERIALS = {"oz", "lb", "lbs", "tsp", "tbsp", "cup", "cups",
                     "fl oz", "pint", "quart", "gallon",
                     "pound", "ounce", "teaspoon", "tablespoon", "tbs", "tablespoons"}

# ── 1. Convertir IngredientRecepta amb unitats imperials ─────────────────────
print("🔄 Convertint IngredientRecepta...")
ingredients_actualitzats = 0
for ing in IngredientRecepta.objects.select_related("recepta", "unitat").all():
    if ing.unitat.lower().strip() in UNITATS_IMPERIALS:
        nova_quantitat, nova_unitat = convertir_quantitat(ing.quantitat, ing.unitat)
        print(f"   {ing.recepta.nom[:40]} | {ing.nom_original}: "
              f"{ing.quantitat} {ing.unitat} → {nova_quantitat} {nova_unitat}")
        ing.quantitat = nova_quantitat
        ing.unitat = nova_unitat
        ing.save(update_fields=["quantitat", "unitat"])
        ingredients_actualitzats += 1

print(f"   ✅ {ingredients_actualitzats} ingredients convertits.\n")

# ── 2. Convertir ingredients_no_vinculats (JSON dins Recepta) ────────────────
print("🔄 Convertint ingredients_no_vinculats...")
receptes_actualitzades = 0

for recepta in Recepta.objects.exclude(ingredients_no_vinculats__isnull=True):
    no_vinculats = recepta.ingredients_no_vinculats or []
    canviat = False
    nous = []
    for nv in no_vinculats:
        unitat = nv.get("unitat", "")
        if unitat.lower().strip() in UNITATS_IMPERIALS:
            nova_q, nova_u = convertir_quantitat(nv.get("quantitat", 0), unitat)
            print(f"   {recepta.nom[:40]} | {nv.get('nom', '')}: "
                  f"{nv.get('quantitat')} {unitat} → {nova_q} {nova_u}")
            nv = {**nv, "quantitat": nova_q, "unitat": nova_u}
            canviat = True
        nous.append(nv)
    if canviat:
        recepta.ingredients_no_vinculats = nous
        recepta.save(update_fields=["ingredients_no_vinculats"])
        receptes_actualitzades += 1

print(f"   ✅ {receptes_actualitzades} receptes amb no_vinculats actualitzats.\n")

print("✅ Migració completada.")