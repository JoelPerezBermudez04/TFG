from django.test import TestCase
from rest_framework.test import APITestCase, APIClient
from rest_framework import status
from django.urls import reverse
from django.utils import timezone
from datetime import date, timedelta
from .models import Usuari, Categoria, Producte, ProducteInventari, ItemCompra, Recepta, Favorit, IngredientRecepta

def crear_usuari(username='testuser', password='Passw0rd_Test!', is_staff=False): #NOSONAR
    user = Usuari.objects.create_user(username=username, email=f'{username}@test.com', password=password)
    user.is_staff = is_staff
    user.save()
    return user

def obtenir_tokens(client, username, password):
    resp = client.post('/usuaris/login/', {'username': username, 'password': password}, format='json')
    return resp.data.get('tokens', {})

def auth_client(user, password='Passw0rd_Test!'): #NOSONAR
    client = APIClient()
    tokens = obtenir_tokens(client, user.username, password)
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
    return client

def crear_recepta(id_api, nom, temps=30, porcions=2, dietes=None):
    return Recepta.objects.create(
        id_api=id_api,
        nom=nom,
        temps_preparacio=temps,
        porcions=porcions,
        dietes=dietes or [],
    )


class RegistreTests(APITestCase):
    def test_registre_correcte(self):
        resp = self.client.post('/usuaris/registre/', {
            'username': 'nou_user',
            'email': 'nou@test.com',
            'password': 'Passw0rd_Test!', #NOSONAR
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        self.assertIn('tokens', resp.data)
        self.assertIn('usuari', resp.data)

    def test_registre_sense_password(self):
        resp = self.client.post('/usuaris/registre/', {
            'username': 'nou_user',
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_registre_username_duplicat(self):
        crear_usuari('duplicat')
        resp = self.client.post('/usuaris/registre/', {
            'username': 'duplicat',
            'email': 'altre@test.com',
            'password': 'Passw0rd_Test!', #NOSONAR
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)


class LoginTests(APITestCase):
    def setUp(self):
        self.user = crear_usuari()

    def test_login_correcte(self):
        resp = self.client.post('/usuaris/login/', {
            'username': 'testuser',
            'password': 'Passw0rd_Test!', #NOSONAR
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('access', resp.data['tokens'])
        self.assertIn('refresh', resp.data['tokens'])

    def test_login_credencials_incorrectes(self):
        resp = self.client.post('/usuaris/login/', {
            'username': 'testuser',
            'password': 'wrong', #NOSONAR
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_login_sense_camps(self):
        resp = self.client.post('/usuaris/login/', {}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)


class LogoutTests(APITestCase):
    def setUp(self):
        self.user = crear_usuari()
        self.tokens = obtenir_tokens(self.client, 'testuser', 'Passw0rd_Test!')

    def test_logout_correcte(self):
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {self.tokens['access']}")
        resp = self.client.post('/usuaris/logout/', {'refresh': self.tokens['refresh']}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

    def test_logout_token_invalid(self):
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {self.tokens['access']}")
        resp = self.client.post('/usuaris/logout/', {'refresh': 'token_invalid'}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_logout_sense_token(self):
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {self.tokens['access']}")
        resp = self.client.post('/usuaris/logout/', {}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)


class RefreshTokenTests(APITestCase):
    def setUp(self):
        self.user = crear_usuari()
        self.tokens = obtenir_tokens(self.client, 'testuser', 'Passw0rd_Test!')

    def test_refresh_correcte(self):
        resp = self.client.post('/usuaris/refresh-token/', {'refresh': self.tokens['refresh']}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('access', resp.data)

    def test_refresh_token_invalid(self):
        resp = self.client.post('/usuaris/refresh-token/', {'refresh': 'invalid'}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)


class PerfilTests(APITestCase):
    def setUp(self):
        self.user = crear_usuari()
        self.client = auth_client(self.user)

    def test_obtenir_perfil(self):
        resp = self.client.get('/usuaris/perfil/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.data['username'], 'testuser')

    def test_perfil_sense_auth(self):
        resp = APIClient().get('/usuaris/perfil/')
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_editar_perfil(self):
        resp = self.client.patch('/usuaris/editar/', {'dies_avis_caducitat': 3}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.data['dies_avis_caducitat'], 3)

    def test_editar_dies_negatiu(self):
        resp = self.client.patch('/usuaris/editar/', {'dies_avis_caducitat': -1}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_editar_username_duplicat(self):
        crear_usuari('altreuser')
        resp = self.client.patch('/usuaris/editar/', {'username': 'altreuser'}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)


class CanviarPasswordTests(APITestCase):
    def setUp(self):
        self.user = crear_usuari()
        self.client = auth_client(self.user)

    def test_canviar_password_correcte(self):
        resp = self.client.post('/usuaris/canviar-password/', {
            'password_actual': 'Passw0rd_Test!', #NOSONAR
            'password_nou': 'novapassword456',
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('tokens', resp.data)

    def test_canviar_password_actual_incorrecte(self):
        resp = self.client.post('/usuaris/canviar-password/', {
            'password_actual': 'wrong', #NOSONAR
            'password_nou': 'novapassword456',
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_canviar_password_nova_massa_curta(self):
        resp = self.client.post('/usuaris/canviar-password/', {
            'password_actual': 'Passw0rd_Test!', #NOSONAR
            'password_nou': '123', #NOSONAR
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_canviar_password_sense_cap_camp(self):
        resp = self.client.post('/usuaris/canviar-password/', {}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_canviar_password_sense_password_nou(self):
        resp = self.client.post('/usuaris/canviar-password/', {
            'password_actual': 'Passw0rd_Test!', #NOSONAR
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_canviar_password_sense_password_actual(self):
        resp = self.client.post('/usuaris/canviar-password/', {
            'password_nou': 'novapassword456',
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)


class EliminarUsuariTests(APITestCase):
    def test_eliminar_usuari(self):
        user = crear_usuari('todelete')
        client = auth_client(user)
        resp = client.delete('/usuaris/eliminar/', {'password': 'Passw0rd_Test!'}, format='json') #NOSONAR
        self.assertEqual(resp.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Usuari.objects.filter(username='todelete').exists())

    def test_eliminar_usuari_password_incorrecte(self):
        user = crear_usuari('todelete2')
        client = auth_client(user)
        resp = client.delete('/usuaris/eliminar/', {'password': 'wrong'}, format='json') #NOSONAR
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_eliminar_sense_autenticacio(self):
        resp = APIClient().delete('/usuaris/eliminar/', {'password': 'qualsevol'}, format='json') #NOSONAR
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_eliminar_usuari_google_sense_password(self):
        user = Usuari.objects.create_user(
            username='google_user', email='google@test.com', password=None
        )
        user.provider = 'GOOGLE'
        user.save()
        from rest_framework_simplejwt.tokens import RefreshToken
        refresh = RefreshToken.for_user(user)
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {str(refresh.access_token)}")
        resp = client.delete('/usuaris/eliminar/', {}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Usuari.objects.filter(username='google_user').exists())


class ProducteTests(APITestCase):
    def setUp(self):
        self.categoria = Categoria.objects.create(nom='Fruites', emoji='🍎')
        self.admin = crear_usuari('admin', is_staff=True)
        self.user = crear_usuari('normal')
        self.admin_client = auth_client(self.admin)
        self.user_client = auth_client(self.user)

    def test_llistar_productes_autenticat(self):
        resp = self.user_client.get('/productes/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

    def test_llistar_productes_no_autenticat(self):
        resp = APIClient().get('/productes/')
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_crear_producte_admin(self):
        resp = self.admin_client.post('/productes/', {
            'nom': 'Poma',
            'categoria': self.categoria.pk,
            'emoji': '🍎',
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)

    def test_crear_producte_user_normal_rebutjat(self):
        resp = self.user_client.post('/productes/', {
            'nom': 'Pera',
            'categoria': self.categoria.pk,
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

    def test_eliminar_producte_admin(self):
        producte = Producte.objects.create(nom='Prova', categoria=self.categoria)
        resp = self.admin_client.delete(f'/productes/{producte.pk}/')
        self.assertEqual(resp.status_code, status.HTTP_204_NO_CONTENT)

    def test_eliminar_producte_user_normal_rebutjat(self):
        producte = Producte.objects.create(nom='Prova2', categoria=self.categoria)
        resp = self.user_client.delete(f'/productes/{producte.pk}/')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

    def test_cerca_producte(self):
        Producte.objects.create(nom='Taronja', categoria=self.categoria, alias_api={'nom_en': 'orange'})
        resp = self.user_client.get('/productes/?cerca=taronja')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

    def test_retrieve_producte_existent(self):
        producte = Producte.objects.create(nom='Llentilles', categoria=self.categoria)
        resp = self.user_client.get(f'/productes/{producte.pk}/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.data['nom'], 'Llentilles')

    def test_retrieve_producte_inexistent(self):
        resp = self.user_client.get('/productes/99999/')
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)

    def test_retrieve_producte_no_autenticat(self):
        producte = Producte.objects.create(nom='Maduixa', categoria=self.categoria)
        resp = APIClient().get(f'/productes/{producte.pk}/')
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_filtrar_per_categoria(self):
        Producte.objects.create(nom='Cigrons', categoria=self.categoria)
        altra_cat = Categoria.objects.create(nom='Cereals', emoji='🌾')
        Producte.objects.create(nom='Arròs', categoria=altra_cat)
        resp = self.user_client.get(f'/productes/?categoria={self.categoria.pk}')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        noms = [p['nom'] for p in resp.data]
        self.assertNotIn('Arròs', noms)

    def test_update_producte_admin(self):
        producte = Producte.objects.create(nom='Arròs blanc', categoria=self.categoria)
        resp = self.admin_client.put(f'/productes/{producte.pk}/', {'nom': 'Arròs integral', 'categoria': self.categoria.pk}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.data['nom'], 'Arròs integral')

    def test_update_producte_user_normal_rebutjat(self):
        producte = Producte.objects.create(nom='Kiwi', categoria=self.categoria)
        resp = self.user_client.put(f'/productes/{producte.pk}/', {'nom': 'Kiwi verd', 'categoria': self.categoria.pk}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

    def test_update_producte_inexistent_admin(self):
        resp = self.admin_client.put('/productes/99999/', {'nom': 'Inexistent', 'categoria': 1}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)


class CategoriaTests(APITestCase):
    def setUp(self):
        self.user = crear_usuari()
        self.client = auth_client(self.user)
        Categoria.objects.create(nom='Verdures', emoji='🥦')

    def test_llistar_categories(self):
        resp = self.client.get('/categories/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(len(resp.data), 1)

    def test_categories_no_autenticat(self):
        resp = APIClient().get('/categories/')
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)


class InventariTests(APITestCase):

    def setUp(self):
        self.categoria = Categoria.objects.create(nom='Làctics', emoji='🥛')
        self.producte = Producte.objects.create(nom='Llet', categoria=self.categoria)
        self.user = crear_usuari('user1')
        self.altre_user = crear_usuari('user2')
        self.client = auth_client(self.user)
        self.altre_client = auth_client(self.altre_user)

    def test_crear_item_inventari(self):
        resp = self.client.post('/inventari/', {
            'producte': self.producte.pk,
            'quantitat': 2.0,
            'unitat': 'L',
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)

    def test_llistar_inventari_propi(self):
        ProducteInventari.objects.create(
            usuari=self.user, producte=self.producte, quantitat=1, unitat='L'
        )
        resp = self.client.get('/inventari/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(len(resp.data), 1)

    def test_aislament_entre_usuaris(self):
        ProducteInventari.objects.create(
            usuari=self.user, producte=self.producte, quantitat=1, unitat='L'
        )
        resp = self.altre_client.get('/inventari/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(len(resp.data), 0)

    def test_editar_item_inventari_patch(self):
        item = ProducteInventari.objects.create(
            usuari=self.user, producte=self.producte, quantitat=1, unitat='L'
        )
        resp = self.client.patch(f'/inventari/{item.pk}/', {'quantitat': 3.0}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(float(resp.data['quantitat']), 3.0)

    def test_editar_item_inventari_put(self):
        item = ProducteInventari.objects.create(
            usuari=self.user, producte=self.producte, quantitat=1, unitat='L'
        )
        resp = self.client.put(f'/inventari/{item.pk}/', {'quantitat': 5.0, 'unitat': 'kg'}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(float(resp.data['quantitat']), 5.0)

    def test_editar_item_altre_usuari_rebutjat(self):
        item = ProducteInventari.objects.create(
            usuari=self.user, producte=self.producte, quantitat=1, unitat='L'
        )
        resp = self.altre_client.patch(f'/inventari/{item.pk}/', {'quantitat': 99}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)

    def test_eliminar_item_inventari(self):
        item = ProducteInventari.objects.create(
            usuari=self.user, producte=self.producte, quantitat=1, unitat='L'
        )
        resp = self.client.delete(f'/inventari/{item.pk}/')
        self.assertEqual(resp.status_code, status.HTTP_204_NO_CONTENT)

    def test_camp_caducat_true(self):
        item = ProducteInventari.objects.create(
            usuari=self.user, producte=self.producte, quantitat=1, unitat='L',
            data_caducitat=date.today() - timedelta(days=1)
        )
        resp = self.client.get(f'/inventari/{item.pk}/')
        self.assertTrue(resp.data['caducat'])

    def test_camp_caducat_false(self):
        item = ProducteInventari.objects.create(
            usuari=self.user, producte=self.producte, quantitat=1, unitat='L',
            data_caducitat=date.today() + timedelta(days=5)
        )
        resp = self.client.get(f'/inventari/{item.pk}/')
        self.assertFalse(resp.data['caducat'])

    def test_retrieve_item_inventari_inexistent(self):
        resp = self.client.get('/inventari/99999/')
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)

    def test_retrieve_item_inventari_altre_usuari_rebutjat(self):
        item = ProducteInventari.objects.create(
            usuari=self.altre_user, producte=self.producte, quantitat=1, unitat='unitat'
        )
        resp = self.client.get(f'/inventari/{item.pk}/')
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)


class CaducitatsTests(APITestCase):

    def setUp(self):
        self.categoria = Categoria.objects.create(nom='Carns', emoji='🥩')
        self.user = crear_usuari('caducat_user')
        self.client = auth_client(self.user)
        avui = date.today()

        self.p1 = Producte.objects.create(nom='Pollastre', categoria=self.categoria)
        self.p2 = Producte.objects.create(nom='Vedella', categoria=self.categoria)
        self.p3 = Producte.objects.create(nom='Porc', categoria=self.categoria)

        ProducteInventari.objects.create(
            usuari=self.user, producte=self.p1, quantitat=1, unitat='kg',
            data_caducitat=avui - timedelta(days=1)
        )
        ProducteInventari.objects.create(
            usuari=self.user, producte=self.p2, quantitat=1, unitat='kg',
            data_caducitat=avui + timedelta(days=1)
        )
        ProducteInventari.objects.create(
            usuari=self.user, producte=self.p3, quantitat=1, unitat='kg',
            data_caducitat=avui + timedelta(days=30)
        )

    def test_caducitats_dies_0_nomes_caducats(self):
        self.user.dies_avis_caducitat = 0
        self.user.save()
        resp = self.client.get('/inventari/caducitats/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(len(resp.data), 1)

    def test_caducitats_dies_5(self):
        self.user.dies_avis_caducitat = 5
        self.user.save()
        resp = self.client.get('/inventari/caducitats/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(len(resp.data), 2)

    def test_caducitats_dies_31(self):
        self.user.dies_avis_caducitat = 31
        self.user.save()
        resp = self.client.get('/inventari/caducitats/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(len(resp.data), 3)


class ItemCompraTests(APITestCase):
    def setUp(self):
        self.categoria = Categoria.objects.create(nom='Begudes', emoji='🥤')
        self.producte = Producte.objects.create(nom='Aigua', categoria=self.categoria)
        self.user = crear_usuari('compra_user')
        self.altre_user = crear_usuari('compra_user2')
        self.client = auth_client(self.user)
        self.altre_client = auth_client(self.altre_user)

    def test_crear_item_compra(self):
        resp = self.client.post('/compra/', {
            'producte': self.producte.pk,
            'quantitat': 6,
            'unitat': 'unitats',
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        self.assertFalse(resp.data['comprat'])

    def test_marcar_item_com_comprat_patch(self):
        item = ItemCompra.objects.create(
            usuari=self.user, producte=self.producte, quantitat=1, unitat='unitat'
        )
        resp = self.client.patch(f'/compra/{item.pk}/', {'comprat': True}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertTrue(resp.data['comprat'])

    def test_actualitzar_item_compra_put(self):
        item = ItemCompra.objects.create(
            usuari=self.user, producte=self.producte, quantitat=1, unitat='unitat'
        )
        resp = self.client.put(f'/compra/{item.pk}/', {
            'producte': self.producte.pk,
            'quantitat': 3,
            'unitat': 'unitats',
            'comprat': True,
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(float(resp.data['quantitat']), 3.0)
        self.assertTrue(resp.data['comprat'])

    def test_aislament_llista_compra(self):
        ItemCompra.objects.create(
            usuari=self.user, producte=self.producte, quantitat=1, unitat='unitat'
        )
        resp = self.altre_client.get('/compra/')
        self.assertEqual(len(resp.data), 0)

    def test_eliminar_item_compra(self):
        item = ItemCompra.objects.create(
            usuari=self.user, producte=self.producte, quantitat=1, unitat='unitat'
        )
        resp = self.client.delete(f'/compra/{item.pk}/')
        self.assertEqual(resp.status_code, status.HTTP_204_NO_CONTENT)

    def test_eliminar_item_altre_usuari_rebutjat(self):
        item = ItemCompra.objects.create(
            usuari=self.user, producte=self.producte, quantitat=1, unitat='unitat'
        )
        resp = self.altre_client.delete(f'/compra/{item.pk}/')
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)

    def test_patch_item_compra_altre_usuari_rebutjat(self):
        item = ItemCompra.objects.create(
            usuari=self.user, producte=self.producte, quantitat=1, unitat='unitat'
        )
        resp = self.altre_client.patch(f'/compra/{item.pk}/', {'comprat': True}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)

    def test_put_item_compra_inexistent(self):
        resp = self.client.put('/compra/99999/', {
            'producte': self.producte.pk,
            'quantitat': 1,
            'unitat': 'unitat',
            'comprat': False,
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)

    def test_compra_no_autenticat(self):
        resp = APIClient().get('/compra/')
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)


class ReceptaTests(APITestCase):
    def setUp(self):
        self.user = crear_usuari('recepta_user')
        self.client = auth_client(self.user)

        self.r1 = crear_recepta('r1', 'Amanida vegana', temps=10, dietes=['vegà'])
        self.r2 = crear_recepta('r2', 'Bistec a la graella', temps=20)
        self.r3 = crear_recepta('r3', 'Sopa de carbassa', temps=60)

        self.categoria = Categoria.objects.create(nom='Verdures2', emoji='🥦')
        self.producte = Producte.objects.create(nom='Carbassa', categoria=self.categoria)
        IngredientRecepta.objects.create(
            recepta=self.r3, producte=self.producte, quantitat=500, unitat='g'
        )

    def test_llistar_receptes(self):
        resp = self.client.get('/receptes/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('results', resp.data)
        self.assertGreaterEqual(resp.data['count'], 3)

    def test_filtre_dieta(self):
        resp = self.client.get('/receptes/?dieta=vegà')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        noms = [r['nom'] for r in resp.data['results']]
        self.assertIn('Amanida vegana', noms)
        self.assertNotIn('Bistec a la graella', noms)

    def test_filtre_max_temps(self):
        resp = self.client.get('/receptes/?max_temps=20')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        for r in resp.data['results']:
            self.assertLessEqual(r['temps_preparacio'], 20)

    def test_filtre_max_temps_invalid(self):
        resp = self.client.get('/receptes/?max_temps=abc')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_filtre_per_producte(self):
        resp = self.client.get(f'/receptes/?producte={self.producte.pk}')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        noms = [r['nom'] for r in resp.data['results']]
        self.assertIn('Sopa de carbassa', noms)

    def test_filtre_per_producte_invalid(self):
        resp = self.client.get('/receptes/?producte=abc')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_retrieve_recepta_existent(self):
        resp = self.client.get(f'/receptes/{self.r1.id_api}/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.data['nom'], 'Amanida vegana')

    def test_retrieve_recepta_inexistent(self):
        resp = self.client.get('/receptes/recepta_inexistent_xyz/')
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)

    def test_receptes_no_autenticat(self):
        resp = APIClient().get('/receptes/')
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_paginacio_limit_offset(self):
        resp = self.client.get('/receptes/?limit=2&offset=0')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertLessEqual(len(resp.data['results']), 2)


class FavoritTests(APITestCase):
    def setUp(self):
        self.user = crear_usuari('fav_user')
        self.altre_user = crear_usuari('fav_user2')
        self.client = auth_client(self.user)
        self.altre_client = auth_client(self.altre_user)
        self.recepta = crear_recepta('fav_r1', 'Recepta Favorita')
        self.recepta2 = crear_recepta('fav_r2', 'Recepta Favorita 2')

    def test_llistar_favorits_buit(self):
        resp = self.client.get('/favorits/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(len(resp.data), 0)

    def test_afegir_favorit(self):
        resp = self.client.post('/favorits/', {'recepta': self.recepta.id_api}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)

    def test_llistar_favorits_despres_dafegir(self):
        Favorit.objects.create(usuari=self.user, recepta=self.recepta)
        resp = self.client.get('/favorits/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(len(resp.data), 1)

    def test_afegir_favorit_duplicat(self):
        Favorit.objects.create(usuari=self.user, recepta=self.recepta)
        resp = self.client.post('/favorits/', {'recepta': self.recepta.id_api}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_eliminar_favorit(self):
        Favorit.objects.create(usuari=self.user, recepta=self.recepta)
        resp = self.client.delete(f'/favorits/{self.recepta.id_api}/')
        self.assertEqual(resp.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Favorit.objects.filter(usuari=self.user, recepta=self.recepta).exists())

    def test_eliminar_favorit_inexistent(self):
        resp = self.client.delete('/favorits/recepta_inexistent_xyz/')
        self.assertEqual(resp.status_code, status.HTTP_404_NOT_FOUND)

    def test_aillament_favorits_entre_usuaris(self):
        Favorit.objects.create(usuari=self.user, recepta=self.recepta)
        resp = self.altre_client.get('/favorits/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(len(resp.data), 0)

    def test_favorits_no_autenticat(self):
        resp = APIClient().get('/favorits/')
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)


class RecomanacioTests(APITestCase):
    def setUp(self):
        self.user = crear_usuari('rec_user')
        self.client = auth_client(self.user)

        self.categoria = Categoria.objects.create(nom='Proteïnes', emoji='🥩')
        self.p1 = Producte.objects.create(nom='Ou', categoria=self.categoria)
        self.p2 = Producte.objects.create(nom='Tomàquet', categoria=self.categoria)
        self.p3 = Producte.objects.create(nom='Formatge', categoria=self.categoria)

        self.r1 = crear_recepta('rec1', 'Truita de patates', temps=15, dietes=['vegetarià'])
        IngredientRecepta.objects.create(recepta=self.r1, producte=self.p1, quantitat=2, unitat='unitats')
        IngredientRecepta.objects.create(recepta=self.r1, producte=self.p2, quantitat=100, unitat='g')

        self.r2 = crear_recepta('rec2', 'Pasta amb formatge', temps=20)
        IngredientRecepta.objects.create(recepta=self.r2, producte=self.p3, quantitat=50, unitat='g')

        self.r3 = crear_recepta('rec3', 'Estofat llarg', temps=120)
        IngredientRecepta.objects.create(recepta=self.r3, producte=self.p1, quantitat=1, unitat='unitat')

        avui = date.today()
        ProducteInventari.objects.create(
            usuari=self.user, producte=self.p1, quantitat=3, unitat='unitats',
            data_caducitat=avui + timedelta(days=2)
        )
        ProducteInventari.objects.create(
            usuari=self.user, producte=self.p2, quantitat=200, unitat='g',
            data_caducitat=avui + timedelta(days=10)
        )

    def test_recomanacions_basiques(self):
        resp = self.client.get('/recomanacions/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('results', resp.data)

    def test_recomanacions_no_autenticat(self):
        resp = APIClient().get('/recomanacions/')
        self.assertEqual(resp.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_filtre_dieta(self):
        resp = self.client.get('/recomanacions/?dieta=vegetarià')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        noms = [r['nom'] for r in resp.data['results']]
        self.assertIn('Truita de patates', noms)
        self.assertNotIn('Pasta amb formatge', noms)

    def test_filtre_max_temps(self):
        resp = self.client.get('/recomanacions/?max_temps=20')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        for r in resp.data['results']:
            self.assertLessEqual(r['temps_preparacio'], 20)

    def test_filtre_max_temps_invalid(self):
        resp = self.client.get('/recomanacions/?max_temps=abc')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_filtre_nomes_inventari(self):
        resp = self.client.get('/recomanacions/?nomes_inventari=true')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        for r in resp.data['results']:
            self.assertEqual(r['ingredients_coberts'], r['total_ingredients'])

    def test_filtre_nomes_urgents(self):
        self.user.dies_avis_caducitat = 5
        self.user.save()
        resp = self.client.get('/recomanacions/?nomes_urgents=true')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        noms = [r['nom'] for r in resp.data['results']]
        self.assertIn('Truita de patates', noms)

    def test_filtre_productes_param(self):
        resp = self.client.get(f'/recomanacions/?productes={self.p1.pk}')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('results', resp.data)

    def test_filtre_productes_param_invalid(self):
        resp = self.client.get('/recomanacions/?productes=abc,xyz')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)

    def test_recomanacions_sense_inventari(self):
        user_buit = crear_usuari('rec_buit')
        client = auth_client(user_buit)
        resp = client.get('/recomanacions/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        for r in resp.data['results']:
            self.assertEqual(r['score'], 0.0)

    def test_recomanacions_ordenades_per_score_descendent(self):
        resp = self.client.get('/recomanacions/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        scores = [r['score'] for r in resp.data['results']]
        self.assertEqual(scores, sorted(scores, reverse=True))

    def test_paginacio_recomanacions(self):
        resp = self.client.get('/recomanacions/?limit=1&offset=0')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertLessEqual(len(resp.data['results']), 1)