#!/bin/bash
set -e

echo "🔍 Validação Completa do Fix Kaniko ECR"
echo "========================================"
echo ""

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FALHOU${NC}"
        return 1
    fi
}

# 1. Pod Identity Agent
echo -n "1️⃣ Pod Identity Agent rodando: "
kubectl -n kube-system get pods | grep -q pod-identity-agent && check || check

# 2. Associação Pod Identity
echo -n "2️⃣ Associação Pod Identity existe: "
aws eks list-pod-identity-associations --cluster-name eks-mgmt --region us-east-1 2>/dev/null | grep -q kaniko-builder && check || check

# 3. Secret Docker Config
echo -n "3️⃣ Secret docker-config criado: "
kubectl -n backstage get secret kaniko-docker-config >/dev/null 2>&1 && check || check

# 4. ServiceAccount Kaniko
echo -n "4️⃣ ServiceAccount kaniko-builder: "
kubectl -n backstage get sa kaniko-builder >/dev/null 2>&1 && check || check

# 5. Build Job
echo ""
echo "5️⃣ Status do Build Job:"
kubectl -n backstage get jobs -l app=build-backstage-git 2>/dev/null || echo "   Nenhum job encontrado (ainda não rodou)"
echo ""

# 6. Imagem no ECR
echo -n "6️⃣ Imagem 'production' no ECR: "
aws ecr describe-images \
  --repository-name backstage-git \
  --region us-east-1 \
  --query 'imageDetails[?imageTags[?@ == `production`]].imagePushedAt' \
  --output text 2>/dev/null | grep -q . && check || check

# 7. Backstage deployment image
echo ""
echo "7️⃣ Imagem do Backstage deployment:"
kubectl -n backstage get deployment backstage -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "   Deployment ainda não existe"
echo ""
echo ""

# 8. Teste rápido AWS CLI no pod
echo "8️⃣ Teste AWS credentials (opcional):"
echo "   Para testar manualmente:"
echo -e "   ${YELLOW}kubectl run test-aws --rm -it --image=amazon/aws-cli:2 --serviceaccount=kaniko-builder -n backstage -- aws sts get-caller-identity${NC}"
echo ""

# Summary
echo "========================================"
echo "📊 Resumo:"
echo ""
echo "Se 1-6 estão OK: ✅ Fix aplicado corretamente"
echo "Se algum falhou: ❌ Ver FIX-KANIKO-CHECKLIST.md"
echo ""
echo "📖 Próximos passos:"
echo "   1. Aguardar build completar (~3-5min)"
echo "   2. Verificar logs: kubectl logs -n backstage -l app=build-backstage-git -f"
echo "   3. Testar Backstage: kubectl port-forward -n backstage svc/backstage 7007:7007"
echo ""
