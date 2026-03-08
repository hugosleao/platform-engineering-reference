#!/bin/bash
set -e

echo "🗑️ Cleanup completo para destravar destroy"
echo "==========================================="
echo ""

# 1. Deletar Ingress Kubernetes
echo "1️⃣ Deletando Ingress resources..."
kubectl delete ingress --all -n backstage 2>/dev/null || true
kubectl delete ingress --all -n argocd 2>/dev/null || true
echo "✅ Ingress deletados"
echo ""

# 2. Aguardar ALBs serem removidos
echo "2️⃣ Aguardando AWS remover ALBs (pode levar 2-3min)..."
sleep 30

# Verificar ALBs
echo "   Verificando ALBs restantes..."
ALB_COUNT=$(aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --query "LoadBalancers[?VpcId=='vpc-0a242e170ec2f95f6'].LoadBalancerArn" \
  --output text 2>/dev/null | wc -l || echo "0")

if [ "$ALB_COUNT" -gt 0 ]; then
  echo "   ⚠️  Ainda existem $ALB_COUNT ALB(s). Aguardando mais 60s..."
  sleep 60
else
  echo "   ✅ Nenhum ALB encontrado"
fi
echo ""

# 3. Deletar ENIs órfãs (se houver)
echo "3️⃣ Verificando ENIs órfãs..."
ENIS=$(aws ec2 describe-network-interfaces \
  --region us-east-1 \
  --filters "Name=vpc-id,Values=vpc-0a242e170ec2f95f6" \
  --query "NetworkInterfaces[?Status=='available'].NetworkInterfaceId" \
  --output text 2>/dev/null || echo "")

if [ -n "$ENIS" ]; then
  echo "   Deletando ENIs órfãs: $ENIS"
  for ENI in $ENIS; do
    aws ec2 delete-network-interface --network-interface-id $ENI --region us-east-1 2>/dev/null || true
  done
  echo "   ✅ ENIs deletadas"
else
  echo "   ✅ Nenhuma ENI órfã"
fi
echo ""

# 4. Retry destroy
echo "4️⃣ Tentando destroy novamente..."
cd /Users/hugoleao/crossplane/lab-ativo/infra/terraform/01-management
terraform destroy -auto-approve

echo ""
echo "==========================================="
echo "✅ Destroy completo!"
echo ""
