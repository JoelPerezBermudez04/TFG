from rest_framework.viewsets import ViewSet
from rest_framework.response import Response
from rest_framework.decorators import action
from rest_framework import status
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError
from django.contrib.auth import authenticate
from .models import *
from .serializers import *


def get_tokens(user):
    refresh = RefreshToken.for_user(user)
    return {
        'refresh': str(refresh),
        'access':  str(refresh.access_token),
    }

class UsuariViewSet(ViewSet):
    def list(self, request):
        return Response()

    def retrieve(self, request, pk=None):
        return Response()

    @action(detail=False, methods=['post'], url_path='registre')
    def registre(self, request):
        serializer = RegistreSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        user = serializer.save()
        return Response(
            {'usuari': UsuariSerializer(user).data, 'tokens': get_tokens(user)},
            status=status.HTTP_201_CREATED
        )


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
