from rest_framework.viewsets import ViewSet
from rest_framework.response import Response
from rest_framework.decorators import action
from rest_framework import status
from rest_framework.permissions import IsAuthenticated, IsAdminUser, AllowAny
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError
from django.contrib.auth import authenticate
from django.utils import timezone
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

    def get_permissions(self):
        public = {'registre', 'login', 'refresh_token'}
        if self.action in public:
            return [AllowAny()]
        return [IsAuthenticated()]

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

    @action(detail=False, methods=['post'], url_path='login')
    def login(self, request):
        username = request.data.get('username')
        password = request.data.get('password')
        if not username or not password:
            return Response(
                {'error': 'Cal proporcionar username i password.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        user = authenticate(request, username=username, password=password)
        if user is None:
            return Response(
                {'error': 'Credencials incorrectes.'},
                status=status.HTTP_401_UNAUTHORIZED
            )
        return Response(
            {'usuari': UsuariSerializer(user).data, 'tokens': get_tokens(user)},
            status=status.HTTP_200_OK
        )

    @action(detail=False, methods=['post'], url_path='logout')
    def logout(self, request):
        refresh_token = request.data.get('refresh')
        if not refresh_token:
            return Response(
                {'error': 'Cal proporcionar el refresh token.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        try:
            token = RefreshToken(refresh_token)
            token.blacklist()
        except TokenError:
            return Response(
                {'error': 'Token invàlid o ja caducat.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        return Response({'missatge': 'Sessió tancada correctament.'}, status=status.HTTP_200_OK)

    @action(detail=False, methods=['post'], url_path='refresh-token')
    def refresh_token(self, request):
        refresh_token = request.data.get('refresh')
        if not refresh_token:
            return Response(
                {'error': 'Cal proporcionar el refresh token.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        try:
            token = RefreshToken(refresh_token)
            return Response({
                'access':  str(token.access_token),
                'refresh': str(token),
            }, status=status.HTTP_200_OK)
        except TokenError:
            return Response(
                {'error': 'Token invàlid o ja caducat.'},
                status=status.HTTP_401_UNAUTHORIZED
            )

    @action(detail=False, methods=['get'], url_path='perfil')
    def perfil(self, request):
        return Response(UsuariSerializer(request.user).data)

    @action(detail=False, methods=['patch'], url_path='editar')
    def editar(self, request):
        serializer = EditarUsuariSerializer(
            request.user, data=request.data, partial=True
        )
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        serializer.save()
        return Response(UsuariSerializer(request.user).data)

    @action(detail=False, methods=['post'], url_path='canviar-password')
    def canviar_password(self, request):
        user = request.user
        password_actual = request.data.get('password_actual')
        password_nou    = request.data.get('password_nou')
        if not password_actual or not password_nou:
            return Response(
                {'error': 'Cal proporcionar password_actual i password_nou.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        if not user.check_password(password_actual):
            return Response(
                {'error': 'La contrasenya actual és incorrecta.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        if len(password_nou) < 8:
            return Response(
                {'error': 'La nova contrasenya ha de tenir mínim 8 caràcters.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        user.set_password(password_nou)
        user.save()
        return Response(
            {'missatge': 'Contrasenya canviada.', 'tokens': get_tokens(user)},
            status=status.HTTP_200_OK
        )

    @action(detail=False, methods=['delete'], url_path='eliminar')
    def eliminar(self, request):
        user = request.user
        password = request.data.get('password')
        if password and not user.check_password(password):
            return Response(
                {'error': 'Contrasenya incorrecta.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        user.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ProducteViewSet(ViewSet):

    def get_permissions(self):
        # Crear, editar i eliminar: només admins. Llegir: qualsevol autenticat.
        if self.action in {'create', 'update', 'destroy'}:
            return [IsAdminUser()]
        return [IsAuthenticated()]

    def list(self, request):
        queryset = Producte.objects.select_related('categoria').all()
        categoria = request.query_params.get('categoria')
        cerca = request.query_params.get('cerca')
        if categoria:
            queryset = queryset.filter(categoria__nom__iexact=categoria)
        if cerca:
            from thefuzz import process
            productes = list(queryset)
            opcions = {
                p.pk: [p.nom, (p.alias_api or {}).get('nom_en', '')]
                for p in productes
            }
            cerca_lower = cerca.lower()
            pks_coincidents = [
                pk for pk, noms in opcions.items()
                if any(process.extractOne(cerca_lower, [n.lower()], score_cutoff=70)
                       for n in noms if n)
            ]
            queryset = [p for p in productes if p.pk in pks_coincidents]
            return Response(ProducteSerializer(queryset, many=True).data)
        return Response(ProducteSerializer(queryset, many=True).data)

    def retrieve(self, request, pk=None):
        try:
            producte = Producte.objects.select_related('categoria').get(pk=pk)
        except Producte.DoesNotExist:
            return Response({'error': 'No trobat.'}, status=status.HTTP_404_NOT_FOUND)
        return Response(ProducteSerializer(producte).data)

    def create(self, request):
        serializer = ProducteCreateUpdateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        producte = serializer.save()
        return Response(ProducteSerializer(producte).data, status=status.HTTP_201_CREATED)

    def update(self, request, pk=None):
        try:
            producte = Producte.objects.get(pk=pk)
        except Producte.DoesNotExist:
            return Response({'error': 'No trobat.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = ProducteCreateUpdateSerializer(producte, data=request.data, partial=True)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        producte = serializer.save()
        return Response(ProducteSerializer(producte).data)

    def destroy(self, request, pk=None):
        try:
            producte = Producte.objects.get(pk=pk)
        except Producte.DoesNotExist:
            return Response({'error': 'No trobat.'}, status=status.HTTP_404_NOT_FOUND)
        producte.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class CategoriaViewSet(ViewSet):
    permission_classes = [IsAuthenticated]

    def list(self, request):
        return Response(CategoriaSerializer(Categoria.objects.all(), many=True).data)


class ProducteInventariViewSet(ViewSet):
    permission_classes = [IsAuthenticated]

    def list(self, request):
        qs = ProducteInventari.objects.filter(usuari=request.user).select_related('producte')
        return Response(ProducteInventariSerializer(qs, many=True).data)

    def retrieve(self, request, pk=None):
        try:
            item = ProducteInventari.objects.select_related('producte').get(pk=pk, usuari=request.user)
        except ProducteInventari.DoesNotExist:
            return Response({'error': 'No trobat.'}, status=status.HTTP_404_NOT_FOUND)
        return Response(ProducteInventariSerializer(item).data)

    def create(self, request):
        serializer = ProducteInventariSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        serializer.save(usuari=request.user)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    def update(self, request, pk=None):
        try:
            item = ProducteInventari.objects.get(pk=pk, usuari=request.user)
        except ProducteInventari.DoesNotExist:
            return Response({'error': 'No trobat.'}, status=status.HTTP_404_NOT_FOUND)
        # Usem el serializer restringit
        serializer = ProducteInventariEditSerializer(item, data=request.data, partial=True)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        serializer.save()
        return Response(ProducteInventariSerializer(item).data)

    def destroy(self, request, pk=None):
        try:
            item = ProducteInventari.objects.get(pk=pk, usuari=request.user)
        except ProducteInventari.DoesNotExist:
            return Response({'error': 'No trobat.'}, status=status.HTTP_404_NOT_FOUND)
        item.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    
    @action(detail=False, methods=['get'], url_path='caducitats')
    def caducitats(self, request):
        dies = request.user.dies_avis_caducitat
        avui = timezone.now().date()
        if dies == 0:
            qs = (
                ProducteInventari.objects
                .filter(usuari=request.user, data_caducitat__isnull=False, data_caducitat__lt=avui)
                .select_related('producte')
                .order_by('data_caducitat')
            )
        else:
            limit = avui + timezone.timedelta(days=dies)
            qs = (
                ProducteInventari.objects
                .filter(usuari=request.user, data_caducitat__isnull=False, data_caducitat__lte=limit)
                .select_related('producte')
                .order_by('data_caducitat')
            )
        return Response(ProducteInventariSerializer(qs, many=True).data)


class ItemCompraViewSet(ViewSet):
    permission_classes = [IsAuthenticated]

    def list(self, request):
        qs = ItemCompra.objects.filter(usuari=request.user).select_related('producte')
        return Response(ItemCompraSerializer(qs, many=True).data)

    def create(self, request):
        serializer = ItemCompraSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        serializer.save(usuari=request.user)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    def update(self, request, pk=None):
        try:
            item = ItemCompra.objects.get(pk=pk, usuari=request.user)
        except ItemCompra.DoesNotExist:
            return Response({'error': 'No trobat.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = ItemCompraSerializer(item, data=request.data, partial=True)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        serializer.save()
        return Response(serializer.data)

    def destroy(self, request, pk=None):
        try:
            item = ItemCompra.objects.get(pk=pk, usuari=request.user)
        except ItemCompra.DoesNotExist:
            return Response({'error': 'No trobat.'}, status=status.HTTP_404_NOT_FOUND)
        item.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ReceptaViewSet(ViewSet):
    permission_classes = [IsAuthenticated]

    def list(self, request):
        return Response(ReceptaSerializer(Recepta.objects.all(), many=True).data)

    def retrieve(self, request, pk=None):
        try:
            recepta = Recepta.objects.get(pk=pk)
        except Recepta.DoesNotExist:
            return Response({'error': 'No trobada.'}, status=status.HTTP_404_NOT_FOUND)
        return Response(ReceptaSerializer(recepta).data)


class FavoritViewSet(ViewSet):
    permission_classes = [IsAuthenticated]

    def list(self, request):
        qs = Favorit.objects.filter(usuari=request.user).select_related('recepta')
        return Response(FavoritSerializer(qs, many=True).data)

    def create(self, request):
        serializer = FavoritSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        serializer.save(usuari=request.user)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    def destroy(self, request, pk=None):
        try:
            favorit = Favorit.objects.get(pk=pk, usuari=request.user)
        except Favorit.DoesNotExist:
            return Response({'error': 'No trobat.'}, status=status.HTTP_404_NOT_FOUND)
        favorit.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class RecomanacioViewSet(ViewSet):
    permission_classes = [IsAuthenticated]

    def list(self, request):
        return Response()