#!/bin/bash
# Deploy manual do Platform Operator após build da imagem no ECR
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

echo "Deployando Platform Operator..."
sed "s|ACCOUNT_ID|$AWS_ACCOUNT|g" "$SCRIPT_DIR/platform-api/k8s/deployment.yaml" | \
  kubectl apply -f -

kubectl apply -f "$SCRIPT_DIR/platform-api/config/crd/"
kubectl rollout status deployment/platform-operator -n platform --timeout=180s

echo "✅ Operator rodando: https://platform-api.devopstia.com/v1/health"
