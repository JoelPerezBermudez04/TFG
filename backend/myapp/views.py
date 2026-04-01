from rest_framework.viewsets import ViewSet
from rest_framework.response import Response

class UsuariViewSet(ViewSet):
    def list(self, request):
        return Response()

    def retrieve(self, request, pk=None):
        return Response()


class ProducteViewSet(ViewSet):
    def list(self, request):
        return Response()

    def retrieve(self, request, pk=None):
        return Response()


class CategoriaViewSet(ViewSet):
    def list(self, request):
        return Response()


class ProducteInventariViewSet(ViewSet):
    def list(self, request):
        return Response()

    def create(self, request):
        return Response()

    def update(self, request, pk=None):
        return Response()

    def destroy(self, request, pk=None):
        return Response()


class ItemCompraViewSet(ViewSet):
    def list(self, request):
        return Response()

    def create(self, request):
        return Response()

    def update(self, request, pk=None):
        return Response()

    def destroy(self, request, pk=None):
        return Response()


class ReceptaViewSet(ViewSet):
    def list(self, request):
        return Response()

    def retrieve(self, request, pk=None):
        return Response()


class FavoritViewSet(ViewSet):
    def list(self, request):
        return Response()

    def create(self, request):
        return Response()

    def destroy(self, request, pk=None):
        return Response()


class RecomanacioViewSet(ViewSet):
    def list(self, request):
        return Response()
