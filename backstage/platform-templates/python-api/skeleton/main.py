from flask import Flask, request, jsonify
from src.domain.models.pessoa import PessoaSchema
from src.domain.ports.pessoa_repository_port import PessoaRepositoryPort
from src.adapters.repositories import InMemoryPessoaRepository
from src.domain.services.pessoa_services import PessoaService
from src.security.jwt_validar_role import jwt_validar_role
from src.security.token_generate import TokenGenerate
from src.security.token_verifier import token_verify

from flask_wtf.csrf import CSRFProtect
import logging
import requests
from src.config.configuracao import app_infos
from os import environ


logger = logging.getLogger('__name__')
logging.basicConfig(filemode='w', level=logging.WARN, format= '[%(asctime)s] [%(pathname)s:%(lineno)d] [%(levelname)s] - %(message)s',
datefmt='%H:%M:%S')

token_generate = TokenGenerate()

app = Flask(__name__)
app.config['WTF_CSRF_ENABLED'] = False
csrf = CSRFProtect()
csrf.init_app(app)

pessoa_repository = InMemoryPessoaRepository()
pessoa_repository_port = PessoaRepositoryPort(pessoa_repository)
pessoa_service = PessoaService(pessoa_repository_port)


@app.route('/actuator/health', methods=['GET'])
def actuator():
    return 'teste', 200

@app.route('/', methods=['GET'])
def hello():
    return 'Olá'

@app.route('/pessoas', methods=['GET'])
def listar():
    pessoas = pessoa_service.listar()
    lista_pessoa_schema = PessoaSchema(many=True)
    result = lista_pessoa_schema.dump(pessoas)
    return  jsonify(result), 200

@app.route('/pessoas', methods = ["POST"])
@token_verify
def salvar():
    data = request.json
    nome = data['nome']
    cpf = data['cpf']
 
    try:
        pessoa = pessoa_service.salvar(nome, cpf)
        return jsonify(nome=pessoa.nome, cpf=pessoa.cpf), 201
    except Exception as e:
        return jsonify(str(e)), 409        

@app.route('/pessoas/<cpf>', methods=['GET'])
def buscar_por_cpf(cpf:str):
    try:
        pessoa = pessoa_service.buscar_por_cpf(cpf)
        if None != pessoa and pessoa.cpf == cpf:
            return jsonify(nome=pessoa.nome, cpf=pessoa.cpf), 200
        
        return  jsonify('Pessoa não encontrada!'), 200
    except Exception as e:
        return jsonify(str(e)), 409        


@app.route('/pessoas/<cpf>', methods=['DELETE'])
@token_verify
def excluir(cpf:str):
    try:
        pessoa_service.excluir(cpf)
        return  jsonify('Pessoa excluída com sucesso!'), 200
    except Exception as e:
        return jsonify(str(e)), 409      

@app.route('/encaminhar_token', methods=['POST'])
@token_verify
def encaminhar_token():
     
    headers = processar_token()
    url_encaminhamento = 'https://cca-sorveteria-da-esquina.cca.dev.cieloaws/receber'
    try:
    
        response = requests.get(url_encaminhamento, headers=headers, verify='/etc/ssl/certs/ca-certificates.crt')
         
        logging.info(f"Status {response.status_code}")
        if response.status_code == 200:            
            return jsonify('Sucesso ao encaminhar o token:', response.json()), 200
        
    except Exception as e: 
        logging.error(f"Erro ao fazer o encaminhamento do token na url {url_encaminhamento} - " + str(e))

    return jsonify('Erro com o forward do token'), 401


@app.route('/receber', methods=['GET'])
def receber():
    jwt_token = request.headers.get('Authorization')
    if not jwt_token :
        logging.info("Nao foi encontrado token")
        return jsonify('Token JWT não encontrado'), 401
        
    jwt_token = jwt_token.replace('Bearer ', '')
    logging.info(f"Sucesso ao receber {jwt_token} ")
    return jsonify(jwt_token),200

@app.route('/admin_token', methods=['POST'])
@jwt_validar_role('admin')
def admin_token():
    return "Token válido com a role admin", 200

@app.route('/operator_token', methods=['POST'])
@jwt_validar_role('operator')
def operator_token():
    return "Token válido com a role operator", 200
    
@app.route('/nao_admin_token', methods=['POST'])
@jwt_validar_role('nao_admin')
def nao_admin_token():
    return "Sucesso ao entrar com a role nao admin", 200

@app.route('/criar', methods=['GET'])
def criar():
    access_token = token_generate.create_token()

    return str(access_token.json()), access_token.status_code

def processar_token():
    jwt_token = request.headers.get('Authorization')
    token = jwt_token.replace('Bearer ', '').strip()
    logging.info(f" Iniciando o metodo de processamento de token com {token}")
    headers = {'Authorization': f'Bearer {token}'}
    return headers

if __name__ == '__main__':
   app.run(debug=False, host='0.0.0.0', port=8080)