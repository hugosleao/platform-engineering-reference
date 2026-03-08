import os

token_infos = {
   
    "audience": os.environ.get('arquitetura_cielo_oauth2_audience','account'),
    "client_id": os.environ.get('arquitetura_cielo_oauth2_client_id',''),
    "client_secret": os.environ.get('arquitetura_cielo_oauth2_client_secret',''),
    "jwks_url_provider": os.environ.get('arquitetura_cielo_oauth2_token_url','https://rhsso.enterprisetrn.hdevelo.com.br/auth/realms/developer/protocol/openid-connect/token'),
    "jwks_url": os.environ.get('arquitetura_cielo_oauth2_jwks_provider_urls','https://rhsso.enterprisetrn.hdevelo.com.br/auth/realms/developer/protocol/openid-connect/certs')
    }

app_infos = {
   
    "port": os.environ.get('port','8080')
}