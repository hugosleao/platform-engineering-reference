#!/bin/bash
# Instala hooks de segurança no repositório local
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
HOOKS_SRC="$ROOT/.github/hooks"
HOOKS_DST="$ROOT/.git/hooks"

echo -e "${CYAN}Instalando git hooks de segurança...${NC}"

# Copia e torna executável
cp "$HOOKS_SRC/pre-commit" "$HOOKS_DST/pre-commit"
chmod +x "$HOOKS_DST/pre-commit"
echo -e "${GREEN}✅ pre-commit hook instalado${NC}"

# Instala gitleaks se não existir
if ! command -v gitleaks &>/dev/null; then
  echo -e "${YELLOW}gitleaks não encontrado — instalando...${NC}"
  if command -v brew &>/dev/null; then
    brew install gitleaks
  else
    echo -e "${YELLOW}Instale manualmente: https://github.com/gitleaks/gitleaks#install${NC}"
  fi
else
  echo -e "${GREEN}✅ gitleaks já instalado: $(gitleaks version)${NC}"
fi

echo ""
echo -e "${GREEN}✅ Hooks instalados. Todo commit será verificado automaticamente.${NC}"
