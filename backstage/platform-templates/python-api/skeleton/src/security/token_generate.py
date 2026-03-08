import requests

from src.config.configuracao import token_infos

class TokenGenerate():
 
    def create_token(self):
        data = {
            'grant_type': 'client_credentials',
            'client_id': token_infos['client_id'],
            'client_secret': token_infos['client_secret']
        }
   
        response = requests.post(token_infos['jwks_url_provider'], data = data, verify='/etc/ssl/certs/ca-certificates.crt')

        return response
