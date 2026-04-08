from django.contrib.auth.models import AbstractUser
from django.db import models


class Usuari(AbstractUser):
    PROVIDER_CHOICES = [
        ('LOCAL', 'Local'),
        ('GOOGLE', 'Google'),
    ]
    provider = models.CharField(max_length=10, choices=PROVIDER_CHOICES, default='LOCAL')


class Categoria(models.Model):
    nom = models.CharField(max_length=100, unique=True)
    emoji = models.CharField(max_length=10, default='🛒')

    def __str__(self):
        return self.nom


class Producte(models.Model):
    nom = models.CharField(max_length=100, unique=True)
    categoria = models.ForeignKey(Categoria, on_delete=models.CASCADE)
    emoji = models.CharField(max_length=10, default='🛒')#fallback
    imatge_url = models.URLField(blank=True, null=True)

    # id Spoonacular, nom imatge i nom en anglès per fer matching amb receptes
    alias_api = models.JSONField(blank=True, null=True)

    def __str__(self):
        return f'{self.emoji} {self.nom}'


class ProducteInventari(models.Model):
    UNITATS = [
        ('g', 'grams'),
        ('kg', 'kilograms'),
        ('ml', 'mililitres'),
        ('L', 'litres'),
        ('unitat', 'unitat'),
        ('unitats', 'unitats'),
    ]
    usuari = models.ForeignKey(Usuari, on_delete=models.CASCADE)
    producte = models.ForeignKey(Producte, on_delete=models.CASCADE)
    quantitat = models.FloatField()
    unitat = models.CharField(max_length=10, choices=UNITATS)
    data_caducitat = models.DateField(null=True, blank=True)
    data_afegit = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('usuari', 'producte')


class Recepta(models.Model):
    id_api = models.CharField(max_length=100, primary_key=True)
    nom = models.CharField(max_length=255)
    descripcio = models.TextField(blank=True)
    imatge_url = models.URLField()
    temps_preparacio = models.IntegerField()

    def __str__(self):
        return self.nom


class IngredientRecepta(models.Model):
    recepta = models.ForeignKey(Recepta, on_delete=models.CASCADE)
    producte = models.ForeignKey(Producte, on_delete=models.CASCADE)
    quantitat = models.FloatField()
    unitat = models.CharField(max_length=10)

    class Meta:
        unique_together = ('recepta', 'producte')


class Favorit(models.Model):
    usuari = models.ForeignKey(Usuari, on_delete=models.CASCADE)
    recepta = models.ForeignKey(Recepta, on_delete=models.CASCADE)
    data_guardat = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('usuari', 'recepta')


class ItemCompra(models.Model):
    UNITATS = [
        ('g', 'grams'),
        ('kg', 'kilograms'),
        ('ml', 'mililitres'),
        ('L', 'litres'),
        ('unitat', 'unitat'),
        ('unitats', 'unitats'),
    ]
    usuari = models.ForeignKey(Usuari, on_delete=models.CASCADE)
    producte = models.ForeignKey(Producte, on_delete=models.CASCADE)
    quantitat = models.FloatField()
    unitat = models.CharField(max_length=10, choices=UNITATS)
    comprat = models.BooleanField(default=False)
    data_afegit = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('usuari', 'producte')