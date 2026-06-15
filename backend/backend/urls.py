from pathlib import Path

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from django.contrib import admin
from django.http import JsonResponse, HttpResponse, FileResponse, Http404, HttpResponseNotAllowed
from django.views.decorators.http import require_GET
from myapp.views import UsuariViewSet, ProducteViewSet, CategoriaViewSet, ProducteInventariViewSet, ItemCompraViewSet, ReceptaViewSet, FavoritViewSet, RecomanacioViewSet

BASE_DIR = Path(__file__).resolve().parent.parent
OPENAPI_FILE = BASE_DIR / 'openapi.yaml'


@require_GET
def openapi_yaml(request):
    """Serve the static OpenAPI YAML file. Only GET allowed."""
    if not OPENAPI_FILE.exists():
        raise Http404('OpenAPI file not found')
    # Use FileResponse to stream file contents
    return FileResponse(OPENAPI_FILE.open('rb'), content_type='application/yaml')


@require_GET
def documentation_view(request):
    """Serve a minimal Swagger UI page pointing to `/openapi.yaml`.

    Only GET is allowed to avoid unsafe side-effects from other HTTP methods.
    The SRI attributes were removed to avoid blocked resources in some
    deployments; the page loads the Swagger assets from a stable CDN.
    """
    html = '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>TFG API Documentation</title>
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@4/swagger-ui.css" />
  <style>body { margin:0; padding:0; }</style>
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@4/swagger-ui-bundle.js"></script>
  <script src="https://unpkg.com/swagger-ui-dist@4/swagger-ui-standalone-preset.js"></script>
  <script>
    window.onload = function() {
      const ui = SwaggerUIBundle({
        url: '/openapi.yaml',
        dom_id: '#swagger-ui',
        presets: [SwaggerUIBundle.presets.apis, SwaggerUIStandalonePreset],
        layout: 'BaseLayout',
      });
      window.ui = ui;
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
