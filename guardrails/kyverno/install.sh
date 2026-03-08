#!/bin/bash
set -e

echo "📦 Instalando Kyverno..."
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --set admissionController.replicas=1 \
  --wait --timeout 5m

echo "⏳ Aguardando Kyverno..."
kubectl wait pod -l app.kubernetes.io/instance=kyverno \
  -n kyverno --for=condition=Ready --timeout=120s

echo "📋 Aplicando políticas..."
kubectl apply -f "$(dirname "$0")/"*.yaml

echo "✅ Kyverno + políticas aplicadas!"
kubectl get clusterpolicies
