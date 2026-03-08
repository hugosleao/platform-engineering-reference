#!/bin/bash
# ============================================================
# vision-2026 — MASTER DESTROY
# Ordem correta respeitando dependências AWS:
#
#  1. Para operator (evita reconcile durante destroy)
#  2. CRs com finalizers (PlatformService, InfraRequest)
#  3. Crossplane Claims → espera AWS deletar RDS/S3/SQS
#  4. Crossplane Providers (só após MRs zerados)
#  5. ArgoCD Apps/AppSets (para sync)
#  6. PVCs → espera EBS ser deletado do AWS
#  7. NGINX Ingress → espera ELB sumir do AWS (crítico para VPC)
#  8. terraform destroy 04-platform
#  9. terraform destroy 03-networking
# 10. ECR cleanup → terraform destroy 02-eks
# 11. terraform destroy 01-vpc
# 12. (opcional) terraform destroy 00-backend
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/infra"
LOG_FILE="$SCRIPT_DIR/destroy-$(date +%Y%m%d-%H%M%S).log"
TOTAL_STEPS=12

step()  { echo -e "\n${RED}${BOLD}[$1/$TOTAL_STEPS] $2${NC}"; }
ok()    { echo -e "${GREEN}✅ $1${NC}"; }
warn()  { echo -e "${YELLOW}⚠️  $1${NC}"; }
info()  { echo -e "${CYAN}   $1${NC}"; }

echo -e "${RED}${BOLD}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║          ⚠️  DESTROY COMPLETO — vision-2026         ║"
echo "║  Isso vai destruir TUDO incluindo recursos na AWS   ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
read -rp "Digite DESTROY para confirmar: " CONFIRM
[[ "$CONFIRM" == "DESTROY" ]] || { echo "Abortado."; exit 0; }

AWS_REGION=${AWS_REGION:-$(grep "^aws_region" "$TF_DIR/01-vpc/terraform.tfvars" 2>/dev/null \
  | cut -d'"' -f2 || echo "us-east-1")}
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)

# Verifica se kubectl está apontando para o cluster
CLUSTER_OK=false
if kubectl get nodes &>/dev/null 2>&1; then
  CLUSTER_OK=true
else
  warn "kubectl não conectado ao cluster — pulando steps de kubectl"
fi

# ── helper: aguarda ELB ser deletado da AWS ───────────────────
wait_elb_gone() {
  info "Aguardando ELBs do cluster sumirem da AWS (~3 min)..."
  for i in $(seq 1 36); do
    COUNT=$(aws elb describe-load-balancers --region "$AWS_REGION" \
      --query "LoadBalancerDescriptions[?contains(LoadBalancerName,'k8s')].LoadBalancerName" \
      --output text 2>/dev/null | wc -w || echo 0)
    NLB=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" \
      --query "LoadBalancers[?contains(LoadBalancerName,'k8s')].LoadBalancerArn" \
      --output text 2>/dev/null | wc -w || echo 0)
    TOTAL=$((COUNT + NLB))
    [ "$TOTAL" -eq 0 ] && { ok "ELBs removidos da AWS"; return 0; }
    [ $((i % 6)) -eq 0 ] && info "Aguardando ELBs... ${i}x5s (restam ~$TOTAL)"
    sleep 5
  done
  warn "Timeout aguardando ELBs — o destroy da VPC pode falhar"
}

# ── helper: aguarda EBS orphans da PVC sumirem ───────────────
wait_ebs_gone() {
  local ns=$1
  info "Aguardando EBS volumes da namespace $ns serem deletados..."
  for i in $(seq 1 24); do
    COUNT=$(aws ec2 describe-volumes --region "$AWS_REGION" \
      --filters "Name=tag:kubernetes.io/created-for/pvc/namespace,Values=$ns" \
      --query 'Volumes[?State!=`deleted`].VolumeId' \
      --output text 2>/dev/null | wc -w || echo 0)
    [ "$COUNT" -eq 0 ] && { ok "EBS volumes removidos"; return 0; }
    [ $((i % 6)) -eq 0 ] && info "Aguardando EBS... ${i}x5s (restam $COUNT volumes)"
    sleep 5
  done
  warn "Timeout aguardando EBS — verifique manualmente após o destroy"
}

# ── 1. Para Platform Operator ────────────────────────────────
step 1 "Parando Platform Operator (evita reconcile durante destroy)"
if $CLUSTER_OK; then
  kubectl scale deployment platform-operator -n platform --replicas=0 \
    >> "$LOG_FILE" 2>&1 || true
  ok "Platform Operator parado"
else
  warn "Pulando — cluster não acessível"
fi

# ── 2. Remove CRs com finalizers ─────────────────────────────
step 2 "Removendo CRs com finalizers (PlatformService, InfraRequest)"
if $CLUSTER_OK; then
  # Remove finalizers antes de deletar para não travar
  for crd in platformservices infrarequests; do
    for cr in $(kubectl get "$crd.platform.devopstia.com" \
        --all-namespaces --no-headers -o name 2>/dev/null || true); do
      kubectl patch "$cr" --type=json \
        -p='[{"op":"remove","path":"/metadata/finalizers"}]' \
        >> "$LOG_FILE" 2>&1 || true
    done
  done
  kubectl delete platformservices.platform.devopstia.com \
    --all --all-namespaces >> "$LOG_FILE" 2>&1 || true
  kubectl delete infrarequests.platform.devopstia.com \
    --all --all-namespaces >> "$LOG_FILE" 2>&1 || true
  ok "CRs removidos"
else
  warn "Pulando — cluster não acessível"
fi

# ── 3. Crossplane Claims → aguarda AWS deletar recursos ──────
step 3 "Removendo Claims Crossplane e aguardando AWS deletar recursos"
if $CLUSTER_OK; then
  warn "Deletando Claims — RDS/S3/SQS serão destruídos na AWS"

  # Remove finalizers de todos os managed resources Crossplane
  for mr in $(kubectl get managed --all-namespaces --no-headers -o name \
      2>/dev/null || true); do
    kubectl patch "$mr" --type=json \
      -p='[{"op":"remove","path":"/metadata/finalizers"}]' \
      >> "$LOG_FILE" 2>&1 || true
  done

  # Deleta XR Claims (nomes comuns Crossplane)
  for kind in rdsinstances s3buckets sqsqueues xpostgresqlinstances \
              composites claims; do
    kubectl delete "$kind" --all --all-namespaces \
      >> "$LOG_FILE" 2>&1 || true
  done

  info "Aguardando AWS deletar recursos provisionados pelo Crossplane (~3 min)..."
  sleep 30
  for i in $(seq 1 18); do
    COUNT=$(kubectl get managed --all-namespaces --no-headers \
      2>/dev/null | wc -l || echo 0)
    [ "$COUNT" -eq 0 ] && break
    info "Aguardando managed resources... ${i}/18 (restam $COUNT)"
    sleep 10
  done
  ok "Recursos Crossplane removidos da AWS"
else
  warn "Pulando — cluster não acessível"
fi

# ── 4. ArgoCD ApplicationSets e Applications ─────────────────
step 4 "Parando ArgoCD (ApplicationSets + Applications)"
if $CLUSTER_OK; then
  kubectl delete applicationsets --all -n argocd >> "$LOG_FILE" 2>&1 || true
  kubectl delete applications    --all -n argocd >> "$LOG_FILE" 2>&1 || true
  ok "ArgoCD sync parado"
else
  warn "Pulando — cluster não acessível"
fi

# ── 5. Crossplane Providers (só após MRs zerados) ────────────
step 5 "Removendo Crossplane Providers e ProviderConfigs"
if $CLUSTER_OK; then
  kubectl delete providerconfigs --all --all-namespaces \
    >> "$LOG_FILE" 2>&1 || true
  kubectl delete providers       --all --all-namespaces \
    >> "$LOG_FILE" 2>&1 || true
  # Aguarda providers sumirem
  for i in $(seq 1 12); do
    COUNT=$(kubectl get providers --all-namespaces --no-headers \
      2>/dev/null | wc -l || echo 0)
    [ "$COUNT" -eq 0 ] && break
    sleep 5
  done
  ok "Providers removidos"
else
  warn "Pulando — cluster não acessível"
fi

# ── 6. Kyverno policies ───────────────────────────────────────
step 6 "Removendo Kyverno (policies antes do controller)"
if $CLUSTER_OK; then
  kubectl delete clusterpolicies --all >> "$LOG_FILE" 2>&1 || true
  kubectl delete policies --all --all-namespaces >> "$LOG_FILE" 2>&1 || true
  ok "Kyverno policies removidas"
else
  warn "Pulando — cluster não acessível"
fi

# ── 7. PVCs → espera EBS sumir da AWS ────────────────────────
step 7 "Deletando PVCs (EBS volumes PostgreSQL)"
if $CLUSTER_OK; then
  kubectl delete pvc --all -n backstage >> "$LOG_FILE" 2>&1 || true
  wait_ebs_gone "backstage"
else
  warn "Pulando — cluster não acessível"
fi

# ── 8. NGINX Ingress → espera ELB sumir da AWS ──────────────
step 8 "Deletando Ingress e aguardando ELB sumir da AWS (crítico para VPC)"
if $CLUSTER_OK; then
  # Deleta todos os Ingress objects (isso instrui o controller a remover o ELB)
  kubectl delete ingress --all --all-namespaces >> "$LOG_FILE" 2>&1 || true
  # Deleta o service LoadBalancer do NGINX (remove o ELB)
  kubectl delete svc ingress-nginx-controller -n ingress-nginx \
    >> "$LOG_FILE" 2>&1 || true
  wait_elb_gone
else
  warn "Pulando kubectl — verificando ELBs diretamente na AWS..."
  wait_elb_gone
fi

# ── 9. terraform destroy 04-platform ────────────────────────
step 9 "Destruindo plataforma via Terraform (ArgoCD, Backstage, Crossplane, PostgreSQL)"
cd "$TF_DIR/04-platform"
terraform init -input=false -reconfigure >> "$LOG_FILE" 2>&1
terraform destroy -auto-approve -input=false 2>&1 | tee -a "$LOG_FILE" | tail -8
ok "04-platform destruído"

# ── 10. terraform destroy 03-networking ─────────────────────
step 10 "Destruindo networking (NGINX + cert-manager + Route53)"
cd "$TF_DIR/03-networking"
terraform init -input=false -reconfigure >> "$LOG_FILE" 2>&1
terraform destroy -auto-approve -input=false 2>&1 | tee -a "$LOG_FILE" | tail -8
ok "03-networking destruído"

# ── ECR cleanup → terraform destroy 02-eks ──────────────────
step 11 "Limpando ECR e destruindo EKS (~15 min)"

# ECR com imagens bloqueia terraform destroy — limpa primeiro
for repo in platform-operator backstage; do
  if aws ecr describe-repositories --repository-names "$repo" \
      --region "$AWS_REGION" &>/dev/null 2>&1; then
    info "Limpando imagens do ECR: $repo"
    aws ecr batch-delete-image \
      --repository-name "$repo" \
      --region "$AWS_REGION" \
      --image-ids "$(aws ecr list-images \
        --repository-name "$repo" \
        --region "$AWS_REGION" \
        --query 'imageIds[*]' --output json)" \
      >> "$LOG_FILE" 2>&1 || true
  fi
done
ok "ECR limpo"

cd "$TF_DIR/02-eks"
terraform init -input=false -reconfigure >> "$LOG_FILE" 2>&1
terraform destroy -auto-approve -input=false 2>&1 | tee -a "$LOG_FILE" | tail -8
ok "EKS destruído"

# ── terraform destroy 01-vpc ─────────────────────────────────
# Security groups criados pelo EKS podem atrasar — aguarda
info "Aguardando security groups do EKS serem liberados..."
sleep 30

cd "$TF_DIR/01-vpc"
terraform init -input=false -reconfigure >> "$LOG_FILE" 2>&1
# Tenta até 3x — SGs do EKS às vezes demoram para sumir
for attempt in 1 2 3; do
  if terraform destroy -auto-approve -input=false \
      2>&1 | tee -a "$LOG_FILE" | tail -8; then
    ok "VPC destruída"
    break
  else
    if [ "$attempt" -lt 3 ]; then
      warn "Tentativa $attempt falhou — aguardando 30s e tentando novamente..."
      sleep 30
    else
      warn "VPC destroy falhou após 3 tentativas"
      warn "Verifique SGs/ENIs órfãos: aws ec2 describe-security-groups --region $AWS_REGION"
    fi
  fi
done

# ── backend (opcional) ───────────────────────────────────────
echo ""
warn "O backend S3/DynamoDB guarda o histórico de state — preservado por padrão"
read -rp "Destruir também o backend S3/DynamoDB? (s/N): " DESTROY_BACKEND
if [[ "$DESTROY_BACKEND" =~ ^[sS]$ ]]; then
  cd "$TF_DIR/00-backend"
  terraform init -input=false -reconfigure >> "$LOG_FILE" 2>&1
  terraform destroy -auto-approve -input=false 2>&1 | tee -a "$LOG_FILE" | tail -5
  ok "Backend destruído"
else
  warn "Backend preservado (cluster-kubernetes-tf-state-files)"
fi

# ── Secrets Manager ──────────────────────────────────────────
read -rp "Remover secret platform/lab/shared-config do Secrets Manager? (s/N): " DEL_SECRET
if [[ "$DEL_SECRET" =~ ^[sS]$ ]]; then
  aws secretsmanager delete-secret \
    --secret-id "platform/lab/shared-config" \
    --force-delete-without-recovery \
    --region "$AWS_REGION" >> "$LOG_FILE" 2>&1 && \
    ok "Secret removido" || warn "Secret não encontrado ou já removido"
fi

# ── Limpa arquivos locais ─────────────────────────────────────
rm -f "$SCRIPT_DIR/.deploy-checkpoint"
rm -f "$SCRIPT_DIR/.env.platform"

echo ""
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✅ DESTROY COMPLETO — zero recursos na AWS${NC}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Log completo: ${CYAN}$LOG_FILE${NC}"
echo ""
echo -e "${YELLOW}Verifique manualmente se necessário:${NC}"
echo -e "  ${CYAN}aws ec2 describe-vpcs --region $AWS_REGION${NC}"
echo -e "  ${CYAN}aws eks list-clusters --region $AWS_REGION${NC}"
echo -e "  ${CYAN}aws elb describe-load-balancers --region $AWS_REGION${NC}"
echo -e "  ${CYAN}aws ec2 describe-volumes --region $AWS_REGION --filters Name=status,Values=available${NC}"
