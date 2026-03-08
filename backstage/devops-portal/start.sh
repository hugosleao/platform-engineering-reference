#!/bin/bash

# Backstage Startup Script
echo "🚀 Carregando variáveis de ambiente..."

# Carregar .env no ambiente atual
set -a
source .env
set +a

echo "📦 PostgreSQL: ${POSTGRES_HOST}:${POSTGRES_PORT}"
echo "👤 User: ${POSTGRES_USER}"
echo ""

# Iniciar Backstage com variáveis carregadas
yarn start
