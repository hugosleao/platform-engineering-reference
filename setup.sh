#!/bin/bash
# ============================================================
# vision-2026 — SETUP AUTOMÁTICO
# Zero interação para tudo que pode ser detectado.
# Só pede credenciais do GitHub App (impossível auto-detectar).
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/infra"

ok()   { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
info() { echo -e "${CYAN}→  $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; exit 1; }
ask()  { echo -e "${CYAN}$1${NC}"; }

# ── Carrega .env.secrets se existir (zero export manual) ─────
ENV_FILE="$SCRIPT_DIR/.env.secrets"
if [ -f "$ENV_FILE" ]; then
  set -o allexport
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +o allexport
  ok "Credenciais carregadas de .env.secrets"
else
  info "Dica: crie .env.secrets para rodar sem nenhuma pergunta"
  info "  cp .env.secrets.example .env.secrets && vim .env.secrets"
fi

echo -e "${BOLD}${BLUE}"
echo "╔══════════════════════════════════════════╗"
echo "║   vision-2026 — Setup Automático         ║"
echo "║   Detecção máxima, interação mínima      ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ── 1. AWS — detecta tudo automaticamente ────────────────────
echo -e "${BOLD}[1/4] Detectando ambiente AWS...${NC}"

AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) \
  || fail "AWS CLI não autenticado."
AWS_REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")
AWS_USER=$(aws sts get-caller-identity --query 'Arn' --output text | awk -F'/' '{print $NF}')

ok "Conta: $AWS_ACCOUNT | Região: $AWS_REGION | User: $AWS_USER"

# Auto-detecta S3 bucket de tfstate (prefere os existentes)
PREFERRED_BUCKETS=("cluster-kubernetes-tf-state-files" "devopstia-containers-statefiles")
TF_STATE_BUCKET=""
for b in "${PREFERRED_BUCKETS[@]}"; do
  if aws s3api head-bucket --bucket "$b" 2>/dev/null; then
    TF_STATE_BUCKET="$b"
    break
  fi
done
if [ -z "$TF_STATE_BUCKET" ]; then
  # Pega o primeiro bucket que contenha "state" ou "tf" no nome
  TF_STATE_BUCKET=$(aws s3 ls | awk '{print $3}' | grep -E "state|tfstate|terraform" | head -1 || echo "")
fi
if [ -z "$TF_STATE_BUCKET" ]; then
  TF_STATE_BUCKET="vision-2026-tfstate-$AWS_ACCOUNT"
  info "Nenhum bucket de tfstate encontrado — será criado: $TF_STATE_BUCKET"
fi
ok "S3 tfstate: $TF_STATE_BUCKET"

# Auto-detecta DynamoDB de lock
PREFERRED_TABLES=("cluster-kubernetes-tf-state-locking" "devopstia-terraform-lock" "hugosleao-terraform-locks")
TF_LOCK_TABLE=""
for t in "${PREFERRED_TABLES[@]}"; do
  if aws dynamodb describe-table --table-name "$t" --region "$AWS_REGION" &>/dev/null; then
    TF_LOCK_TABLE="$t"
    break
  fi
done
if [ -z "$TF_LOCK_TABLE" ]; then
  TF_LOCK_TABLE=$(aws dynamodb list-tables --region "$AWS_REGION" \
    --query 'TableNames[?contains(@, `lock`) || contains(@, `terraform`)]' \
    --output text | awk '{print $1}' | head -1 || echo "")
fi
if [ -z "$TF_LOCK_TABLE" ]; then
  TF_LOCK_TABLE="vision-2026-tf-locks"
  info "Nenhuma tabela de lock encontrada — será criada: $TF_LOCK_TABLE"
fi
ok "DynamoDB lock: $TF_LOCK_TABLE"

# Auto-detecta hosted zone Route53 para devopstia.com
DOMAIN_NAME=$(aws route53 list-hosted-zones \
  --query 'HostedZones[0].Name' --output text 2>/dev/null | sed 's/\.$//' || echo "devopstia.com")
ok "Domínio Route53: $DOMAIN_NAME"

# Defaults automáticos
CLUSTER_NAME="eks-vision-2026"
PROJECT_NAME="vision-2026"
GITOPS_REPO="gitops-repo"

# Auto-detecta GitHub owner do git config ou gh CLI
GITHUB_ORG=$(gh api user --jq '.login' 2>/dev/null || git config github.user 2>/dev/null || echo "hugosleao")
ok "GitHub Org: $GITHUB_ORG"

# ── 2. GitHub App — única interação obrigatória ───────────────
echo ""
echo -e "${BOLD}[2/4] Credenciais do GitHub App${NC}"
echo -e "${YELLOW}Única parte que não pode ser auto-detectada.${NC}"
echo -e "Acesse: ${CYAN}https://github.com/settings/apps${NC}\n"
echo -e "Permissões necessárias: Contents(R/W), Metadata(R), Administration(R/W), Workflows(R/W)"
echo -e "Callback URL: ${CYAN}https://backstage.$DOMAIN_NAME/api/auth/github/handler/frame${NC}\n"

# Aceita via env var para automação total (ex: CI)
if [ -z "${GITHUB_APP_ID:-}" ]; then
  ask "GitHub App ID: "; read -r GITHUB_APP_ID
fi
if [ -z "${GITHUB_INSTALLATION_ID:-}" ]; then
  ask "GitHub Installation ID: "; read -r GITHUB_INSTALLATION_ID
fi
if [ -z "${GITHUB_CLIENT_ID:-}" ]; then
  ask "GitHub App Client ID (OAuth): "; read -r GITHUB_CLIENT_ID
fi
if [ -z "${GITHUB_CLIENT_SECRET:-}" ]; then
  ask "GitHub App Client Secret (OAuth): "; read -r -s GITHUB_CLIENT_SECRET; echo ""
fi

# PEM — aceita arquivo ou env var
PEM_PATH="${GITHUB_PEM_PATH:-$SCRIPT_DIR/platform-api/github-app.pem}"
if [ ! -f "$PEM_PATH" ]; then
  warn "Arquivo .pem não encontrado em $PEM_PATH"
  ask "Cole o conteúdo do .pem (ENTER em linha vazia para finalizar):"
  PEM_CONTENT=""
  while IFS= read -r line; do
    [[ -z "$line" ]] && break
    PEM_CONTENT="${PEM_CONTENT}${line}\n"
  done
  mkdir -p "$(dirname "$PEM_PATH")"
  printf "%b" "$PEM_CONTENT" > "$PEM_PATH"
  chmod 600 "$PEM_PATH"
  ok "github-app.pem salvo em $PEM_PATH"
fi

# Gera secrets automáticos
PLATFORM_API_TOKEN=$(openssl rand -hex 32)
GITHUB_WEBHOOK_SECRET=$(openssl rand -hex 20)
ok "PLATFORM_API_TOKEN gerado automaticamente"
ok "GITHUB_WEBHOOK_SECRET gerado automaticamente"

# ── 3. Gera terraform.tfvars em todos os módulos ─────────────
echo -e "\n${BOLD}[3/4] Gerando terraform.tfvars...${NC}"

# Garante que S3 e DynamoDB existem
if ! aws s3api head-bucket --bucket "$TF_STATE_BUCKET" 2>/dev/null; then
  info "Criando S3 bucket: $TF_STATE_BUCKET"
  aws s3api create-bucket --bucket "$TF_STATE_BUCKET" --region "$AWS_REGION" \
    $([ "$AWS_REGION" != "us-east-1" ] && echo "--create-bucket-configuration LocationConstraint=$AWS_REGION") \
    > /dev/null
  aws s3api put-bucket-versioning --bucket "$TF_STATE_BUCKET" \
    --versioning-configuration Status=Enabled
  ok "Bucket criado: $TF_STATE_BUCKET"
fi

if ! aws dynamodb describe-table --table-name "$TF_LOCK_TABLE" --region "$AWS_REGION" &>/dev/null; then
  info "Criando DynamoDB table: $TF_LOCK_TABLE"
  aws dynamodb create-table \
    --table-name "$TF_LOCK_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$AWS_REGION" > /dev/null
  aws dynamodb wait table-exists --table-name "$TF_LOCK_TABLE" --region "$AWS_REGION"
  ok "Tabela criada: $TF_LOCK_TABLE"
fi

# Atualiza o backend em todos os módulos com os valores reais
for MODULE in 01-vpc 02-eks 03-networking 04-platform; do
  MAIN_TF="$TF_DIR/$MODULE/main.tf"
  if [ -f "$MAIN_TF" ]; then
    sed -i.bak \
      -e "s|bucket\s*=\s*\"[^\"]*\"|bucket         = \"$TF_STATE_BUCKET\"|g" \
      -e "s|dynamodb_table\s*=\s*\"[^\"]*\"|dynamodb_table = \"$TF_LOCK_TABLE\"|g" \
      -e "s|region\s*=\s*\"[^\"]*\"\s*#\s*backend|region         = \"$AWS_REGION\" # backend|g" \
      "$MAIN_TF"
    rm -f "${MAIN_TF}.bak"
  fi
done
ok "Backends atualizados: $TF_STATE_BUCKET / $TF_LOCK_TABLE"

# terraform.tfvars
cat > "$TF_DIR/00-backend/terraform.tfvars" <<EOF
aws_region   = "$AWS_REGION"
project_name = "$PROJECT_NAME"
owner        = "$GITHUB_ORG"
EOF

cat > "$TF_DIR/01-vpc/terraform.tfvars" <<EOF
aws_region   = "$AWS_REGION"
project_name = "$PROJECT_NAME"
environment  = "lab"
owner        = "$GITHUB_ORG"
EOF

cat > "$TF_DIR/02-eks/terraform.tfvars" <<EOF
aws_region   = "$AWS_REGION"
project_name = "$PROJECT_NAME"
environment  = "lab"
owner        = "$GITHUB_ORG"
cluster_name = "$CLUSTER_NAME"
EOF

cat > "$TF_DIR/03-networking/terraform.tfvars" <<EOF
aws_region   = "$AWS_REGION"
project_name = "$PROJECT_NAME"
environment  = "lab"
owner        = "$GITHUB_ORG"
domain_name  = "$DOMAIN_NAME"
cluster_name = "$CLUSTER_NAME"
EOF

cat > "$TF_DIR/04-platform/terraform.tfvars" <<EOF
aws_region                       = "$AWS_REGION"
project_name                     = "$PROJECT_NAME"
environment                      = "lab"
owner                            = "$GITHUB_ORG"
domain_name                      = "$DOMAIN_NAME"
github_secrets_manager_secret_id = "platform/lab/shared-config"
EOF

ok "terraform.tfvars gerados em todos os módulos"

# ── 4. Secrets Manager + repos GitHub ────────────────────────
echo -e "\n${BOLD}[4/4] Configurando secrets e repos GitHub...${NC}"

SECRET_NAME="platform/lab/shared-config"
SECRET_VALUE=$(python3 -c "
import json
data = {
  'GITHUB_APP_ID':           '$GITHUB_APP_ID',
  'GITHUB_INSTALLATION_ID':  '$GITHUB_INSTALLATION_ID',
  'GITHUB_ORG':              '$GITHUB_ORG',
  'GITHUB_APP_PRIVATE_KEY':  open('$PEM_PATH').read(),
  'PLATFORM_API_TOKEN':      '$PLATFORM_API_TOKEN',
  'GITOPS_REPO':             '$GITOPS_REPO',
  'GITHUB_CLIENT_ID':        '$GITHUB_CLIENT_ID',
  'GITHUB_CLIENT_SECRET':    '$GITHUB_CLIENT_SECRET',
  'GITHUB_WEBHOOK_SECRET':   '$GITHUB_WEBHOOK_SECRET',
}
print(json.dumps(data))
")

if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$AWS_REGION" &>/dev/null; then
  aws secretsmanager put-secret-value \
    --secret-id "$SECRET_NAME" --secret-string "$SECRET_VALUE" \
    --region "$AWS_REGION" > /dev/null
  ok "Secret atualizado: $SECRET_NAME"
else
  aws secretsmanager create-secret \
    --name "$SECRET_NAME" \
    --description "vision-2026 platform shared config" \
    --secret-string "$SECRET_VALUE" \
    --region "$AWS_REGION" > /dev/null
  ok "Secret criado: $SECRET_NAME"
fi

# Cria repos GitHub necessários
if command -v gh &>/dev/null; then
  for REPO in "gitops-repo:private:GitOps manifests — vision-2026" "platform-templates:public:Backstage platform templates — vision-2026"; do
    REPO_NAME="${REPO%%:*}"; REST="${REPO#*:}"; VISIBILITY="${REST%%:*}"; DESC="${REST#*:}"
    if gh repo view "$GITHUB_ORG/$REPO_NAME" &>/dev/null 2>&1; then
      ok "Repo $GITHUB_ORG/$REPO_NAME já existe"
    else
      gh repo create "$GITHUB_ORG/$REPO_NAME" \
        "--$VISIBILITY" --description "$DESC" --add-readme > /dev/null
      ok "Repo criado: $GITHUB_ORG/$REPO_NAME"
    fi
  done

  # Estrutura do gitops-repo
  for ENV in dev hml prd; do
    gh api "repos/$GITHUB_ORG/gitops-repo/contents/clusters/$ENV/.gitkeep" \
      -X PUT -f message="chore: init $ENV" \
      -f content="$(printf '' | base64)" &>/dev/null || true
  done

  # all-templates.yaml no platform-templates
  ALL_TMPL=$(base64 <<'YAML'
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: platform-templates
spec:
  targets:
    - ./new-service/template.yaml
    - ./python-api/template.yaml
YAML
)
  gh api "repos/$GITHUB_ORG/platform-templates/contents/all-templates.yaml" \
    -X PUT -f message="chore: add template index" \
    -f content="$ALL_TMPL" &>/dev/null || true
  ok "Estrutura de repos criada"
else
  warn "gh CLI não instalado — crie manualmente: $GITHUB_ORG/gitops-repo e $GITHUB_ORG/platform-templates"
fi

# .env.platform — referência local (não commitar)
cat > "$SCRIPT_DIR/.env.platform" <<EOF
# Gerado pelo setup.sh — não commitar
AWS_ACCOUNT=$AWS_ACCOUNT
AWS_REGION=$AWS_REGION
CLUSTER_NAME=$CLUSTER_NAME
DOMAIN_NAME=$DOMAIN_NAME
TF_STATE_BUCKET=$TF_STATE_BUCKET
TF_LOCK_TABLE=$TF_LOCK_TABLE
GITHUB_APP_ID=$GITHUB_APP_ID
GITHUB_INSTALLATION_ID=$GITHUB_INSTALLATION_ID
GITHUB_ORG=$GITHUB_ORG
GITOPS_REPO=$GITOPS_REPO
PLATFORM_API_TOKEN=$PLATFORM_API_TOKEN
SECRET_NAME=$SECRET_NAME
EOF
chmod 600 "$SCRIPT_DIR/.env.platform"
ok ".env.platform salvo (chmod 600)"

# ── Resumo ────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  ✅ SETUP COMPLETO — zero configuração manual!${NC}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
printf "  %-20s %s\n" "Conta AWS:"     "$AWS_ACCOUNT"
printf "  %-20s %s\n" "Região:"        "$AWS_REGION"
printf "  %-20s %s\n" "Cluster:"       "$CLUSTER_NAME"
printf "  %-20s %s\n" "Domínio:"       "$DOMAIN_NAME"
printf "  %-20s %s\n" "S3 tfstate:"    "$TF_STATE_BUCKET"
printf "  %-20s %s\n" "DynamoDB lock:" "$TF_LOCK_TABLE"
printf "  %-20s %s\n" "GitHub Org:"    "$GITHUB_ORG"
printf "  %-20s %s\n" "Secret AWS:"    "$SECRET_NAME"
echo ""
echo -e "${BOLD}Próximo passo:${NC} ${CYAN}./deploy.sh${NC}"
echo ""
echo -e "${YELLOW}PLATFORM_API_TOKEN salvo em .env.platform e no Secrets Manager${NC}"
