# Guia de Teste — Cenário Real da Plataforma

> Como testar o vision-2026 do início ao fim, seguindo o fluxo real de um desenvolvedor.
> Personagem: **Lucas**, dev do time de pagamentos da empresa **XPTO**.

---

## Índice

1. [Pré-requisitos antes de testar](#1-pré-requisitos-antes-de-testar)
2. [Setup automatizado](#2-setup-antes-do-deploy-automatizado)
3. [Subir a plataforma](#3-subir-a-plataforma)
4. [GitFlow — Regras de deploy por branch](#4-gitflow--regras-de-deploy-por-branch)
5. [Semana 1 — Criar o serviço no Backstage](#5-semana-1--criar-o-serviço-no-backstage)
6. [Dia 1 — Trabalhar no código](#6-dia-1--trabalhar-no-código)
7. [Dia 3 — Primeiro commit e deploy automático](#7-dia-3--primeiro-commit-e-deploy-automático)
8. [Semana 2 — Validar saúde da plataforma](#8-semana-2--validar-saúde-da-plataforma)
9. [Semana 3 — Adicionar recurso de infra (SQS)](#9-semana-3--adicionar-recurso-de-infra-sqs)
10. [Checklist de validação completa](#10-checklist-de-validação-completa)
11. [O que Lucas nunca precisou fazer](#11-o-que-lucas-nunca-precisou-fazer)

---

## 1. Pré-requisitos antes de testar

### Ferramentas locais

> **Docker não é necessário** — a imagem do Platform Operator é buildada via GitHub Actions na nuvem.

```bash
aws --version          # >= 2.x
terraform --version    # >= 1.6
kubectl version        # >= 1.28
helm version           # >= 3.x
git --version
jq --version
gh --version           # GitHub CLI — opcional, acelera o build do operator
python3 --version      # >= 3.x (usado pelo setup.sh)
```

### Credenciais AWS

```bash
aws sso login
# ou: aws configure

# Verificar
aws sts get-caller-identity
```

### GitHub App necessário (sem PAT — padrão corporativo)

Antes de rodar o `setup.sh`, crie **um único GitHub App** que serve para tudo:
catálogo, scaffolder, login e Platform API. Zero PAT pessoal na stack.

**Criar o GitHub App**
- Acesse: https://github.com/settings/apps → New GitHub App
- Homepage URL: `https://backstage.devopstia.com`
- Callback URL: `https://backstage.devopstia.com/api/auth/github/handler/frame`
- Webhook URL: `https://backstage.devopstia.com/api/catalog/github/webhook`

**Permissões necessárias:**

| Permissão | Nível | Para quê |
|---|---|---|
| Contents | Read & Write | Platform API cria/commita arquivos |
| Metadata | Read | Leitura básica dos repos |
| Administration | Read & Write | Branch protection, teams |
| Workflows | Read & Write | CI/CD pipelines |
| Members | Read | Catálogo de usuários da org |

**Configurações extras no GitHub App:**
- "Request user authorization (OAuth) during installation" → ✅ ativado
- "User-to-server token expiration" → desativado (simplifica o lab)

**Anote após criar:**
- App ID
- Client ID + Client Secret (aba "General")
- Baixe o arquivo `.pem` (Private Key)
- Installation ID (após instalar na org: URL da instalação contém o ID)

---

## 2. Setup antes do deploy (automatizado)

O `setup.sh` detecta tudo automaticamente. A **única interação** são as credenciais do GitHub App — impossível auto-detectar.

### Opção A — Zero interação (recomendado)

Preenche uma vez, nunca mais:

```bash
cp .env.secrets.example .env.secrets
chmod 600 .env.secrets
# edita com seus valores reais
vim .env.secrets
```

Conteúdo do `.env.secrets`:

```bash
GITHUB_APP_ID=123456
GITHUB_INSTALLATION_ID=78901234
GITHUB_CLIENT_ID=Iv1.xxxxxxxxxxxxxxxx
GITHUB_CLIENT_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
GITHUB_PEM_PATH=./platform-api/github-app.pem
```

Depois:

```bash
gh auth login   # apenas na primeira vez
./setup.sh      # lê .env.secrets — zero perguntas
./deploy.sh     # sobe tudo
```

### Opção B — Interativo (sem .env.secrets)

```bash
./setup.sh   # pergunta só as credenciais do GitHub App
```

---

O que o `setup.sh` faz automaticamente:

| O que | Como |
|---|---|
| AWS Account, Region | `aws sts` + `aws configure` |
| S3 bucket tfstate | Detecta `cluster-kubernetes-tf-state-files` ou cria novo |
| DynamoDB lock table | Detecta `cluster-kubernetes-tf-state-locking` ou cria novo |
| Domínio Route53 | `aws route53 list-hosted-zones` → pega o primeiro |
| GitHub Org | `gh api user` |
| `terraform.tfvars` (4 módulos) | Gerado com valores reais |
| Backends dos módulos TF | Atualizado com S3/DynamoDB detectados |
| `PLATFORM_API_TOKEN` | `openssl rand -hex 32` |
| `GITHUB_WEBHOOK_SECRET` | `openssl rand -hex 20` |
| AWS Secrets Manager | Salva tudo em `platform/lab/shared-config` |
| Repo `gitops-repo` | Criado via `gh` CLI (privado) |
| Repo `platform-templates` | Criado via `gh` CLI (público) |
| `.env.platform` | Salvo local com todos os valores (chmod 600) |

```
✅ SETUP COMPLETO — zero configuração manual!
Próximo passo: ./deploy.sh
```

---

## 3. Subir a plataforma

```bash
# Um único comando sobe tudo em ordem
./deploy.sh
```

Tempo estimado: **~25–30 minutos**

O que o script faz em ordem:
```
[1]  Verifica pré-requisitos
[2]  Terraform: S3 backend + DynamoDB lock
[3]  Terraform: VPC + subnets
[4]  Terraform: EKS cluster (~15 min)
[5]  Terraform: NGINX Ingress + cert-manager + Route53
[6]  Terraform: ArgoCD + Backstage + Crossplane + PostgreSQL
[7]  AWS Secrets Manager: credenciais GitHub App
[8]  Crossplane: instala providers + XRDs + Compositions
[9]  Kyverno: instala + aplica 4 políticas de guardrails
[10] ArgoCD: aplica ApplicationSets
[11] Platform Operator: build ECR + deploy no EKS
[12] Observabilidade: Prometheus + Grafana
[13] Validação final + exibe URLs de acesso
```

### Ao finalizar, você verá

```
╔═══════════════════════════════════════════════════════════╗
║  ACESSOS E CREDENCIAIS                                    ║
╠═══════════════════════════════════════════════════════════╣
║  Backstage    https://backstage.devopstia.com
║               Login via GitHub OAuth
║
║  ArgoCD       https://argocd.devopstia.com
║               Usuário : admin
║               Senha   : <buscado automaticamente do K8s>
║
║  Grafana      https://grafana.devopstia.com
║               Usuário : admin
║               Senha   : <buscado automaticamente do K8s>
║
║  Platform API https://platform-api.devopstia.com/v1/health
║               Bearer  : <buscado do AWS Secrets Manager>
║
║  PostgreSQL   postgresql.backstage.svc.cluster.local
║               Usuário : backstage
║               Senha   : <buscado automaticamente do K8s>
╚═══════════════════════════════════════════════════════════╝
```

> Para recuperar as credenciais a qualquer momento depois:
> ```bash
> ./scripts/get-credentials.sh
> ```

### Nota sobre o Platform Operator

O step 11 builda a imagem via **GitHub Actions** (sem Docker local).
Se o `gh` CLI estiver instalado, o deploy dispara automaticamente.
Se não, rode após o build:

```bash
./scripts/deploy-operator.sh
```

### Validar que tudo subiu

```bash
# Todos os pods devem estar Running
kubectl get pods -A

# Certificados TLS devem estar Ready
kubectl get certificates -A

# CRDs da plataforma devem existir
kubectl get crd | grep platform.devopstia.com

# Platform Operator deve estar rodando
kubectl get pods -n platform
```

---

## 5. Semana 1 — Criar o serviço no Backstage

### Lucas abre o portal

Acesse: `https://backstage.devopstia.com`

### Passo a passo no portal

1. Clique em **"Create"** no menu lateral
2. Escolha o template **"Java Spring Boot Service"**
3. Preencha o formulário:

```
Nome do serviço : payment-processor
Time            : payments
Sigla           : xpto
Runtime         : java
Banco de dados  : RDS PostgreSQL
  → nome da instância : payment-db
  → storage           : 20Gi
  → instance type     : db.t3.micro
```

4. Clique **"Review"** → **"Create"**

### O que acontece em background (2 minutos)

```
Platform API recebe o pedido
  │
  ├── GitHub App cria repo: xpto-payment-processor
  │     ├── código esqueleto Spring Boot
  │     ├── .github/workflows/ci.yaml  ← pipeline pronto
  │     ├── .pipeline.yaml             ← account_id por ambiente
  │     ├── catalog-info.yaml          ← registro no Backstage
  │     └── Dockerfile
  │
  ├── Commita ArgoCD Application no gitops-repo
  │     └── argocd/apps/payment-processor.yaml
  │           └── ArgoCD detecta → aguarda código
  │
  └── Cria repo: xpto_iac-infra_cp-aws-rds
        └── commita payment-db.yaml (Crossplane Claim)
              └── ArgoCD ApplicationSet detecta repo novo
                    └── Crossplane reconcilia (~8 min)
                          └── AWS provisiona RDS PostgreSQL
                                └── Secret injetado no K8s:
                                      namespace xpto / payment-processor-db
```

### Validar a criação

```bash
# Repo criado no GitHub
# Acesse: https://github.com/hugosleao/xpto-payment-processor

# ArgoCD Application registrada
kubectl get applications -n argocd | grep payment-processor

# Crossplane Claim criado
kubectl get rdsinstances -A

# Secret do banco injetado (aguardar ~8 min para o RDS ficar Ready)
kubectl get secret payment-processor-db -n xpto
```

---

## 4. GitFlow — Regras de deploy por branch

Dois arquivos de workflow são gerados automaticamente pelo template do Backstage:

```
.github/workflows/
├── ci.yaml   ← roda em TODA branch — só valida o código
└── cd.yaml   ← roda APENAS em develop, release/*, master — faz deploy
```

| Branch | `ci.yaml` | `cd.yaml` | Ambiente |
|---|---|---|---|
| `feature/*` | ✅ build + test + sonar | ❌ | — |
| `fix/*` | ✅ build + test + sonar | ❌ | — |
| `develop` | ✅ | ✅ push ECR + gitops | DEV |
| `release/*` | ✅ | ✅ push ECR + gitops | HML |
| `master` | ✅ | ✅ push ECR + gitops | PRD |

### Fluxo típico do Lucas

```bash
# 1. Parte de develop
git checkout develop
git checkout -b feature/pix-processor

# 2. Desenvolve e commita
git push origin feature/pix-processor
# → ci.yaml dispara: build + test + sonar ✅
# → cd.yaml NÃO dispara: zero deploy ❌

# 3. PR aprovado → merge em develop
# → ci.yaml ✅  cd.yaml ✅
# → imagem: dev-abc123 → ECR
# → gitops-repo atualizado → ArgoCD sync → DEV

# 4. Cria release
git checkout -b release/1.2.0
git push origin release/1.2.0
# → ci.yaml ✅  cd.yaml ✅
# → imagem: hml-abc123 → ECR
# → gitops-repo atualizado → ArgoCD sync → HML

# 5. Testa em HML → merge em master
git checkout master
git merge release/1.2.0
git push origin master
# → ci.yaml ✅  cd.yaml ✅
# → imagem: prd-abc123 → ECR
# → gitops-repo atualizado → ArgoCD sync → PRD
```

### Como o ArgoCD sabe qual branch assistir

A Platform API cria **3 ArgoCD Applications** ao registrar o serviço:

```
payment-processor-dev → targetRevision: develop   → namespace: payment-processor-dev
payment-processor-hml → targetRevision: release/* → namespace: payment-processor-hml
payment-processor-prd → targetRevision: master    → namespace: payment-processor-prd
```

```bash
# Validar as 3 Applications criadas
kubectl get applications -n argocd | grep payment-processor
# payment-processor-dev   Synced  Healthy
# payment-processor-hml   Synced  Healthy
# payment-processor-prd   Synced  Healthy
```

---

## 6. Dia 1 — Trabalhar no código

Lucas clona o repo e começa a codar:

```bash
git clone git@github.com:hugosleao/xpto-payment-processor.git
cd xpto-payment-processor
```

### Estrutura que encontra pronta

```
src/main/java/com/xpto/payment/
├── PaymentProcessorApplication.java
├── controller/PaymentController.java
├── service/PaymentService.java
└── repository/PaymentRepository.java
```

### Banco já configurado no application.yml

```yaml
spring:
  datasource:
    url: ${DB_URL}       # injetado automaticamente pelo Crossplane
    username: ${DB_USER}
    password: ${DB_PASS}
```

> Lucas **não precisa saber** o host, user ou senha do banco.
> Esses valores chegam do Secret K8s criado pelo Crossplane.

---

## 7. Dia 3 — Primeiro commit e deploy automático

Lucas implementou a lógica de PIX e faz o push:

```bash
git add .
git commit -m "feat: add pix payment processing"
git push origin main
```

### O que acontece automaticamente

**GitHub Actions dispara (ci.yaml):**

```
mvn test                  → testes unitários
mvn sonar:sonar           → qualidade de código
OIDC → AWS STS            → sem credencial estática
  └── assume role: github-actions-xpto
        └── push imagem → ECR
              xpto.dkr.ecr.us-east-1.amazonaws.com/
                payment-processor:abc123
✅ pipeline verde
```

**ArgoCD detecta mudança:**

```
compara Git vs cluster
  └── diff: imagem antiga vs abc123
        └── sync → rolling update no EKS
              └── pod novo sobe com imagem abc123
                    └── liveness probe OK
                          └── pod antigo desce
                                └── deploy concluído (zero downtime)
```

### Validar o deploy

```bash
# Ver o pipeline no GitHub Actions
# https://github.com/hugosleao/xpto-payment-processor/actions

# Ver o sync no ArgoCD
kubectl get applications -n argocd payment-processor
# STATUS: Synced  HEALTH: Healthy

# Ver o pod rodando
kubectl get pods -n xpto | grep payment-processor

# Ver a imagem deployada
kubectl describe pod -n xpto -l app=payment-processor | grep Image
# Image: xpto.dkr.ecr.us-east-1.amazonaws.com/payment-processor:abc123

# Testar o endpoint (se tiver Ingress configurado)
curl https://payment-processor.devopstia.com/actuator/health
# {"status":"UP"}
```

---

## 8. Semana 2 — Validar saúde da plataforma

### No Backstage

```
https://backstage.devopstia.com
  → Catalog → payment-processor
```

O que Lucas vê:

```
Overview
  ├── Owner    : payments
  ├── Runtime  : java
  └── Status   : Healthy ✅

CI/CD
  └── Último build: verde, 2 min atrás ✅

ArgoCD
  └── Synced ✅  |  Healthy ✅

Infraestrutura
  └── RDS payment-db: Available ✅

Scorecard de Maturidade
  ├── ✅ Tem Dockerfile
  ├── ✅ Tem pipeline CI
  ├── ✅ Tem catalog-info.yaml
  ├── ⚠️  Falta health probe em /actuator/health  ← Lucas corrige
  └── Score: 7/10
```

### No Grafana

```
https://grafana.devopstia.com
  → Dashboard: payment-processor
```

```bash
# Ou via kubectl port-forward para acessar localmente
kubectl port-forward svc/grafana -n monitoring 3000:80
# Acesse: http://localhost:3000
```

Métricas esperadas:
```
RPS          : 120 req/min
P99 latency  : 45ms
Error rate   : 0.1%
CPU usage    : 120m / 500m
Memory usage : 180Mi / 256Mi
```

### Validar guardrails (Kyverno)

```bash
# Tentar criar pod sem labels — deve ser BLOQUEADO
kubectl run test --image=nginx -n xpto
# Error: admission webhook denied: missing required labels: app, owner, team

# Tentar deploy com imagem :latest — deve ser BLOQUEADO
# (edite um deployment para usar :latest e aplique — Kyverno bloqueia)

# Ver todas as políticas ativas
kubectl get clusterpolicies
```

---

## 9. Semana 3 — Adicionar recurso de infra (SQS)

Lucas precisa de uma fila para eventos de pagamento.

### No Backstage

```
Catalog → payment-processor → "Add Resource"
  → Tipo: SQS Queue
  → Nome: payment-events
  → Sigla: xpto
```

### O que acontece

```
Platform API
  └── cria repo: xpto_iac-infra_cp-aws-sqs
        └── commita payment-events.yaml
              └── ArgoCD ApplicationSet detecta
                    └── Crossplane provisiona SQS na AWS
                          └── ARN injetado como Secret no K8s:
                                xpto/payment-events-sqs
```

### Validar

```bash
# Repo criado
# https://github.com/hugosleao/xpto_iac-infra_cp-aws-sqs

# Crossplane Claim
kubectl get sqsqueues -A

# Secret com ARN da fila
kubectl get secret payment-events-sqs -n xpto -o jsonpath='{.data.arn}' | base64 -d
# arn:aws:sqs:us-east-1:123456789:payment-events
```

### Lucas usa no código sem configurar nada

O `application.yml` já tem a env var injetada:

```yaml
aws:
  sqs:
    queue-url: ${SQS_PAYMENT_EVENTS_URL}
```

Lucas só escreve o código que publica/consome a fila.

---

## 10. Checklist de validação completa

### Infraestrutura

- [ ] `kubectl get nodes` → todos os nodes Ready
- [ ] `kubectl get pods -A` → nenhum pod em CrashLoopBackOff
- [ ] `kubectl get certificates -A` → todos os certs Ready (TLS válido)
- [ ] `curl https://backstage.devopstia.com` → 200 OK
- [ ] `curl https://argocd.devopstia.com` → 200 OK
- [ ] `curl https://platform-api.devopstia.com/v1/health` → `{"status":"ok"}`

### Fluxo completo

- [ ] Criar serviço no Backstage → repo criado no GitHub
- [ ] Repo tem `.github/workflows/ci.yaml` gerado
- [ ] ArgoCD Application aparece no ArgoCD UI
- [ ] Crossplane Claim criado no repo de infra
- [ ] RDS provisionado na AWS (`aws rds describe-db-instances`)
- [ ] Secret do banco injetado no namespace correto
- [ ] `git push` → GitHub Actions roda automaticamente
- [ ] ArgoCD faz sync após merge na main
- [ ] Pod novo sobe com a imagem correta
- [ ] Endpoint do serviço responde

### Guardrails

- [ ] Deploy sem labels é bloqueado pelo Kyverno
- [ ] Deploy sem resource limits é bloqueado
- [ ] Imagem `:latest` é bloqueada
- [ ] `kubectl get clusterpolicies` → 4 políticas ativas

### Observabilidade

- [ ] Grafana acessível com dashboard do serviço
- [ ] Prometheus coletando métricas (`/metrics` no serviço)
- [ ] Audit log da Platform API (`GET /v1/audit`) registra as ações

---

## 11. O que Lucas nunca precisou fazer

| Ação | Status |
|---|---|
| Acessar o AWS Console | ❌ não foi necessário |
| Rodar `kubectl` no dia a dia | ❌ não foi necessário |
| Criar um secret manualmente | ❌ não foi necessário |
| Configurar o pipeline CI/CD | ❌ já estava pronto |
| Pedir ticket para infra provisionar banco | ❌ self-service |
| Esperar aprovação de alguém | ❌ automático |
| Saber o host/senha do banco | ❌ injetado automaticamente |
| Configurar DNS ou TLS | ❌ automático |

**Lucas só fez três coisas:**
1. Preencheu um formulário no Backstage
2. Escreveu código
3. Fez `git push`

**Isso é o Golden Path funcionando.**

---

## Para destruir tudo após o teste

```bash
./destroy.sh
# Digite DESTROY para confirmar
```

O destroy remove em ordem inversa:
```
Crossplane Claims → recursos AWS (RDS, SQS, S3)
ArgoCD Applications
Platform Operator
Observabilidade
Kyverno
Crossplane
ArgoCD + Backstage + PostgreSQL
NGINX + cert-manager + Route53
EKS cluster
VPC
S3 backend + DynamoDB
```

> Nada fica órfão na AWS. Custo: zero após o destroy.
