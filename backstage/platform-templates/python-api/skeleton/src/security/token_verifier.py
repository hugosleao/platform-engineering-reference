import logging
from functools import wraps
import jwt
from jwt import PyJWKClient
from src.config import token_infos
from src.exceptions.exceptions_token import ExeptionToken
from flask import request, jsonify
from time import time

def token_verify(function) :
    @wraps(function)
    def wrapper(*args, **kwargs):
        
        jwt_token = request.headers.get('Authorization')
        if jwt_token is None:
            logging.error("Token no formato invalido não é JWT ")
            return jsonify(str(ExeptionToken('JWT não encontrado'))), 401
        
        if not jwt_token.startswith('Bearer'):
            logging.error("Token no formato invalido")
            return jsonify(str(ExeptionToken('no formato invalido'))), 401

        token = jwt_token.replace('Bearer ', '').strip()

        try:
            
            jwks_client = jwt.PyJWKClient(token_infos['jwks_url'])
            signing_key = jwks_client.get_signing_key_from_jwt(token)
                 
            jwt.decode(
                    token,
                    signing_key.key,
                    algorithms=["RS256"],
                    options={"verify_signature": True},
                    audience=token_infos['audience'])
            
            logging.info("Sucesso ao realizar o decode do token " )
            return function(*args, **kwargs)

        except jwt.ExpiredSignatureError as e:
            logging.error("Exception token expirado %s", {str(e)})
            return jsonify(str(ExeptionToken('Expirado'))), 401
        except jwt.InvalidTokenError as e:
            logging.error("Exception no formato invalido %s", {str(e)})
            return jsonify(str(ExeptionToken('Formato Invalido'))), 403
        except Exception as e:
            logging.error("Exception generica %s", {str(e)})
            return jsonify(str(ExeptionToken('Invalido'))), 401

       
    return wrapper