from django.urls import path, include
from rest_framework.routers import DefaultRouter
from django.contrib import admin
from myapp.views import *

router = DefaultRouter()

router.register(r'usuaris', UsuariViewSet, basename='usuari')
router.register(r'productes', ProducteViewSet, basename='producte')
router.register(r'categories', CategoriaViewSet, basename='categoria')
router.register(r'inventari', ProducteInventariViewSet, basename='inventari')
router.register(r'compra', ItemCompraViewSet, basename='compra')
router.register(r'receptes', ReceptaViewSet, basename='recepta')
router.register(r'favorits', FavoritViewSet, basename='favorit')
router.register(r'recomanacions', RecomanacioViewSet, basename='recomanacio')

urlpatterns = [
    path('', include(router.urls)),
    path('admin/', admin.site.urls),
]
