#!/bin/bash
# Recupera todas as credenciais do lab provisionado
set -euo pipefail

CYAN='\033[0;36m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

ARGOCD_PASS=$(kubectl get secret argocd-initial-admin-secret \
  -n argocd -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "N/A")

GRAFANA_PASS=$(kubectl get secret -n monitoring \
  $(kubectl get secret -n monitoring --no-headers -o custom-columns=":metadata.name" | grep grafana) \
  -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 -d || echo "N/A")

POSTGRES_PASS=$(kubectl get secret postgres-credentials \
  -n backstage -o jsonpath="{.data.POSTGRES_PASSWORD}" 2>/dev/null | base64 -d || echo "N/A")

PLATFORM_TOKEN=$(aws secretsmanager get-secret-value \
  --secret-id "platform/lab/shared-config" \
  --query "SecretString" --output text 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('PLATFORM_API_TOKEN','N/A'))" 2>/dev/null || echo "N/A")

echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  ACESSOS E CREDENCIAIS — vision-2026                      ║${NC}"
echo -e "${BOLD}╠═══════════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}║${NC}  Backstage    ${CYAN}https://backstage.devopstia.com${NC}"
echo -e "${BOLD}║${NC}               Login via GitHub OAuth"
echo -e "${BOLD}║${NC}"
echo -e "${BOLD}║${NC}  ArgoCD       ${CYAN}https://argocd.devopstia.com${NC}"
echo -e "${BOLD}║${NC}               Usuário : admin"
echo -e "${BOLD}║${NC}               Senha   : ${YELLOW}$ARGOCD_PASS${NC}"
echo -e "${BOLD}║${NC}"
echo -e "${BOLD}║${NC}  Grafana      ${CYAN}https://grafana.devopstia.com${NC}"
echo -e "${BOLD}║${NC}               Usuário : admin"
echo -e "${BOLD}║${NC}               Senha   : ${YELLOW}$GRAFANA_PASS${NC}"
echo -e "${BOLD}║${NC}"
echo -e "${BOLD}║${NC}  Platform API ${CYAN}https://platform-api.devopstia.com/v1/health${NC}"
echo -e "${BOLD}║${NC}               Bearer  : ${YELLOW}$PLATFORM_TOKEN${NC}"
echo -e "${BOLD}║${NC}"
echo -e "${BOLD}║${NC}  PostgreSQL   postgresql.backstage.svc.cluster.local"
echo -e "${BOLD}║${NC}               Usuário : backstage"
echo -e "${BOLD}║${NC}               Senha   : ${YELLOW}$POSTGRES_PASS${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
