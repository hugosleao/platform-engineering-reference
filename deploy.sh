#!/bin/bash
# ============================================================
# vision-2026 — MASTER DEPLOY
# Ordem: prerequisites → backend → vpc → eks → networking
#        → secrets → platform → crossplane → kyverno
#        → gitops → platform-api → observability → validação
#
# CHECKPOINT: retoma do último step concluído automaticamente.
# Se quebrar, rode ./deploy.sh novamente — pula o que já foi feito.
# Para forçar do zero: rm .deploy-checkpoint
# ============================================================
set -euo pipefail

# ── cores ────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/infra"
LOG_FILE="$SCRIPT_DIR/deploy-$(date +%Y%m%d-%H%M%S).log"
CHECKPOINT_FILE="$SCRIPT_DIR/.deploy-checkpoint"

step()  { echo -e "\n${BLUE}${BOLD}[$1/$TOTAL_STEPS] $2${NC}"; }
ok()    { echo -e "${GREEN}✅ $1${NC}"; }
warn()  { echo -e "${YELLOW}⚠️  $1${NC}"; }
fail()  { echo -e "${RED}❌ $1${NC}"; exit 1; }
info()  { echo -e "${CYAN}   $1${NC}"; }

TOTAL_STEPS=13

# ── sistema de checkpoint ─────────────────────────────────────
LAST_OK=0
[ -f "$CHECKPOINT_FILE" ] && LAST_OK=$(cat "$CHECKPOINT_FILE")

checkpoint_done() {
  local n=$1
  echo "$n" > "$CHECKPOINT_FILE"
}

# Pula steps já concluídos
skip_if_done() {
  local n=$1; local label=$2
  if [ "$LAST_OK" -ge "$n" ]; then
    echo -e "${GREEN}⏭  [${n}/${TOTAL_STEPS}] ${label} — já concluído, pulando${NC}"
    return 0  # indica: pular
  fi
  return 1  # indica: executar
}

# ── trap: mostra contexto do erro ────────────────────────────
trap_err() {
  local code=$? line=$1
  echo ""
  echo -e "${RED}${BOLD}═══════════════════════════════════════════════════${NC}"
  echo -e "${RED}${BOLD}  ❌ ERRO no step $LAST_OK+1 — linha $line (exit $code)${NC}"
  echo -e "${RED}${BOLD}═══════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${YELLOW}Últimas 20 linhas do log:${NC}"
  tail -20 "$LOG_FILE" 2>/dev/null || true
  echo ""
  echo -e "${BOLD}Para retomar de onde parou:${NC}"
  echo -e "  ${CYAN}./deploy.sh${NC}           # continua do step $((LAST_OK + 1))"
  echo -e "${BOLD}Para recomeçar do zero:${NC}"
  echo -e "  ${CYAN}rm .deploy-checkpoint && ./deploy.sh${NC}"
  echo ""
  echo -e "  Log completo: ${CYAN}$LOG_FILE${NC}"
}
trap 'trap_err $LINENO' ERR

if [ "$LAST_OK" -gt 0 ]; then
  echo -e "${YELLOW}${BOLD}Retomando deploy do step $((LAST_OK + 1))/${TOTAL_STEPS}${NC}"
  echo -e "${CYAN}  (Para recomeçar do zero: rm .deploy-checkpoint)${NC}\n"
fi

# ── preflight ────────────────────────────────────────────────
if ! skip_if_done 1 "Verificando pré-requisitos"; then
  step 1 "Verificando pré-requisitos"

  check_cmd() { command -v "$1" &>/dev/null || fail "Faltando: $1 — instale antes de continuar"; }
  check_cmd aws; check_cmd terraform; check_cmd kubectl
  check_cmd helm; check_cmd jq; check_cmd git

  AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) \
    || fail "AWS CLI não autenticado."
  AWS_REGION=${AWS_REGION:-us-east-1}

  [ ! -f "$TF_DIR/01-vpc/terraform.tfvars" ] && \
    fail "terraform.tfvars não encontrado. Rode primeiro: ./setup.sh"

  ok "Pré-requisitos OK | Conta AWS: $AWS_ACCOUNT | Região: $AWS_REGION"
  checkpoint_done 1
fi

# Garante que AWS_ACCOUNT e AWS_REGION estão sempre definidos
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
AWS_REGION=${AWS_REGION:-$(grep "^aws_region" "$TF_DIR/01-vpc/terraform.tfvars" 2>/dev/null | cut -d'"' -f2 || echo "us-east-1")}

# ── backend ──────────────────────────────────────────────────
if ! skip_if_done 2 "Provisionando backend Terraform (S3 + DynamoDB)"; then
  step 2 "Provisionando backend Terraform (S3 + DynamoDB)"
  cd "$TF_DIR/00-backend"
  terraform init -input=false >> "$LOG_FILE" 2>&1
  terraform apply -auto-approve -input=false | tee -a "$LOG_FILE" | tail -5
  ok "Backend provisionado"
  checkpoint_done 2
fi

# ── vpc ──────────────────────────────────────────────────────
if ! skip_if_done 3 "Criando VPC"; then
  step 3 "Criando VPC"
  cd "$TF_DIR/01-vpc"
  terraform init -input=false >> "$LOG_FILE" 2>&1
  terraform apply -auto-approve -input=false | tee -a "$LOG_FILE" | tail -5
  VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
  ok "VPC criada${VPC_ID:+ | ID: $VPC_ID}"
  checkpoint_done 3
fi

# ── eks ──────────────────────────────────────────────────────
if ! skip_if_done 4 "Criando cluster EKS (~15 min)"; then
  step 4 "Criando cluster EKS (~15 min)"
  cd "$TF_DIR/02-eks"
  terraform init -input=false >> "$LOG_FILE" 2>&1
  terraform apply -auto-approve -input=false | tee -a "$LOG_FILE" | tail -5
  ok "EKS criado"
  checkpoint_done 4
fi

# Sempre atualiza kubeconfig se EKS existe
CLUSTER_NAME=$(cd "$TF_DIR/02-eks" && terraform output -raw cluster_name 2>/dev/null || echo "eks-vision-2026")
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION" >> "$LOG_FILE" 2>&1 || true

# ── networking ───────────────────────────────────────────────
if ! skip_if_done 5 "Instalando NGINX Ingress + cert-manager + Route53"; then
  step 5 "Instalando NGINX Ingress + cert-manager + Route53"
  cd "$TF_DIR/03-networking"
  terraform init -input=false >> "$LOG_FILE" 2>&1
  terraform apply -auto-approve -input=false | tee -a "$LOG_FILE" | tail -5
  info "Aguardando NGINX Ingress LoadBalancer (~3 min)..."
  for i in $(seq 1 36); do
    LB=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
      -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    [ -n "$LB" ] && break
    sleep 5
    [ $((i % 6)) -eq 0 ] && info "Aguardando... ${i}x5s"
  done
  ok "Networking configurado"
  checkpoint_done 5
fi

# ── secrets ──────────────────────────────────────────────────
if ! skip_if_done 6 "Verificando secrets no AWS Secrets Manager"; then
  step 6 "Verificando secrets no AWS Secrets Manager"
  SECRET_ID="platform/lab/shared-config"
  if aws secretsmanager describe-secret --secret-id "$SECRET_ID" --region "$AWS_REGION" &>/dev/null; then
    ok "Secret '$SECRET_ID' encontrado"
  else
    fail "Secret '$SECRET_ID' não encontrado. Rode primeiro: ./setup.sh"
  fi
  checkpoint_done 6
fi

# ── platform ─────────────────────────────────────────────────
if ! skip_if_done 7 "Instalando plataforma (ArgoCD + Backstage + Crossplane + PostgreSQL)"; then
  step 7 "Instalando plataforma (ArgoCD + Backstage + Crossplane + PostgreSQL)"
  cd "$TF_DIR/04-platform"
  terraform init -input=false >> "$LOG_FILE" 2>&1
  terraform apply -auto-approve -input=false | tee -a "$LOG_FILE" | tail -5
  ok "Plataforma provisionada"
  info "Aguardando ArgoCD ficar pronto..."
  kubectl wait pod -l app.kubernetes.io/name=argocd-server \
    -n argocd --for=condition=Ready --timeout=300s
  ok "ArgoCD pronto"
  info "Aguardando Backstage ficar pronto..."
  kubectl rollout status deployment -n backstage --timeout=300s 2>/dev/null \
    || warn "Backstage ainda inicializando — verifique com: kubectl get pods -n backstage"
  info "Aguardando Crossplane ficar pronto..."
  kubectl wait pod -l app=crossplane \
    -n crossplane-system --for=condition=Ready --timeout=300s
  ok "Crossplane pronto"
  checkpoint_done 7
fi

# ── crossplane config ─────────────────────────────────────────
if ! skip_if_done 8 "Configurando Crossplane (Providers + XRDs + Compositions)"; then
  step 8 "Configurando Crossplane (Providers + XRDs + Compositions)"
  chmod +x "$SCRIPT_DIR/crossplane/install.sh"
  bash "$SCRIPT_DIR/crossplane/install.sh"
  ok "Crossplane configurado"
  checkpoint_done 8
fi

# ── kyverno ──────────────────────────────────────────────────
if ! skip_if_done 9 "Instalando Kyverno + políticas (guardrails)"; then
  step 9 "Instalando Kyverno + políticas (guardrails)"
  chmod +x "$SCRIPT_DIR/guardrails/kyverno/install.sh"
  bash "$SCRIPT_DIR/guardrails/kyverno/install.sh"
  ok "Kyverno instalado"
  checkpoint_done 9
fi

# ── gitops applicationsets ───────────────────────────────────
if ! skip_if_done 10 "Aplicando ArgoCD ApplicationSets"; then
  step 10 "Aplicando ArgoCD ApplicationSets"
  GITHUB_ORG="hugosleao"
  [ -f "$SCRIPT_DIR/.env.platform" ] && \
    GITHUB_ORG=$(grep "^GITHUB_ORG=" "$SCRIPT_DIR/.env.platform" | cut -d= -f2 || echo "hugosleao")
  info "Usando org GitHub: $GITHUB_ORG"
  for f in "$SCRIPT_DIR/gitops/appsets/"*.yaml; do
    sed "s|hugosleao|$GITHUB_ORG|g" "$f" | kubectl apply -f -
  done
  ok "ApplicationSets aplicados"
  checkpoint_done 10
fi

# ── platform api (operator) ──────────────────────────────────
if ! skip_if_done 11 "Deploy Platform Operator (Go + controller-runtime)"; then
  step 11 "Deploy Platform Operator (Go + controller-runtime)"
  ECR_REPO="$AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/platform-operator"

info "Aplicando CRDs..."
kubectl apply -f "$SCRIPT_DIR/platform-api/config/crd/"
kubectl wait --for condition=established --timeout=30s \
  crd/platformservices.platform.devopstia.com \
  crd/infrarequests.platform.devopstia.com

# Build da imagem via GitHub Actions (sem Docker local)
# Verifica se a imagem já existe no ECR
info "Verificando imagem no ECR..."
IMAGE_EXISTS=$(aws ecr describe-images \
  --repository-name platform-operator \
  --region "$AWS_REGION" \
  --query 'imageDetails[?contains(imageTags, `latest`)]' \
  --output text 2>/dev/null || echo "")

if [ -z "$IMAGE_EXISTS" ]; then
  warn "Imagem não encontrada no ECR."
  info "Disparando build via GitHub Actions..."

  # Verifica se gh CLI está disponível
  if command -v gh &>/dev/null; then
    gh workflow run build-operator.yaml \
      --repo "hugosleao/vision-2026" \
      -f aws_account_id="$AWS_ACCOUNT" \
      -f aws_region="$AWS_REGION" >> "$LOG_FILE" 2>&1 || true

    info "Aguardando build da imagem (GitHub Actions)..."
    sleep 30
    # Aguarda até 5 min pela imagem
    for i in $(seq 1 10); do
      IMAGE_EXISTS=$(aws ecr describe-images \
        --repository-name platform-operator \
        --region "$AWS_REGION" \
        --query 'imageDetails[?contains(imageTags, `latest`)]' \
        --output text 2>/dev/null || echo "")
      [ -n "$IMAGE_EXISTS" ] && break
      warn "Aguardando imagem ECR... tentativa $i/10"
      sleep 30
    done
  else
    warn "gh CLI não encontrado. Build manual necessário:"
    warn "  cd platform-api && gh workflow run build-operator.yaml"
    warn "  Ou push em master/develop dispara automaticamente"
    warn "Pulando deploy do operator — aplique manualmente após o build"
  fi
fi

  if [ -n "$IMAGE_EXISTS" ]; then
    info "Imagem encontrada no ECR. Deployando operator..."
    sed "s|ACCOUNT_ID|$AWS_ACCOUNT|g" "$SCRIPT_DIR/platform-api/k8s/deployment.yaml" | \
      kubectl apply -f -
    kubectl rollout status deployment/platform-operator -n platform --timeout=180s
    ok "Platform Operator rodando — https://platform-api.devopstia.com"
  else
    warn "Operator não deployado — imagem ainda não disponível no ECR"
    warn "Após o build, rode: ./scripts/deploy-operator.sh"
  fi
  checkpoint_done 11
fi

# ── observabilidade ───────────────────────────────────────────
if ! skip_if_done 12 "Instalando Observabilidade (Prometheus + Grafana)"; then
  step 12 "Instalando Observabilidade (Prometheus + Grafana)"
  chmod +x "$SCRIPT_DIR/observability/install.sh"
  bash "$SCRIPT_DIR/observability/install.sh"
  ok "Observabilidade instalada"
  checkpoint_done 12
fi

# ── validação final ───────────────────────────────────────────
step 13 "Validação final"

echo ""
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  ✅ DEPLOY COMPLETO!${NC}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""

# ── Coletar credenciais de acesso ─────────────────────────────
ARGOCD_PASS=$(kubectl get secret argocd-initial-admin-secret \
  -n argocd -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "N/A")

GRAFANA_PASS=$(kubectl get secret -n monitoring \
  $(kubectl get secret -n monitoring --no-headers -o custom-columns=":metadata.name" | grep grafana) \
  -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 -d || echo "prom-operator")

POSTGRES_PASS=$(kubectl get secret postgres-credentials \
  -n backstage -o jsonpath="{.data.POSTGRES_PASSWORD}" 2>/dev/null | base64 -d || echo "N/A")

PLATFORM_TOKEN=$(aws secretsmanager get-secret-value \
  --secret-id "platform/lab/shared-config" \
  --query "SecretString" --output text 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('PLATFORM_API_TOKEN','N/A'))" 2>/dev/null || echo "N/A")

# ── Exibir resultado final ─────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  ✅ DEPLOY COMPLETO — vision-2026${NC}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  ACESSOS E CREDENCIAIS                                    ║${NC}"
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
echo -e "${BOLD}║${NC}  PostgreSQL   Internal: postgresql.backstage.svc.cluster.local"
echo -e "${BOLD}║${NC}               Usuário : backstage"
echo -e "${BOLD}║${NC}               Senha   : ${YELLOW}$POSTGRES_PASS${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Validação rápida:${NC}"
echo -e "  ${CYAN}kubectl get pods -A${NC}                    # todos Running?"
echo -e "  ${CYAN}kubectl get certificates -A${NC}            # TLS Ready?"
echo -e "  ${CYAN}kubectl get clusterpolicies${NC}            # Kyverno ativo?"
echo -e "  ${CYAN}kubectl get applications -n argocd${NC}     # ArgoCD apps?"
echo -e "  ${CYAN}curl https://platform-api.devopstia.com/v1/health${NC}"
echo ""
echo -e "  Log completo: ${CYAN}$LOG_FILE${NC}"
echo ""
echo -e "${YELLOW}⚠️  DNS propagação pode levar até 5 min${NC}"
echo -e "${YELLOW}⚠️  Guarde as credenciais acima — não serão exibidas novamente${NC}"

checkpoint_done 13
# Remove checkpoint — deploy completo, próximo run começa do zero
rm -f "$CHECKPOINT_FILE"
info "Checkpoint removido — próximo deploy começa do zero"
