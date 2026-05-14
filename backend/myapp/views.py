from rest_framework.viewsets import ViewSet
from rest_framework.response import Response
from rest_framework.decorators import action
from rest_framework import status
from rest_framework.permissions import IsAuthenticated, IsAdminUser, AllowAny
from rest_framework.pagination import LimitOffsetPagination
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
from django.conf import settings
from django.contrib.auth import authenticate
from django.utils import timezone
from .models import Usuari, Categoria, Producte, ProducteInventari, Recepta, Favorit, ItemCompra
from .serializers import CategoriaSerializer, ProducteSerializer, ProducteCreateUpdateSerializer, UsuariSerializer, RegistreSerializer, EditarUsuariSerializer, ProducteInventariSerializer, ProducteInventariEditSerializer, ReceptaResumSerializer, ReceptaSerializer, FavoritSerializer, ItemCompraSerializer, RecomanacioSerializer

NOT_FOUND_ERROR = 'No trobat.'

_MAX_BASE_SCORE      = 0.85
_MAX_CADUCITAT_BONUS = 0.15

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
        public = {'registre', 'login', 'refresh_token', 'google_login'}
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
        if not password and user.provider == 'LOCAL':
            return Response(
                {'error': 'Cal proporcionar la contrasenya per eliminar el compte.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        if password and not user.check_password(password):
            return Response(
                {'error': 'Contrasenya incorrecta.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        user.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


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
    username = base
    counter = 1
    while Usuari.objects.filter(username=username).exists():
        username = f'{base}{counter}'
        counter += 1
    return username


class ProducteViewSet(ViewSet):

    def get_permissions(self):
        if self.action in {'create', 'update', 'destroy'}:
            return [IsAdminUser()]
        return [IsAuthenticated()]

    def list(self, request):
        queryset = Producte.objects.select_related('categoria').all()
        categoria = request.query_params.get('categoria')
        cerca = request.query_params.get('cerca')
        if categoria:
            queryset = queryset.filter(categoria_id=categoria)
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
            return Response({'error': NOT_FOUND_ERROR}, status=status.HTTP_404_NOT_FOUND)
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
            return Response({'error': NOT_FOUND_ERROR}, status=status.HTTP_404_NOT_FOUND)
        serializer = ProducteCreateUpdateSerializer(producte, data=request.data, partial=True)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        producte = serializer.save()
        return Response(ProducteSerializer(producte).data)

    def destroy(self, request, pk=None):
        try:
            producte = Producte.objects.get(pk=pk)
        except Producte.DoesNotExist:
            return Response({'error': NOT_FOUND_ERROR}, status=status.HTTP_404_NOT_FOUND)
        producte.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class CategoriaViewSet(ViewSet):
    permission_classes = [IsAuthenticated]

    def list(self, request):
        return Response(CategoriaSerializer(Categoria.objects.all(), many=True).data)


class ProducteInventariViewSet(ViewSet):
    permission_classes = [IsAuthenticated]

    def list(self, request):
        qs = ProducteInventari.objects.filter(usuari=request.user).select_related('producte__categoria')
        return Response(ProducteInventariSerializer(qs, many=True).data)

    def retrieve(self, request, pk=None):
        try:
            item = ProducteInventari.objects.select_related('producte').get(pk=pk, usuari=request.user)
        except ProducteInventari.DoesNotExist:
            return Response({'error': NOT_FOUND_ERROR}, status=status.HTTP_404_NOT_FOUND)
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
            return Response({'error': NOT_FOUND_ERROR}, status=status.HTTP_404_NOT_FOUND)
        serializer = ProducteInventariEditSerializer(item, data=request.data, partial=False)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        serializer.save()
        return Response(ProducteInventariSerializer(item).data)

    def partial_update(self, request, pk=None):
        try:
            item = ProducteInventari.objects.get(pk=pk, usuari=request.user)
        except ProducteInventari.DoesNotExist:
            return Response({'error': NOT_FOUND_ERROR}, status=status.HTTP_404_NOT_FOUND)
        serializer = ProducteInventariEditSerializer(item, data=request.data, partial=True)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        serializer.save()
        return Response(ProducteInventariSerializer(item).data)

    def destroy(self, request, pk=None):
        try:
            item = ProducteInventari.objects.get(pk=pk, usuari=request.user)
        except ProducteInventari.DoesNotExist:
            return Response({'error': NOT_FOUND_ERROR}, status=status.HTTP_404_NOT_FOUND)
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
            return Response({'error': NOT_FOUND_ERROR}, status=status.HTTP_404_NOT_FOUND)
        serializer = ItemCompraSerializer(item, data=request.data, partial=False)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        serializer.save()
        return Response(serializer.data)

    def partial_update(self, request, pk=None):
        try:
            item = ItemCompra.objects.get(pk=pk, usuari=request.user)
        except ItemCompra.DoesNotExist:
            return Response({'error': NOT_FOUND_ERROR}, status=status.HTTP_404_NOT_FOUND)
        serializer = ItemCompraSerializer(item, data=request.data, partial=True)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        serializer.save()
        return Response(serializer.data)

    def destroy(self, request, pk=None):
        try:
            item = ItemCompra.objects.get(pk=pk, usuari=request.user)
        except ItemCompra.DoesNotExist:
            return Response({'error': NOT_FOUND_ERROR}, status=status.HTTP_404_NOT_FOUND)
        item.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ReceptaViewSet(ViewSet):
    permission_classes = [IsAuthenticated]

    def list(self, request):
        qs = Recepta.objects.prefetch_related('ingredientrecepta_set').all()
        dieta = request.query_params.get('dieta')
        intolerancia = request.query_params.get('intolerancia')
        max_temps = request.query_params.get('max_temps')
        producte = request.query_params.get('producte')

        if dieta:
            qs = qs.filter(dietes__contains=dieta)
        if intolerancia:
            qs = qs.exclude(intolerancias__contains=intolerancia)
        if max_temps:
            try:
                qs = qs.filter(temps_preparacio__lte=int(max_temps))
            except ValueError:
                return Response(
                    {'error': 'max_temps ha de ser un número enter.'},
                    status=status.HTTP_400_BAD_REQUEST
                )
        if producte:
            try:
                qs = qs.filter(
                    ingredientrecepta__producte_id=int(producte)
                ).distinct()
            except ValueError:
                return Response(
                    {'error': 'producte ha de ser un ID enter.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

        paginator = LimitOffsetPagination()
        paginator.default_limit = 20
        paginator.max_limit = 100

        page = paginator.paginate_queryset(qs, request)
        return paginator.get_paginated_response(ReceptaResumSerializer(page, many=True).data)

    def retrieve(self, request, pk=None):
        try:
            recepta = Recepta.objects.prefetch_related('ingredientrecepta_set__producte').get(pk=pk)
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
        try:
            serializer.save(usuari=request.user)
        except Exception:
            return Response(
                {'error': 'Aquesta recepta ja és als favorits.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    def destroy(self, request, pk=None):
        try:
            favorit = Favorit.objects.get(recepta_id=pk, usuari=request.user)
        except Favorit.DoesNotExist:
            return Response({'error': NOT_FOUND_ERROR}, status=status.HTTP_404_NOT_FOUND)
        favorit.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


def _calcular_score(ingredients_recepta, inventari_ids, caducitat_per_producte, dies_urgencia):
    total = len(ingredients_recepta)
    if total == 0:
        return 0.0, 0

    coberts = 0
    max_urgencia = 0.0
    avui = timezone.now().date()

    for ing in ingredients_recepta:
        pid = ing.producte_id
        if pid not in inventari_ids:
            continue

        coberts += 1

        if dies_urgencia > 0:
            data_cad = caducitat_per_producte.get(pid)
            if data_cad is not None:
                dies_restants = (data_cad - avui).days
                if dies_restants <= dies_urgencia:
                    urgencia = max(0, dies_urgencia - dies_restants) / dies_urgencia
                    max_urgencia = max(max_urgencia, urgencia)

    cobertura_base = (coberts / total) * _MAX_BASE_SCORE
    bonus_caducitat = max_urgencia * _MAX_CADUCITAT_BONUS
    score = round(min(cobertura_base + bonus_caducitat, 1.0), 4)

    return score, coberts
 
 
class RecomanacioViewSet(ViewSet):
    permission_classes = [IsAuthenticated]

    def list(self, request):
        productes_param = request.query_params.get('productes')

        inventari_qs = ProducteInventari.objects.filter(
            usuari=request.user
        ).values('producte_id', 'data_caducitat')

        if productes_param:
            try:
                ids_seleccionats = {int(i) for i in productes_param.split(',') if i.strip()}
            except ValueError:
                return Response(
                    {'error': 'productes ha de ser una llista d\'IDs enters separats per comes (ex: 1,2,3).'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            inventari_qs = inventari_qs.filter(producte_id__in=ids_seleccionats)

        caducitat_per_producte = {}
        for item in inventari_qs:
            pid  = item['producte_id']
            data = item['data_caducitat']
            if pid not in caducitat_per_producte:
                caducitat_per_producte[pid] = data
            elif data is not None:
                existent = caducitat_per_producte[pid]
                if existent is None or data < existent:
                    caducitat_per_producte[pid] = data

        inventari_ids = set(caducitat_per_producte.keys())
        dies_urgencia = request.user.dies_avis_caducitat
        avui = timezone.now().date()
        qs = Recepta.objects.prefetch_related('ingredientrecepta_set__producte').all()
        dieta = request.query_params.get('dieta')
        intolerancia = request.query_params.get('intolerancia')
        max_temps = request.query_params.get('max_temps')
        nomes_inv = request.query_params.get('nomes_inventari', 'false').lower() == 'true'
        nomes_urg = request.query_params.get('nomes_urgents',   'false').lower() == 'true'

        if dieta:
            qs = qs.filter(dietes__contains=dieta)
        if intolerancia:
            qs = qs.exclude(intolerancias__contains=intolerancia)
        if max_temps:
            try:
                qs = qs.filter(temps_preparacio__lte=int(max_temps))
            except ValueError:
                return Response(
                    {'error': 'max_temps ha de ser un número enter.'},
                    status=status.HTTP_400_BAD_REQUEST
                )
        resultats = []

        for recepta in qs:
            ings = list(recepta.ingredientrecepta_set.all())
            if not ings:
                continue

            score, coberts = _calcular_score(
                ings, inventari_ids, caducitat_per_producte, dies_urgencia
            )

            if nomes_inv and coberts < len(ings):
                continue

            if nomes_urg:
                te_urgent = any(
                    ing.producte_id in inventari_ids
                    and caducitat_per_producte.get(ing.producte_id) is not None
                    and (caducitat_per_producte[ing.producte_id] - avui).days <= dies_urgencia
                    for ing in ings
                )
                if not te_urgent:
                    continue

            detall_ings = []
            for ing in ings:
                pid      = ing.producte_id
                data_cad = caducitat_per_producte.get(pid)
                dies_cad = (data_cad - avui).days if data_cad else None
                detall_ings.append({
                    'producte_id' : pid,
                    'producte_nom' : ing.producte.nom,
                    'producte_emoji' : ing.producte.emoji,
                    'quantitat' : ing.quantitat,
                    'unitat' : ing.unitat,
                    'al_inventari' : pid in inventari_ids,
                    'dies_caducitat' : dies_cad,
                })

            resultats.append({
                'id_api' : recepta.id_api,
                'nom' : recepta.nom,
                'imatge_url' : recepta.imatge_url,
                'temps_preparacio' : recepta.temps_preparacio,
                'porcions' : recepta.porcions,
                'dietes' : recepta.dietes,
                'intolerancias' : recepta.intolerancias,
                'score' : score,
                'ingredients_coberts' : coberts,
                'total_ingredients' : len(ings),
                'ingredients' : detall_ings,
            })

        resultats.sort(key=lambda r: r['score'], reverse=True)
        paginator = LimitOffsetPagination()
        paginator.default_limit = 20
        paginator.max_limit = 100
        page = paginator.paginate_queryset(resultats, request)

        return paginator.get_paginated_response(RecomanacioSerializer(page, many=True).data)