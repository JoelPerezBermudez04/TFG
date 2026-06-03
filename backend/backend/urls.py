from pathlib import Path

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from django.contrib import admin
from django.http import JsonResponse, HttpResponse, FileResponse, Http404
from myapp.views import UsuariViewSet, ProducteViewSet, CategoriaViewSet, ProducteInventariViewSet, ItemCompraViewSet, ReceptaViewSet, FavoritViewSet, RecomanacioViewSet

BASE_DIR = Path(__file__).resolve().parent.parent
OPENAPI_FILE = BASE_DIR / 'openapi.yaml'


def openapi_yaml(request):
    if not OPENAPI_FILE.exists():
        raise Http404('OpenAPI file not found')
    return FileResponse(open(OPENAPI_FILE, 'rb'), content_type='application/yaml')


def documentation_view(request):
    html = '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>TFG API Documentation</title>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/4.33.0/swagger-ui.css" integrity="sha512-o7u4n+0V7qkl7FkaP7a4j6BdKqXqK1fP1mR1/D/dcQLuRDi1BjE3EbHzOMoyxgkz3kv6xQdysmsLHo7KYAAn6Q==" crossorigin="anonymous" referrerpolicy="no-referrer" />
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/4.33.0/swagger-ui-bundle.min.js" integrity="sha512-FG8slUNaQ+Tt+WhjP0ve6+gieP+6g6OxD2RzIQ2j9r+n/A0Dga5op6UQhfl8K5BTmvdhVJyNHgGkEYqXzAo1RQ==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
  <script>
    window.onload = function() {
      SwaggerUIBundle({
        url: '/openapi.yaml',
        dom_id: '#swagger-ui',
        presets: [SwaggerUIBundle.presets.apis],
        layout: 'BaseLayout',
      });
    };
  </script>
</body>
</html>'''
    return HttpResponse(html)

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
    path('health/', lambda request: JsonResponse({'status': 'ok'})),
    path('docu-api/', documentation_view),
    path('openapi.yaml', openapi_yaml),
    path('', include(router.urls)),
    path('admin/', admin.site.urls),
]
