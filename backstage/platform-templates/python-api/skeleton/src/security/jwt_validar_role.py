import logging
import jwt
from functools import wraps
from flask import request
from src.config.configuracao import token_infos

def jwt_validar_role(role):
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            data = request.headers.get('Authorization')
            if data is None:
                logging.error('Token não informado')
                return "Token não informado", 401
            
            if not data.startswith('Bearer '):
                logging.error('Token inválido')
                return "Token inválido", 401
            
            token = data.replace('Bearer ', '')
            
            jwk_client = jwt.PyJWKClient(token_infos['jwks_url'])
            sign_key = jwk_client.get_signing_key_from_jwt(token)
            decoded = jwt.decode(token, sign_key.key, algorithms=['RS256'], options={'verify_signature':True}, audience=token_infos['audience'])
            logging.info(f'decoded:{decoded}')
        
            roles_com_admin = decoded['realm_access']['roles']
            roles_sem_admin = decoded['resource_access']['account']['roles']
        
            roles = roles_com_admin + roles_sem_admin
            logging.info(f'roles:{roles}')
            
            if role not in roles:
                logging.error('Role inválida')
                return "Role inválida", 403
                
            return func(*args, **kwargs)
        return wrapper
    return decorator