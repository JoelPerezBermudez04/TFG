from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
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


class ProducteCreateUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Producte
        fields = ['nom', 'categoria', 'emoji', 'imatge_url', 'alias_api']


class UsuariSerializer(serializers.ModelSerializer):
    class Meta:
        model = Usuari
        fields = ['id', 'username', 'email', 'provider', 'dies_avis_caducitat']


class RegistreSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, validators=[validate_password])

    class Meta:
        model = Usuari
        fields = ['username', 'email', 'password']

    def create(self, validated_data):
        return Usuari.objects.create_user(
            username=validated_data['username'],
            email=validated_data.get('email', ''),
            password=validated_data['password'],
        )


class EditarUsuariSerializer(serializers.ModelSerializer):
    class Meta:
        model = Usuari
        fields = ['username', 'email', 'dies_avis_caducitat']

    def validate_dies_avis_caducitat(self, value):
        if value < 0:
            raise serializers.ValidationError('El valor no pot ser negatiu.')
        return value

    def validate_username(self, value):
        user = self.instance
        if Usuari.objects.exclude(pk=user.pk).filter(username=value).exists():
            raise serializers.ValidationError('Aquest username ja està en ús.')
        return value

    def validate_email(self, value):
        user = self.instance
        if Usuari.objects.exclude(pk=user.pk).filter(email=value).exists():
            raise serializers.ValidationError('Aquest email ja està en ús.')
        return value


class ProducteInventariSerializer(serializers.ModelSerializer):
    producte_nom = serializers.CharField(source='producte.nom', read_only=True)
    producte_emoji = serializers.CharField(source='producte.emoji', read_only=True)
    producte_imatge_url = serializers.URLField(source='producte.imatge_url', read_only=True)
    caducat = serializers.SerializerMethodField()
 
    class Meta:
        model = ProducteInventari
        fields = '__all__'
        read_only_fields = ['usuari', 'data_afegit']
 
    def get_caducat(self, obj):
        if obj.data_caducitat is None:
            return False
        from django.utils import timezone
        return obj.data_caducitat < timezone.now().date()


class ProducteInventariEditSerializer(serializers.ModelSerializer):

    class Meta:
        model = ProducteInventari
        fields = ['quantitat', 'unitat', 'data_caducitat']


class ReceptaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Recepta
        fields = '__all__'


class FavoritSerializer(serializers.ModelSerializer):
    recepta_nom = serializers.CharField(source='recepta.nom', read_only=True)

    class Meta:
        model = Favorit
        fields = '__all__'
        read_only_fields = ['usuari', 'data_guardat']


class ItemCompraSerializer(serializers.ModelSerializer):
    producte_nom = serializers.CharField(source='producte.nom', read_only=True)

    class Meta:
        model = ItemCompra
        fields = '__all__'
        read_only_fields = ['usuari', 'data_afegit']