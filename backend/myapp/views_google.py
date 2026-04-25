from rest_framework.viewsets import ViewSet
from rest_framework.response import Response
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny
from rest_framework import status
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
from django.conf import settings
from .models import Usuari
from .serializers import UsuariSerializer
from rest_framework_simplejwt.tokens import RefreshToken


def get_tokens(user):
    refresh = RefreshToken.for_user(user)
    return {
        'refresh': str(refresh),
        'access': str(refresh.access_token),
    }


class GoogleAuthViewSet(ViewSet):

    def get_permissions(self):
        return [AllowAny()]

    @action(detail=False, methods=['post'], url_path='google')
    def google_login(self, request):
        id_token_str = request.data.get('id_token')

        if not id_token_str:
            return Response(
                {'error': 'Cal proporcionar el id_token de Google.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            idinfo = id_token.verify_oauth2_token(
                id_token_str,
                google_requests.Request(),
                settings.GOOGLE_WEB_CLIENT_ID,
            )
        except ValueError:
            return Response(
                {'error': 'Token de Google invàlid o caducat.'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        google_id = idinfo['sub']
        email = idinfo.get('email', '')
        username_base = email.split('@')[0] if email else f'user_{google_id[:8]}'

        user, created = Usuari.objects.get_or_create(
            email=email,
            defaults={
                'username': _unique_username(username_base),
                'provider': 'GOOGLE',
            }
        )

        if not created and user.provider == 'LOCAL':
            return Response(
                {'error': 'Aquest email ja està registrat amb contrasenya. Inicia sessió normalment.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        return Response(
            {'usuari': UsuariSerializer(user).data, 'tokens': get_tokens(user)},
            status=status.HTTP_200_OK
        )


def _unique_username(base):
    """Genera un username únic afegint un número si cal."""
    username = base
    counter = 1
    while Usuari.objects.filter(username=username).exists():
        username = f'{base}{counter}'
        counter += 1
    return username