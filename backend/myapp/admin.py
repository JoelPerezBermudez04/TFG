from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import (
    Usuari, Categoria, Producte, ProducteInventari,
    Recepta, IngredientRecepta, Favorit, ItemCompra
)

class ProducteCategoriaInline(admin.TabularInline):
    """Productes dins d'una categoria."""
    model = Producte
    fields = ['nom', 'emoji']
    extra = 0
    show_change_link = True


class IngredientReceptaInline(admin.TabularInline):
    """Ingredients dins d'una recepta."""
    model = IngredientRecepta
    fields = ['producte', 'quantitat', 'unitat']
    extra = 0
    autocomplete_fields = ['producte']


class ProducteInventariInline(admin.TabularInline):
    """Inventari d'un usuari."""
    model = ProducteInventari
    fields = ['producte', 'quantitat', 'unitat', 'data_caducitat']
    extra = 0
    autocomplete_fields = ['producte']


class FavoritInline(admin.TabularInline):
    """Receptes favorites d'un usuari."""
    model = Favorit
    fields = ['recepta', 'data_guardat']
    readonly_fields = ['data_guardat']
    extra = 0


class ItemCompraInline(admin.TabularInline):
    """Llista de la compra d'un usuari."""
    model = ItemCompra
    fields = ['producte', 'quantitat', 'unitat', 'comprat']
    extra = 0
    autocomplete_fields = ['producte']


@admin.register(Usuari)
class UsuariAdmin(UserAdmin):
    list_display = ['username', 'email', 'provider', 'is_staff', 'is_active']
    list_filter = ['provider', 'is_staff', 'is_active']
    search_fields = ['username', 'email']
    fieldsets = UserAdmin.fieldsets + (
        ('Informació addicional', {'fields': ('provider',)}),
    )
    inlines = [ProducteInventariInline, FavoritInline, ItemCompraInline]


@admin.register(Categoria)
class CategoriaAdmin(admin.ModelAdmin):
    list_display = ['nom', 'emoji', 'num_productes']
    search_fields = ['nom']
    inlines = [ProducteCategoriaInline]

    @admin.display(description='Núm. productes')
    def num_productes(self, obj):
        return obj.producte_set.count()


@admin.register(Producte)
class ProducteAdmin(admin.ModelAdmin):
    list_display = ['nom', 'emoji', 'categoria']
    list_filter = ['categoria']
    search_fields = ['nom', 'alias_api__nom_en']


@admin.register(Recepta)
class ReceptaAdmin(admin.ModelAdmin):
    list_display = ['nom', 'temps_preparacio']
    search_fields = ['nom']
    inlines = [IngredientReceptaInline]


@admin.register(ProducteInventari)
class ProducteInventariAdmin(admin.ModelAdmin):
    list_display = ['producte', 'usuari', 'quantitat', 'unitat', 'data_caducitat']
    list_filter = ['unitat']
    search_fields = ['producte__nom', 'usuari__username']


@admin.register(Favorit)
class FavoritAdmin(admin.ModelAdmin):
    list_display = ['usuari', 'recepta', 'data_guardat']
    search_fields = ['usuari__username', 'recepta__nom']


@admin.register(ItemCompra)
class ItemCompraAdmin(admin.ModelAdmin):
    list_display = ['producte', 'usuari', 'quantitat', 'unitat', 'comprat']
    list_filter = ['comprat', 'unitat']
    search_fields = ['producte__nom', 'usuari__username']