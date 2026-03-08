#!/bin/bash
set -e

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-us-east-1}

echo "📦 Instalando Crossplane AWS Provider..."
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-s3
spec:
  package: xpkg.upbound.io/upbound/provider-aws-s3:v1
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-rds
spec:
  package: xpkg.upbound.io/upbound/provider-aws-rds:v1
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-sqs
spec:
  package: xpkg.upbound.io/upbound/provider-aws-sqs:v1
EOF

echo "⏳ Aguardando providers ficarem healthy..."
kubectl wait provider/provider-aws-s3 --for=condition=Healthy --timeout=300s
kubectl wait provider/provider-aws-rds --for=condition=Healthy --timeout=300s
kubectl wait provider/provider-aws-sqs --for=condition=Healthy --timeout=300s

echo "🔑 Configurando ProviderConfig (Pod Identity)..."
cat <<EOF | kubectl apply -f -
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
EOF

echo "📋 Aplicando XRDs..."
kubectl apply -f "$(dirname "$0")/xrds/"

echo "⏳ Aguardando XRDs serem estabelecidas..."
sleep 10
kubectl wait xrd/xrdsinstances.platform.devopstia.com --for=condition=Established --timeout=60s
kubectl wait xrd/xs3buckets.platform.devopstia.com --for=condition=Established --timeout=60s
kubectl wait xrd/xsqsqueues.platform.devopstia.com --for=condition=Established --timeout=60s

echo "📋 Aplicando Compositions..."
kubectl apply -f "$(dirname "$0")/compositions/"

echo "✅ Crossplane configurado!"
