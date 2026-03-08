#!/bin/bash
set -e

echo "📦 Instalando kube-prometheus-stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.ingress.enabled=true \
  --set grafana.ingress.ingressClassName=nginx \
  --set "grafana.ingress.hosts[0]=grafana.devopstia.com" \
  --set "grafana.ingress.tls[0].secretName=grafana-tls" \
  --set "grafana.ingress.tls[0].hosts[0]=grafana.devopstia.com" \
  --set "grafana.ingress.annotations.cert-manager\\.io/cluster-issuer=letsencrypt-prod" \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --wait --timeout 10m

echo "📋 Aplicando ServiceMonitor Platform API..."
kubectl apply -f "$(dirname "$0")/prometheus/servicemonitor.yaml"

echo "✅ Observabilidade instalada!"
echo "Grafana: https://grafana.devopstia.com (admin/prom-operator)"
