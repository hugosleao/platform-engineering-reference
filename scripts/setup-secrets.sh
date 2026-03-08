#!/bin/bash
set -e
# ==========================================
# Setup GitHub Secrets no AWS Secrets Manager
# ==========================================

echo "🔐 Configuração de Secrets no AWS Secrets Manager"
echo ""
echo "Você precisa de:"
echo "  1. GitHub Personal Access Token (PAT)"
echo "  2. GitHub OAuth App (Client ID + Secret)"
echo "  3. AWS CLI autenticado"
echo ""

# ==========================================
# GitHub PAT
# ==========================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1️⃣  GitHub Personal Access Token (PAT)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Acesse: https://github.com/settings/tokens/new"
echo ""
echo "Permissions necessárias:"
echo "  ✓ repo (all)"
echo "  ✓ workflow"
echo "  ✓ admin:org (read:org)"
echo "  ✓ user (read:user, user:email)"
echo ""
read -sp "Cole seu GitHub PAT: " GITHUB_TOKEN
echo ""
echo ""

# ==========================================
# GitHub OAuth App
# ==========================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣  GitHub OAuth App"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Acesse: https://github.com/settings/applications/new"
echo ""
echo "Configuração:"
echo "  Application name: Backstage Lab"
echo "  Homepage URL: https://backstage.devopstia.com"
echo "  Authorization callback URL: https://backstage.devopstia.com/api/auth/github/handler/frame"
echo ""
read -p "Cole Client ID: " GITHUB_CLIENT_ID
read -sp "Cole Client Secret: " GITHUB_CLIENT_SECRET
echo ""
echo ""

# ==========================================
# Secret Manager
# ==========================================

DEFAULT_SECRET_ID="backstage/github-lab"
read -p "Nome/ARN do secret [${DEFAULT_SECRET_ID}]: " GITHUB_SECRETS_MANAGER_SECRET_ID
GITHUB_SECRETS_MANAGER_SECRET_ID=${GITHUB_SECRETS_MANAGER_SECRET_ID:-$DEFAULT_SECRET_ID}

SECRET_PAYLOAD=$(cat <<EOF
{"github_token":"$GITHUB_TOKEN","github_client_id":"$GITHUB_CLIENT_ID","github_client_secret":"$GITHUB_CLIENT_SECRET"}
EOF
)

if aws secretsmanager describe-secret --secret-id "$GITHUB_SECRETS_MANAGER_SECRET_ID" >/dev/null 2>&1; then
  aws secretsmanager put-secret-value \
    --secret-id "$GITHUB_SECRETS_MANAGER_SECRET_ID" \
    --secret-string "$SECRET_PAYLOAD" >/dev/null
  echo "✅ Secret atualizado: $GITHUB_SECRETS_MANAGER_SECRET_ID"
else
  aws secretsmanager create-secret \
    --name "$GITHUB_SECRETS_MANAGER_SECRET_ID" \
    --secret-string "$SECRET_PAYLOAD" >/dev/null
  echo "✅ Secret criado: $GITHUB_SECRETS_MANAGER_SECRET_ID"
fi

# ==========================================
# Criar terraform.tfvars
# ==========================================

TFVARS_FILE="04-platform/terraform.tfvars"

cat > "$TFVARS_FILE" <<EOF
github_secrets_manager_secret_id = "$GITHUB_SECRETS_MANAGER_SECRET_ID"
EOF

chmod 600 "$TFVARS_FILE"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Secrets configurados!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Arquivo criado: $TFVARS_FILE"
echo "Secret Manager: $GITHUB_SECRETS_MANAGER_SECRET_ID"
echo ""
echo "⚠️  IMPORTANTE: Não commitar este arquivo!"
echo ""
echo "Próximo passo:"
echo "  ./deploy.sh"
echo ""
