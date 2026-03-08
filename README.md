# vision-2026 — Platform Engineering Lab

> Arquitetura de referência para Internal Developer Platform (IDP)  
> baseada nas práticas de mercado de empresas como **Spotify, Netflix, Mercado Livre e Uber**.

---

## O que é essa arquitetura

É a implementação prática do conceito **"Platform as a Product"** — onde a plataforma
de engenharia é tratada como um produto interno, e o desenvolvedor é o cliente.

O objetivo é eliminar o atrito entre escrever código e ter esse código rodando em produção,
com toda a infraestrutura, segurança e observabilidade já resolvidas automaticamente.

```
Dev escreve código
  → plataforma provisiona infra, configura CI/CD, faz deploy e monitora
  → sem tickets, sem espera, sem acesso direto à AWS
```

---

## Empresas de referência

| Empresa | IDP | O que inspirou |
|---|---|---|
| **Spotify** | Backstage (open source) | Portal self-service, catálogo de serviços |
| **Netflix** | Spinnaker + plataforma interna | Golden Path, deploy sem downtime |
| **Mercado Livre** | FURY | Vending machine — dev pede, plataforma entrega |
| **Uber** | uDeploy | Abstrações sobre Kubernetes, padrão de serviço |
| **Airbnb** | Deployboard | Scorecard de maturidade de serviços |

Esta arquitetura implementa os mesmos princípios dessas plataformas, mas com
stack 100% open source e cloud-native.

---

## Arquitetura — Golden Triangle + Platform API

```
┌─────────────────────────────────────────────────────────────┐
│                    DEVELOPER EXPERIENCE                      │
│   Dev abre DevPortal → escolhe template → preenche form      │
│   Plataforma faz o resto automaticamente                     │
└─────────────────────────────────────────────────────────────┘
                             │
            ┌────────────────┼────────────────┐
            ▼                ▼                ▼
     ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
     │  BACKSTAGE  │  │   GITHUB    │  │    ArgoCD   │
     │    (IDP)    │─▶│  (GitOps)   │─▶│  (Sync)     │
     └──────┬──────┘  └──────┬──────┘  └──────┬──────┘
            │                │                 │
            ▼                │                 ▼
     ┌─────────────┐         │          ┌─────────────┐
     │ PLATFORM    │─────────┘          │     EKS     │
     │  API (Go)   │   escreve Git      │ (Workloads) │
     │  Operator   │                    └─────────────┘
     └──────┬──────┘
            │ reconcile loop
            ▼
     ┌─────────────┐
     │  CROSSPLANE │──▶ AWS: RDS · SQS · S3
     │  (XRDs)     │
     └─────────────┘
```

**Os quatro pilares:**
- **Backstage** — self-service portal (o dev nunca acessa AWS diretamente)
- **GitHub** — fonte única de verdade (todo estado fica em Git)
- **Platform API (Go)** — broker + operator: recebe pedido, escreve manifest no Git, reconcilia estado
- **ArgoCD** — motor GitOps (o que está no Git é o que está no cluster)

---

## Platform API — Go Operator Pattern

Esta é a camada que diferencia o `vision-2026` de uma arquitetura GitOps simples.
Baseada no padrão que empresas como **Uber, Cloudflare e HashiCorp** usam internamente.

### Por que Operator pattern e não só REST API?

| Abordagem | Limitação |
|---|---|
| REST API simples | Stateless — não sabe se o recurso foi criado com sucesso |
| Broker GitOps puro | Escreve no Git mas não valida o estado final |
| **Operator (controller-runtime)** | **Reconcilia continuamente — garante que o estado desejado == estado real** |

### O que o Operator faz

```
Dev cria PlatformService CRD
  └→ Platform Operator detecta (reconcile loop)
        ├→ EnsureRepo: cria repo GitHub se não existe
        ├→ CommitManifest: escreve Crossplane Claim no Git
        ├→ CommitManifest: escreve 3 ArgoCD Applications no Git
        │     ├→ {service}-dev  → targetRevision: develop
        │     ├→ {service}-hml  → targetRevision: release/*
        │     └→ {service}-prd  → targetRevision: master
        ├→ Atualiza status do CRD (Provisioning → Ready)
        └→ Expõe métricas para Prometheus
```

### GitFlow — Regras de deploy por branch

O template gerado pelo Backstage inclui dois workflows separados:

| Arquivo | Branch | O que faz |
|---|---|---|
| `ci.yaml` | **toda branch** | build + test + sonar — nunca deploya |
| `cd.yaml` | `develop`, `release/**`, `master` | push ECR + atualiza gitops-repo |

```
feature/* → ci.yaml ✅   cd.yaml ❌  (sem deploy)
fix/*     → ci.yaml ✅   cd.yaml ❌  (sem deploy)
develop   → ci.yaml ✅   cd.yaml ✅  → DEV
release/* → ci.yaml ✅   cd.yaml ✅  → HML
master    → ci.yaml ✅   cd.yaml ✅  → PRD
```

### Ciclo de reconciliação (padrão Kubernetes)

```
┌──────────────────────────────────────────────┐
│              RECONCILE LOOP                   │
│                                               │
│  Observe (lê estado atual do CRD)             │
│      │                                        │
│      ▼                                        │
│  Diff (compara com estado desejado)           │
│      │                                        │
│      ▼                                        │
│  Act (escreve Git / atualiza status)          │
│      │                                        │
│      └──────────────── repete a cada 30s ─────┘
└──────────────────────────────────────────────┘
```

### Quem usa esse padrão no mercado

| Empresa | Projeto | O que faz |
|---|---|---|
| **HashiCorp** | Vault Operator | Reconcilia Secrets entre Vault e K8s |
| **Crossplane** | Todos os Providers | Reconcilia Claims → recursos AWS |
| **Cloudflare** | Operators internos | Gerencia DNS, Workers via CRD |
| **Uber** | uDeploy internals | Reconcilia estado de deploys |
| **Livro referência** | Platform Engineering with Go (Nels Lutiy) | Ensina exatamente esse padrão |

### Estrutura da Platform API no projeto

```
platform-api/
├── cmd/operator/main.go          ← entry point do operator
├── internal/
│   ├── controller/               ← reconcile loop (controller-runtime)
│   │   ├── platformservice.go    ← CRD PlatformService
│   │   └── infrarequest.go       ← CRD InfraRequest
│   ├── github/client.go          ← EnsureRepo + CommitFile (GitHub App JWT)
│   ├── crossplane/manifest.go    ← gera Crossplane Claims
│   ├── argocd/manifest.go        ← gera ArgoCD Applications
│   ├── handlers/                 ← REST endpoints (Backstage → API)
│   ├── middleware/               ← auth, logging
│   └── audit/                    ← audit log estruturado
├── api/v1alpha1/                 ← tipos dos CRDs
│   ├── platformservice_types.go
│   └── infrarequest_types.go
├── config/crd/                   ← manifests gerados dos CRDs
├── Dockerfile
└── go.mod
```

### Fluxo completo com a Platform API

```
1. Dev acessa Backstage → preenche template
2. Backstage chama Platform API REST: POST /api/services
3. Platform API cria CRD PlatformService no K8s
4. Operator detecta novo CRD → inicia reconcile
5. Operator cria repo GitHub (GitHub App JWT)
6. Operator commita Crossplane Claim no repo
7. Operator commita ArgoCD Application no gitops-repo
8. ArgoCD detecta mudança → sync automático
9. Crossplane reconcilia Claim → provisiona AWS
10. Operator atualiza status do CRD: Ready
11. Backstage lê status via API → mostra para o dev
```

---

## Stack técnica

| Camada | Tecnologia | Por que usamos |
|---|---|---|
| **IDP** | Backstage | Padrão de mercado, criado pelo Spotify, usado por 3000+ empresas |
| **Platform API** | Go + controller-runtime | Operator pattern — reconcilia estado desejado vs real |
| **GitOps** | ArgoCD | Sync declarativo Git→EKS, audit trail automático |
| **IaC Cloud** | Crossplane 2.0 | Infra como CRD Kubernetes — mesma API para app e infra |
| **IaC Base** | Terraform | Provisiona EKS, VPC, Route53, cert-manager |
| **CI/CD** | GitHub Actions + OIDC | Zero credencial estática, role temporária via STS |
| **Auth GitHub** | GitHub App (JWT + OAuth) | Um único App para tudo — catálogo, login e Platform API. Zero PAT. |
| **Guardrails** | Kyverno | Políticas como código, enforce no admission webhook |
| **Observabilidade** | Prometheus + Grafana | Stack CNCF padrão de mercado |
| **DNS + SSL** | Route53 + cert-manager + Let's Encrypt | TLS automático, zero configuração manual |
| **Container Runtime** | EKS 1.31 + SPOT | Custo otimizado para lab |

---

## O que você consegue fazer durante o lab provisionado

### Self-service via DevPortal

Acesse `https://backstage.devopstia.com` e:

- **Criar um novo serviço** — escolhe o template (Java, Python, Node, Lambda),
  preenche o formulário e o portal cria automaticamente:
  - Repo no GitHub com código esqueleto
  - Pipeline CI/CD configurado (GitHub Actions)
  - Registro no catálogo do Backstage
  - ArgoCD Application para deploy automático

- **Provisionar infraestrutura AWS** — solicita RDS, S3 ou SQS via Crossplane Claim:
  - Preenche o formulário → Crossplane provisiona na AWS
  - Connection string injetada automaticamente no K8s Secret
  - App sobe e já conecta no banco sem configuração manual

- **Consultar o catálogo** — todos os serviços, seus owners, links de repositório,
  documentação TechDocs e scorecard de maturidade em um só lugar

- **Ver o Audit Log** — quem criou o quê, quando e por quê

### GitOps com ArgoCD

Acesse `https://argocd.devopstia.com` e:

- Visualize todos os serviços e seu estado (Synced / OutOfSync / Degraded)
- Veja o histórico de deploys com diff de cada mudança
- Faça rollback manual de qualquer serviço em segundos
- Observe os recursos Crossplane (RDS, S3, SQS) aparecerem como recursos
  Kubernetes junto com pods, ingress e secrets

### CI/CD sem credenciais

Ao fazer um `git push`:

```
commit → build → test (SonarQube style) → OIDC token
  → AWS STS → assume-role temporária → push ECR
  → merge main → ArgoCD detecta → sync → deploy EKS
```

Zero `AWS_ACCESS_KEY_ID`. Zero `AWS_SECRET_ACCESS_KEY`. Apenas OIDC.

### Guardrails automáticos

Qualquer deploy que não cumpra os padrões é **bloqueado automaticamente**:

| Política | Impacto |
|---|---|
| Labels obrigatórios (app/owner/team) | Enforce — deploy rejeitado |
| Resource limits obrigatórios | Enforce — sem limites, sem deploy |
| Sem tag `:latest` | Enforce — obriga versionamento |
| Health probes | Audit — visibilidade de compliance |

### Observabilidade

Acesse `https://grafana.devopstia.com` e:

- Dashboards de todas as aplicações rodando no EKS
- Métricas da Platform API (requisições, erros, latência)
- Alertas configurados para pods em crashloop

---

## Como o lab reflete o mercado

### O que o MELI (Mercado Livre) faz com o FURY

O FURY é o IDP do MELI — funciona exatamente como o que está aqui:
- Dev acessa portal → escolhe serviço → preenche → plataforma entrega
- Sem acesso direto à infra
- Pipeline padronizado para todos os times

**O que temos de equivalente:**
- Backstage = portal (mesmo princípio do FURY)
- Platform API = o backend que o FURY chama
- ArgoCD = o motor de deploy do FURY
- Templates = os "tipos de serviço" que o FURY oferece

### O que o Spotify faz com o Backstage

O Spotify criou o Backstage e usa internamente com:
- Catálogo de todos os serviços da empresa
- TechDocs integrado
- Scorecard de maturidade

**O que temos de equivalente:**
- Backstage com catálogo real (via `catalog-info.yaml` nos repos)
- Plugin Scorecard implementado
- TechDocs configurado

### O que empresas cloud-native fazem com OIDC

Netflix, Airbnb, Uber — nenhum usa access key estática em CI/CD.
Todas usam OIDC para autenticação temporária com o cloud provider.

**O que temos de equivalente:**
- GitHub Actions com OIDC configurado para AWS STS
- Role temporária com least privilege por ambiente

---

## Estrutura do projeto

```
vision-2026/
├── setup.sh                  ← detecta AWS/GitHub automaticamente, zero interação com .env.secrets
├── .env.secrets.example      ← template de credenciais GitHub App (copiar → .env.secrets)
├── deploy.sh                 ← sobe tudo em um comando
├── destroy.sh                ← destrói tudo em um comando
├── terraform.tfvars.example  ← referência (setup.sh gera os tfvars reais)
│
├── infra/                    ← base de infraestrutura (Terraform)
│   ├── 00-backend/           ← S3 state + DynamoDB lock
│   ├── 01-vpc/               ← VPC + subnets
│   ├── 02-eks/               ← cluster EKS
│   ├── 03-networking/        ← NGINX + cert-manager + Route53
│   └── 04-platform/          ← ArgoCD + Backstage + Crossplane + PostgreSQL
│
├── backstage/                ← DevPortal + templates
│   └── platform-templates/
│       ├── new-service/      ← template Java (skeleton com ci.yaml + cd.yaml)
│       └── python-api/       ← template Python
│
├── platform-api/             ← Go Operator (controller-runtime)
│   ├── cmd/operator/         ← entry point (REST API + Operator no mesmo processo)
│   ├── internal/controller/  ← reconcile loop (PlatformService + InfraRequest)
│   ├── internal/github/      ← GitHub App client (JWT)
│   ├── internal/handlers/    ← REST endpoints para Backstage
│   ├── api/v1alpha1/         ← tipos dos CRDs
│   ├── config/crd/           ← manifests CRD para aplicar no EKS
│   ├── k8s/deployment.yaml   ← Deployment + RBAC + Ingress
│   └── .github/workflows/
│       └── build-operator.yaml ← build sem Docker local (GitHub Actions)
│
├── crossplane/               ← XRDs + Compositions (RDS, S3, SQS)
├── guardrails/kyverno/       ← 4 políticas de segurança
├── gitops/appsets/           ← ApplicationSets ArgoCD (GitFlow: dev/hml/prd)
├── observability/            ← Prometheus + Grafana
├── scripts/
│   ├── get-credentials.sh    ← recupera todas as senhas pós-deploy
│   ├── deploy-operator.sh    ← deploy manual do operator se necessário
│   └── setup-secrets.sh      ← utilitário auxiliar
└── insights/                 ← DDPE e tendências 2026
```

---

## Para subir

> **Docker não é necessário** — o Platform Operator é buildado via GitHub Actions na nuvem.

### Pré-requisitos (1x)

```bash
# AWS já autenticado (confirma)
aws sts get-caller-identity

# gh CLI autenticado
gh auth login
```

### Setup zero-interação (recomendado)

```bash
# Preenche uma vez só com as credenciais do GitHub App
cp .env.secrets.example .env.secrets
chmod 600 .env.secrets
vim .env.secrets   # GITHUB_APP_ID, INSTALLATION_ID, CLIENT_ID, CLIENT_SECRET, PEM_PATH

# Detecta tudo o que for possível automaticamente
./setup.sh
# → S3 tfstate, DynamoDB lock, Route53, GitHub Org: auto-detectados
# → Repos gitops-repo e platform-templates: criados automaticamente
# → terraform.tfvars dos 4 módulos: gerados
# → AWS Secrets Manager: populado

# Sobe tudo em ordem
./deploy.sh
```

Ao finalizar, exibe todas as credenciais. Para recuperar depois:

```bash
./scripts/get-credentials.sh
```

Tempo estimado: **~25–30 minutos** (EKS domina com ~15 min)  
Custo estimado: **~$0.30/hora** (EKS SPOT t3.medium)

---

## Para destruir (sem deixar nada na AWS)

```bash
./destroy.sh
# Digite DESTROY para confirmar
```

O script destrói na ordem correta: Crossplane Claims → ArgoCD Apps →
Platform → Networking → EKS → VPC. Nada fica órfão.

---

## Roadmap de implementação

| Fase | Componente | Status |
|---|---|---|
| 1 | Infra base (Terraform: VPC, EKS, NGINX, cert-manager) | ✅ implementado |
| 1 | Backstage + templates (ci.yaml / cd.yaml GitFlow) | ✅ implementado |
| 1 | Crossplane XRDs + Compositions (RDS, S3, SQS) | ✅ implementado |
| 1 | ArgoCD ApplicationSets (dev/hml/prd) | ✅ implementado |
| 1 | Kyverno guardrails (4 políticas) | ✅ implementado |
| 1 | Observabilidade (Prometheus + Grafana) | ✅ implementado |
| 2 | Platform API — Go Operator (controller-runtime) | ✅ implementado |
| 2 | CRDs: PlatformService + InfraRequest | ✅ implementado |
| 2 | GitFlow (ci.yaml / cd.yaml separados) | ✅ implementado |
| 2 | setup.sh + get-credentials.sh automatizados | ✅ implementado |
| 2 | Build sem Docker local (GitHub Actions) | ✅ implementado |
| 3 | AI layer (linguagem natural → Claim) | 🔲 futuro |
| 3 | Scorecard de maturidade avançado | 🔲 futuro |

---

## Referências

- [Backstage.io](https://backstage.io) — documentação oficial
- [Crossplane 2.0](https://docs.crossplane.io) — IaC declarativa
- [ArgoCD](https://argo-cd.readthedocs.io) — GitOps engine
- [Kyverno](https://kyverno.io) — policy engine para Kubernetes
- [controller-runtime](https://github.com/kubernetes-sigs/controller-runtime) — base do Operator pattern em Go
- [CNCF Landscape](https://landscape.cncf.io) — mapa do ecossistema cloud-native
- [Crossplane & AI: API-First Infrastructure](https://blog.crossplane.io/crossplane-ai-the-case-for-api-first-infrastructure/) — visão 2026
- **Platform Engineering with Go** — Nels Lutiy (O'Reilly) — Operator pattern, CRDs, platform tooling
- **Crafting Engineering Strategy** — Will Larson (O'Reilly) — estratégia de plataforma
