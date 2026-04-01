from rest_framework import serializers
from .models import *

class CategoriaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Categoria
        fields = '__all__'

class ProducteSerializer(serializers.ModelSerializer):
    categoria_nom = serializers.CharField(source='categoria.nom', read_only=True)

    class Meta:
        model = Producte
        fields = '__all__'

class UsuariSerializer(serializers.ModelSerializer):
    class Meta:
        model = Usuari
        fields = ['id', 'username', 'email', 'provider']

class ProducteInventariSerializer(serializers.ModelSerializer):
    producte_nom = serializers.CharField(source='producte.nom', read_only=True)

    class Meta:
        model = ProducteInventari
        fields = '__all__'

class ReceptaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Recepta
        fields = '__all__'

class ReceptaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Recepta
        fields = '__all__'

class FavoritSerializer(serializers.ModelSerializer):
    recepta_nom = serializers.CharField(source='recepta.nom', read_only=True)

    class Meta:
        model = Favorit
        fields = '__all__'

class ItemCompraSerializer(serializers.ModelSerializer):
    producte_nom = serializers.CharField(source='producte.nom', read_only=True)

    class Meta:
        model = ItemCompra
        fields = '__all__'

