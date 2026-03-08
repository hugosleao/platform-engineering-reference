# Python API Template - Multi-Version Support

## Versões Python Suportadas

✅ Python 3.11
✅ Python 3.12 (recomendado)
✅ Python 3.13

## Como Rodar Localmente

### Opção 1: Ambiente Virtual (sua versão Python local)

```bash
# Pré-requisito: Python 3.11+ instalado
python3 --version  # Verificar versão

# 1. Criar ambiente
python3 -m venv venv
source venv/bin/activate  # Linux/Mac
# ou: venv\Scripts\activate  # Windows

# 2. Instalar dependências
pip install -r requirements.txt

# 3. Rodar
python main.py

# 4. Testar
curl http://localhost:8080/actuator/health
```

### Opção 2: Docker (versão isolada)

```bash
# Python 3.12 (padrão)
docker build -t python-api .
docker run -p 8080:8080 python-api

# Python 3.11
docker build --build-arg PYTHON_VERSION=3.11 -t python-api:py311 .
docker run -p 8080:8080 python-api:py311

# Python 3.13
docker build --build-arg PYTHON_VERSION=3.13 -t python-api:py313 .
docker run -p 8080:8080 python-api:py313
```

### Opção 3: Docker Compose

```bash
docker-compose up
```

## Testes

```bash
# Rodar testes
pytest

# Com coverage
pytest --cov=src --cov-report=html
open htmlcov/index.html
```

## Endpoints Disponíveis

- `GET /actuator/health` - Health check
- `GET /` - Hello world
- `GET /pessoas` - Listar pessoas
- `POST /pessoas` - Criar pessoa (requer JWT)
- `GET /pessoas/{cpf}` - Buscar por CPF
- `DELETE /pessoas/{cpf}` - Deletar (requer JWT)
- `GET /criar` - Gerar token JWT

## Teste Completo

```bash
# 1. Gerar token
TOKEN=$(curl -s http://localhost:8080/criar | jq -r '.access_token')

# 2. Criar pessoa
curl -X POST http://localhost:8080/pessoas \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"nome":"Hugo","cpf":"12345678900"}'

# 3. Listar
curl http://localhost:8080/pessoas

# 4. Buscar
curl http://localhost:8080/pessoas/12345678900

# 5. Deletar
curl -X DELETE http://localhost:8080/pessoas/12345678900 \
  -H "Authorization: Bearer $TOKEN"
```

## Compatibilidade

| Versão | Status | Fim Suporte |
|--------|--------|-------------|
| 3.11   | ✅ Suportado | Out 2027 |
| 3.12   | ✅ Recomendado | Out 2028 |
| 3.13   | ✅ Suportado | Out 2029 |

## Estrutura do Projeto

```
template/
├── src/
│   ├── adapters/       # Implementações concretas
│   ├── domain/         # Regras de negócio
│   │   ├── models/     # Modelos de domínio
│   │   ├── ports/      # Interfaces (contratos)
│   │   └── services/   # Lógica de negócio
│   ├── config/         # Configurações
│   ├── exceptions/     # Exceções customizadas
│   └── security/       # JWT, autenticação
├── test/               # Testes unitários
├── main.py            # Entry point
├── requirements.txt   # Dependências
├── pyproject.toml     # Configuração Python
└── Dockerfile         # Multi-version
```

## Desenvolvimento

```bash
# Instalar em modo desenvolvimento
pip install -e .

# Rodar com reload automático
python -m flask run --reload

# Ou com uvicorn (se migrar para FastAPI)
uvicorn src.main:app --reload
```
