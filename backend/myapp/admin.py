from django.contrib import admin
from .models import *

admin.site.register(Usuari)
admin.site.register(Producte)
admin.site.register(Categoria)
admin.site.register(ProducteInventari)
admin.site.register(Recepta)
admin.site.register(IngredientRecepta)
admin.site.register(Favorit)
admin.site.register(ItemCompra)