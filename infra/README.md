# 🚀 Golden Triangle Lab - Versão Minimalista

Arquitetura modular simplificada para lab/estudos com **Backstage + ArgoCD + Crossplane** em EKS.

## 📋 Características

**✅ Simplicidade:**
- Estrutura modular (4 módulos independentes)
- PostgreSQL in-cluster (sem RDS)
- 1 LoadBalancer (NGINX Ingress)
- Destroy limpo (5-10min)

**✅ SSL Automático:**
- cert-manager + Let's Encrypt
- HTTPS automático para Backstage e ArgoCD

**✅ Custo Baixo:**
- SPOT instances (t3.medium)
- Sem NAT Gateway
- Sem RDS

**✅ Produção-like:**
- Domínio real (devopstia.com)
- SSL válido
- GitOps pronto

---

## 📁 Estrutura

```
infra/terraform/
├── 00-backend/          # Backend S3 + DynamoDB (já existe)
├── 01-vpc/             # VPC + Subnets públicas + IGW
├── 02-eks/             # EKS Cluster + Node Group SPOT
├── 03-networking/      # NGINX + cert-manager + Route53
├── 04-platform/        # Backstage + ArgoCD + Crossplane + PostgreSQL
├── deploy.sh           # Deploy completo (ordem correta)
└── destroy.sh          # Destroy completo (ordem reversa)
```

---

## 🚀 Deploy Rápido

### 1. Pré-requisitos

```bash
# AWS CLI configurado
aws sts get-caller-identity

# Terraform >= 1.0
terraform version

# kubectl
kubectl version --client

# Hosted Zone Route53 (devopstia.com)
aws route53 list-hosted-zones --query 'HostedZones[?Name==`devopstia.com.`]'
```

### 2. Configurar Secrets

```bash
./setup-secrets.sh
```

O script vai pedir:
- **GitHub PAT**: [Criar aqui](https://github.com/settings/tokens/new)
  - Scopes: `repo`, `workflow`, `read:org`, `read:user`
- **GitHub OAuth App**: [Criar aqui](https://github.com/settings/applications/new)
  - Homepage: `https://backstage.devopstia.com`
  - Callback: `https://backstage.devopstia.com/api/auth/github/handler/frame`

Gera `04-platform/terraform.tfvars` automaticamente.

### 3. Deploy Automatizado

```bash
cd infra/terraform
./deploy.sh
```

**Tempo:** ~20min total
- VPC: 1min
- EKS: 10-15min
- Networking: 3min
- Platform: 5min

### 4. Acessar

```bash
# URLs
echo "Backstage: https://backstage.devopstia.com"
echo "ArgoCD: https://argocd.devopstia.com"

# ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

---

## 🗑️ Destroy

```bash
cd infra/terraform
./destroy.sh
```

**Tempo:** ~15min total
- Platform: 2min
- Networking: 2min
- EKS: 10min
- VPC: 1min

**✅ Destroy limpo!** Sem travamentos.

---

## 📦 Ordem de Dependências

### Apply (1→4):
```
VPC → EKS → Networking → Platform
```

### Destroy (4→1):
```
Platform → Networking → EKS → VPC
```

---

## 🛠️ Deploy Manual (por módulo)

Se preferir controle manual:

```bash
# 1. VPC
cd 01-vpc
terraform init
terraform apply

# 2. EKS
cd ../02-eks
terraform init
terraform apply

# Configurar kubectl
aws eks update-kubeconfig --name eks-lab --region us-east-1

# 3. Networking
cd ../03-networking
terraform init
terraform apply

# 4. Platform
cd ../04-platform
terraform init
terraform apply -var="github_token=ghp_..." \
                -var="github_client_id=..." \
                -var="github_client_secret=..."
```

---

## 🔧 Customizações

### Trocar domínio

Edite `03-networking/variables.tf` e `04-platform/variables.tf`:

```hcl
variable "domain_name" {
  default = "seu-dominio.com"
}

variable "letsencrypt_email" {
  default = "seu-email@exemplo.com"
}
```

### Aumentar nodes

Edite `02-eks/main.tf`:

```hcl
min_size     = 3
max_size     = 6
desired_size = 3
```

### Trocar região

Edite `variables.tf` de cada módulo:

```hcl
variable "aws_region" {
  default = "us-west-2"
}
```

---

## 📊 Custos Estimados

**Mensal (~$50-80):**
- EKS Control Plane: $73/mês
- EC2 SPOT (2x t3.medium): ~$15/mês
- LoadBalancer (NLB): ~$16/mês
- EBS (PostgreSQL): ~$1/mês

**Destroy para economizar!**

---

## 🐛 Troubleshooting

### Certificados SSL pendentes

```bash
# Ver status
kubectl get certificate -A

# Ver eventos cert-manager
kubectl logs -n cert-manager -l app=cert-manager -f
```

### LoadBalancer não provisionado

```bash
# Ver status
kubectl get svc -n ingress-nginx

# Aguardar até External-IP aparecer (1-2min)
```

### ArgoCD não acessa

```bash
# Verificar Ingress
kubectl get ingress -n argocd

# Ver logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

---

## 📚 Próximos Passos

1. Configurar templates Backstage
2. Criar ApplicationSets ArgoCD
3. Configurar Crossplane AWS Provider
4. Testar provisionamento end-to-end

---

## 🎯 Diferenças vs Versão Anterior

| Aspecto | Anterior | Minimalista |
|---------|----------|-------------|
| **RDS** | Managed PostgreSQL | In-cluster StatefulSet |
| **Ingress** | ALB Controller (2 ALBs) | NGINX (1 NLB) |
| **SSL** | ACM manual | cert-manager automático |
| **NAT** | NAT Gateway | Sem (só subnets públicas) |
| **Auth** | Pod Identity complexo | Simples (sem AWS auth) |
| **Destroy** | 40min + travamentos | 15min limpo |
| **Custo** | ~$150/mês | ~$60/mês |

---

**Criado:** 2026-02-15  
**Update:** Estrutura modular minimalista para lab
