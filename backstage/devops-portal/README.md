# Backstage DevOps Portal

## 🚀 Inicialização

**Sempre use o script para garantir que as variáveis de ambiente sejam carregadas:**

```bash
cd /Users/hugoleao/crossplane/devops-portal
./start.sh
```

**OU manualmente:**

```bash
cd /Users/hugoleao/crossplane/devops-portal
set -a
source .env
set +a
yarn start
```

## 📝 Variáveis de Ambiente

Configuradas no arquivo `.env`:
- `POSTGRES_HOST=127.0.0.1`
- `POSTGRES_PORT=5432`
- `POSTGRES_USER=backstage`
- `POSTGRES_PASSWORD=backstage_secret`

## 🐘 PostgreSQL

**Verificar se está rodando:**
```bash
docker ps | grep postgres
```

**Iniciar (se não estiver rodando):**
```bash
docker start backstage-postgres
```

## 🔧 Troubleshooting

**Erro "Could not fetch catalog entities":**
- Certifique-se que as variáveis de ambiente foram carregadas
- Use `./start.sh` ao invés de `yarn start` direto

**Erro "Failed to load entity kinds":**
- PostgreSQL não está rodando
- Variáveis de ambiente não foram carregadas
