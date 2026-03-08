# ${{values.name}}

${{values.description}}

## Stack

- Python 3.12+
- FastAPI
- Docker

## Instalação

### Docker (recomendado)

```bash
docker build -t ${{values.name}} .
docker run -p 8080:8080 ${{values.name}}
```

### Local

```bash
pip install -r requirements.txt
python main.py
```

## Endpoints

**Health Check:**

```bash
curl http://localhost:8080/actuator/health
```

**Listar:**

```bash
curl http://localhost:8080/pessoas
```

## Desenvolvimento

```bash
# Instalar dependências
pip install -r requirements.txt

# Rodar testes
pytest test/

# Build Docker
docker build -t ${{values.name}} .
```

## Owner

**Team:** ${{values.owner}}
