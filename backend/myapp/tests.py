from django.test import TestCase
from rest_framework.test import APITestCase, APIClient
from rest_framework import status
from django.urls import reverse
from django.utils import timezone
from datetime import date, timedelta
from .models import Usuari, Categoria, Producte, ProducteInventari, ItemCompra, Recepta, Favorit

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