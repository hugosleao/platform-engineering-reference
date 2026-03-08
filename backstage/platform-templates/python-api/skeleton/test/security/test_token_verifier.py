
from flask import Flask, jsonify
import pytest
from unittest import mock

from src.security.token_verifier import token_verify
app = Flask(__name__)

class TestTokenVerifier():
    @classmethod
    def setup_class(self):
        app.config['TESTING'] = True
        self.token_fake = 'ezr_YVRo-RWaueniIiaNUBDJBQDaoJ0rZVj5Y1wp'
        self.tipo_autenticacao = 'Bearer'
        self.signing_key_fake = 'RWaueniIiaNUBDJBQDaoJ0rZVj5Y1wplKQp5iLq7pGbq1Ny'
        return app
    

    def test_deve_retornar_erro_ao_enviar_token_invalido(self, mocker):
        mock_jwt_client = mocker.Mock()
        
        mocker.patch('jwt.PyJWKClient', return_value=mock_jwt_client)
        mocker.patch('jwt.decode', side_effect=Exception('mocked error'))
        headers_auth = {'Authorization': self.tipo_autenticacao + ' ' + self.token_fake}

        @token_verify
        def funcao_teste_header(token):
            return jsonify(token)
       
        with app.test_request_context('/', headers = headers_auth):
            resp  = funcao_teste_header()
            assert resp[1] == 401
            assert resp[0].json == 'Token Invalido'

    def test_deve_retornar_erro_ao_enviar_nao_enviar_token(self):
     
        @token_verify
        def funcao_teste_header(token):
            return jsonify(token)
       
        with app.test_request_context('/'):
            resp  = funcao_teste_header()
            assert resp[1] == 401
            assert resp[0].json == 'Token JWT não encontrado'

    def test_deve_retornar_erro_ao_enviar_token_formato_invalido(self):
       
        headers_auth = {'Authorization': f'Basic {self.token_fake}'}
      
        @token_verify
        def funcao_teste_header(token):
            return jsonify(token)
       
        with app.test_request_context('/', headers = headers_auth):
            resp  = funcao_teste_header()
            assert resp[1] == 401
            assert resp[0].json == 'Token no formato invalido'
