import pytest
from unittest.mock import Mock
from src.domain.models.pessoa import Pessoa
import main
from src.domain.services.pessoa_services import PessoaService
from src.exceptions.exceptions_pessoa import ExceptionPessoaJaCadastrada, ExcetionPessoaNaoEstaCadastrada
from flask import jsonify, request
from flask.testing import FlaskClient

class TestMain():
    @classmethod
    def setup_class(cls):
        cls.app = main.app.test_client()
        cls.aline_nome = 'Aline da Silva'
        cls.aline_cpf = '139.649.293-36'
        cls.url_cpf = '/pessoas/139.649.293-36'
        cls.token_fake = 'ezr_YVRo-RWaueniIiaNUBDJBQDaoJ0rZVj5Y1wp'
        cls.tipo_autenticacao = 'Bearer'
        cls.signing_key_fake = 'RWaueniIiaNUBDJBQDaoJ0rZVj5Y1wplKQp5iLq7pGbq1Ny'
        cls.rota_recebe = '/receber'
        cls.rota_pessoa = '/pessoas'
        cls.rota_admin = '/admin_token'

    def test_deve_retornar_sucesso_ao_criar_usuario(self, mocker):
        
        mock_jwt_client = mocker.Mock()
        
        mocker.patch('jwt.PyJWKClient', return_value=mock_jwt_client)
        mocker.patch('jwt.decode', return_value={'token':"teste"})
        headers_auth = {'Authorization': self.tipo_autenticacao + ' ' + self.token_fake}


        request_data = {'nome': self.aline_nome, 'cpf': self.aline_cpf}
        main.pessoa_service.salvar = Mock(spec=  PessoaService, return_value=Pessoa(self.aline_nome, self.aline_cpf))
        response = self.app.post(self.rota_pessoa, json=request_data, headers = headers_auth)
        main.pessoa_service.salvar.assert_called_once

        assert response.status_code == 201

    def test_deve_retornar_mensagem_erro_tentar_cadastrar_pessoa_ja_cadastrada(self, mocker):
          
        mock_jwt_client = mocker.Mock()
        
        mocker.patch('jwt.PyJWKClient', return_value=mock_jwt_client)
        mocker.patch('jwt.decode', return_value={'token':"teste"})

        request_data = {'nome': self.aline_nome, 'cpf': self.aline_cpf}
        headers_auth = {'Authorization': self.tipo_autenticacao + ' ' + self.token_fake}

        main.pessoa_service = Mock(spec=  PessoaService)
        main.pessoa_service.salvar = ExceptionPessoaJaCadastrada(self.aline_cpf)
        response_secundario = self.app.post(self.rota_pessoa, json=request_data, headers = headers_auth)

        assert response_secundario.status_code == 409

    def test_deve_retornar_mensagem_sucesso_buscar_pessoa_por_cpf(self):
        main.pessoa_service = Mock(spec=  PessoaService)
        main.pessoa_service.buscar_por_cpf = Mock(spec= PessoaService, return_value= Pessoa(self.aline_nome, self.aline_cpf))
        response = self.app.get(self.url_cpf)
        main.pessoa_service.buscar_por_cpf.assert_called_once
        
        assert response.status_code == 200

    def test_deve_retornar_mensagem_erro_tentar_buscar_pessoa_nao_cadastrada_ocorrer_exception(self):

        main.pessoa_service = Mock(spec=  PessoaService)
        main.pessoa_service.buscar_por_cpf = Mock(spec=  PessoaService, return_value= Exception )
        response = self.app.get(self.url_cpf)
        
        assert response.status_code == 409

    
    def test_deve_retornar_mensagem_erro_tentar_buscar_pessoa_nao_cadastrada(self):

        main.pessoa_service = Mock(spec=  PessoaService)
        main.pessoa_service.salvar = ExcetionPessoaNaoEstaCadastrada ()
        response = self.app.get(self.url_cpf)

        assert response.status_code == 200
        assert response.json == 'Pessoa não encontrada!'


    def test_deve_retornar_sucesso_obter_lista(self):

        joao_cpf =  "086.864.293-36"
        joao_nome = "Joao da Silva"

        pessoa_aline = Pessoa(self.aline_nome, self.aline_cpf)
        pessoa_joao = Pessoa(joao_nome,joao_cpf)

        main.pessoa_service.listar = Mock(spec=  PessoaService, return_value= [pessoa_aline, pessoa_joao])
        response = self.app.get(self.rota_pessoa)
        
        main.pessoa_service.listar.assert_called_once

        assert response.status_code == 200
        assert {'nome':self.aline_nome, 'cpf': self.aline_cpf} in response.json
        assert {'nome':joao_nome, 'cpf': joao_cpf} in response.json

    def test_deve_retornar_sucesso_excluir(self, mocker):
    
        mock_jwt_client = mocker.Mock()
        
        mocker.patch('jwt.PyJWKClient', return_value=mock_jwt_client)
        mocker.patch('jwt.decode', return_value={'token':"teste"})

        main.pessoa_service.excluir = Mock(spec=  PessoaService, return_value= None)

        headers_auth = {'Authorization': self.tipo_autenticacao + ' ' + self.token_fake}
        response = self.app.delete(self.url_cpf, headers = headers_auth)
        main.pessoa_service.excluir.assert_called_once

        assert response.status_code == 200
    
    def test_deve_retornar_mensagem_erro_tentar_excluir_pessoa_nao_cadastrada(self, mocker ):
     
        mock_jwt_client = mocker.Mock()
        mocker.patch('jwt.PyJWKClient', return_value=mock_jwt_client)
        mocker.patch('jwt.decode', return_value={'token':"teste"})
        headers_auth = {'Authorization': self.tipo_autenticacao+' '+self.token_fake}

        main.pessoa_service = Mock(spec = PessoaService)
        main.pessoa_service.excluir = ExcetionPessoaNaoEstaCadastrada()
        response = self.app.delete(self.url_cpf, headers = headers_auth)
    
        assert response.status_code == 409

    
    def test_deve_retornar_erro_acessar_rota_protegida_sem_token(self, mocker):
        response = self.app.post(self.rota_pessoa)
        assert response.status_code == 401
   
    def test_deve_retornar_sucesso_acessar_rota_recebe_token(self):

        headers = {'Authorization': self.tipo_autenticacao + self.token_fake}
        response = self.app.get(self.rota_recebe, headers=headers)

        assert response.status_code == 200

    def test_deve_retornar_erro_acessar_rota_recebe_token_sem_header_authorization(self):
        response = self.app.get(self.rota_recebe)
        assert response.status_code == 401
        assert 'Token JWT não encontrado' == response.json
    
    def test_deve_retornar_erro_ao_acessar_rota_encaminhar_token_com_token_valido_e_der_erro_no_encamihamento_do_token(self, mocker):
        mock_jwt_client = mocker.Mock()
        
        mocker.patch('jwt.PyJWKClient', return_value=mock_jwt_client)
        mocker.patch('jwt.decode', return_value={'token':"teste"})

        mock_request = mocker.Mock()
        mock_request.headers.get.return_value =  {'Authorization': self.tipo_autenticacao + ' ' + self.token_fake}
        mocker.patch('requests.get', mock_request)

        headers_auth = {'Authorization': self.tipo_autenticacao + ' ' + self.token_fake}
        response = self.app.post('/encaminhar_token', headers = headers_auth)

        assert response.status_code == 401
        assert 'Erro com o forward do token' == response.json
       
  
    def test_deve_retornar_sucesso_ao_acessar_rota_encaminhar_token_com_token_valido(self, mocker):
        mock_jwt_client = mocker.Mock()
        mocker.patch('jwt.PyJWKClient', return_value=mock_jwt_client)
        mocker.patch('jwt.decode', return_value={'token':"teste"})
        
        mock_request = mocker.Mock()
        mock_request.headers.get.return_value =  {'Authorization': self.tipo_autenticacao + ' ' + self.token_fake}

        mock_response = mocker.Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {'status': 'sucesso'}

        mock_request.return_value = mock_response
        mocker.patch('requests.get', mock_request)
        
        headers_auth = {'Authorization': self.tipo_autenticacao + ' ' + self.token_fake}
        response = self.app.post('/encaminhar_token', headers = headers_auth)

        assert response.status_code == 200

    def test_deve_retornar_erro_ao_acessar_rota_encaminhar_token_com_token_valido_e_der_erro_no_encamihamento_do_token(self, mocker):
        mock_jwt_client = mocker.Mock()
        mocker.patch('jwt.PyJWKClient', return_value=mock_jwt_client)
        mocker.patch('jwt.decode', return_value={'token':"teste"})
        
        mock_request = mocker.Mock()
        mock_request.headers.get.return_value =  {'Authorization': self.tipo_autenticacao + ' ' + self.token_fake}

        mock_response = mocker.Mock()
        mock_response.status_code = 403
        mock_response.json.return_value = {'status': 'erro'}

        mock_request.return_value = mock_response
        mocker.patch('requests.get', mock_request)
        
        headers_auth = {'Authorization': self.tipo_autenticacao + ' ' + self.token_fake}
        response = self.app.post('/encaminhar_token', headers = headers_auth)

        assert response.status_code == 401
        assert response.json == 'Erro com o forward do token'

    def test_deve_retornar_sucesso_ao_acessar_rota_admin_token_com_token_valido(self, mocker):
        mock_jwt_client = mocker.Mock()
        mocker.patch('jwt.PyJWKClient', return_value = mock_jwt_client)
        role = 'admin'  
        roles = {'realm_access': {'roles': [role]}, 'resource_access': {'account': {'roles': [role]}}}
        mocker.patch('jwt.decode', return_value=roles)
        response = self.app.post(self.rota_admin, headers= {'Authorization': self.tipo_autenticacao + ' ' + self.token_fake})
        assert response.status_code == 200
    
    def test_deve_retornar_erro_ao_acessar_rota_admin_token_nao_enviando_token(self):
        response = self.app.post(self.rota_admin)
        assert response.status_code == 401
    
    def test_deve_retornar_erro_ao_acessar_rota_admin_token_enviando_token_invalido(self):
        response = self.app.post(self.rota_admin, headers={'Autorization': 'basic'})
        assert response.status_code == 401
        
    def test_deve_retornar_erro_ao_acessar_rota_admin_token_com_role_invalida(self, mocker):
        mock_jwt_client = mocker.Mock()
        mocker.patch('jwt.PyJWKClient', get_signing_key_from_jwt = mock_jwt_client)
        role = 'user'
        roles = {'realm_access': {'roles': [role]}, 'resource_access': {'account': {'roles': [role]}}}
        mocker.patch('jwt.decode', return_value=roles)
        response = self.app.post(self.rota_admin, headers = {'Authorization': self.tipo_autenticacao + ' ' + self.token_fake})
        assert response.status_code == 403
   
    def test_deve_retornar_sucesso_ao_acessar_rota_operator_token_com_token_valido_e_role_operator(self, mocker):
        mock_jwt_client = mocker.Mock()
        mocker.patch('jwt.PyJWKClient', return_value = mock_jwt_client)
        role = 'operator'
        roles = {'realm_access': {'roles': [role]}, 'resource_access': {'account': {'roles': [role]}}}
        mocker.patch('jwt.decode', return_value=roles)
        response = self.app.post('/operator_token', headers= {'Authorization': self.tipo_autenticacao + ' ' + self.token_fake})
        assert response.status_code == 200

    def test_deve_retornar_erro_ao_acessar_rota_nao_admin_token_com_token_valido_e_role_admin(self, mocker):
        mock_jwt_client = mocker.Mock()
        mocker.patch('jwt.PyJWKClient', return_value = mock_jwt_client)
        role = 'admin'
        roles = {'realm_access': {'roles': [role]}, 'resource_access': {'account': {'roles': [role]}}}
        mocker.patch('jwt.decode', return_value=roles)
        response = self.app.post('/nao_admin_token', headers= {'Authorization': self.tipo_autenticacao + ' ' + self.token_fake})
        assert response.status_code == 403

    def test_deve_retornar_sucesso_ao_acessar_rota_nao_admin_token_com_token_valido_e_nao_admin_token(self, mocker):
        mock_jwt_client = mocker.Mock()
        mocker.patch('jwt.PyJWKClient', return_value = mock_jwt_client)
        role = 'nao_admin'
        roles = {'realm_access': {'roles': [role]}, 'resource_access': {'account': {'roles': [role]}}}
        mocker.patch('jwt.decode', return_value=roles)
        response = self.app.post('/nao_admin_token', headers= {'Authorization': self.tipo_autenticacao + ' ' + self.token_fake})
        assert response.status_code == 200