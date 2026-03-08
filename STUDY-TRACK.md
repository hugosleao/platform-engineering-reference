# Platform Engineering — Study Track
# vision-2026 Lab Integration

Metodologia aplicada: Concept → Architectural Pattern → Real Implementation
Cada tópico segue os 7 passos definidos em `metodologia.md`.

---

## Índice

- [Como usar este documento](#como-usar)
- [Semana 1 — GitOps e Environment Pipelines](#semana-1)
- [Semana 2 — Operator Pattern e Control Plane](#semana-2)
- [Semana 3 — Crossplane e Infrastructure Abstraction](#semana-3)
- [Semana 4 — Platform APIs e Developer Experience](#semana-4)
- [Semana 5 — Observability e DORA Metrics](#semana-5)
- [Semana 6 — Security e Governance](#semana-6)
- [Mapa completo Conceito → Lab](#mapa-completo)

---

## Como usar

Para cada tópico semanal, execute os 7 passos:

```
1. Read        → leia o capítulo indicado
2. Translate   → resuma em PT-BR, mantendo termos técnicos em inglês
3. Explain     → responda: qual problema resolve? por que existe?
4. Insight     → conecte ao mundo real (empresa, mercado)
5. Lab         → abra o arquivo indicado no vision-2026
6. Context     → como isso impacta Developer Experience?
7. Key Insight → escreva 1 frase para LinkedIn
```

---

## Semana 1 — GitOps e Environment Pipelines

### Fonte
Platform Engineering on Kubernetes — Capítulo 4

### Conceito
GitOps

### Pattern
Declarative Deployment

### Step 1 — Read
Capítulo 4: Environment pipelines — como o estado desejado declarado em Git
se torna o estado real do cluster via reconciliation contínua.

### Step 2 — Translate
GitOps é o padrão onde o repositório Git é a única fonte de verdade.
Qualquer mudança de estado passa por um Pull Request.
O cluster se reconcilia automaticamente — sem `kubectl apply` manual.

### Step 3 — Explain
Problema: deploys manuais criam drift entre o que está no código e o que roda no cluster.
Solução: o ArgoCD observa o Git e garante que o cluster sempre reflita o repositório.

### Step 4 — Architecture Insight
```
Developer faz merge na develop
       ↓
GitHub dispara webhook
       ↓
ArgoCD detecta mudança no gitops-repo
       ↓
ArgoCD aplica os manifests no cluster EKS
       ↓
Estado do cluster = Estado do Git
```

### Step 5 — Lab Integration

Arquivos no vision-2026:
```
gitops/appsets/platform-services.yaml   ← ApplicationSet por ambiente
infra/04-platform/argocd.tf             ← instalação via Helm
backstage/platform-templates/new-service/skeleton/.github/workflows/cd.yaml
```

Abra `gitops/appsets/platform-services.yaml` e observe:
- generator `git` assistindo branch `develop` → ambiente dev
- generator `git` assistindo branch `master` → ambiente prd
- syncPolicy `automated` com `selfHeal: true`

### Step 6 — Platform Engineering Context
GitOps elimina o acesso direto ao cluster para desenvolvedores.
O dev commita código — a plataforma cuida do resto.
Isso é Developer Experience real: zero fricção, zero acesso manual.

### Step 7 — Key Insight
> "GitOps não é uma ferramenta. É o princípio de que o cluster deve ser
> um reflexo imutável do repositório. O ArgoCD é apenas a implementação."

---

## Semana 2 — Operator Pattern e Control Plane

### Fonte
Kubernetes Patterns — Capítulo Operator (Advanced Patterns)
Platform Engineering on Kubernetes — Capítulo 6

### Conceito
Operator Pattern / Reconciliation Loop

### Pattern
Controller + Custom Resource Definition

### Step 1 — Read
K8s Patterns: Operator Pattern — como estender o Kubernetes com domínio próprio.
PE on K8s Cap 6: Platform APIs — como criar abstrações para desenvolvedores.

### Step 2 — Translate
Um Operator é um controller customizado que entende o domínio da sua aplicação.
Ele observa Custom Resources (CRDs) e reconcilia o estado desejado com o estado real.
O Reconciliation Loop nunca para — é um loop infinito de observação e correção.

### Step 3 — Explain
Problema: Kubernetes sabe gerenciar Pods e Services, mas não sabe o que é um
"serviço de pagamento que precisa de RDS + S3 + repo GitHub".
Solução: você ensina o Kubernetes com um Operator que entende esse domínio.

### Step 4 — Architecture Insight
```
Dev aplica PlatformService CR no cluster
              ↓
platformservice_controller.go detecta (Reconcile loop)
              ↓
├── Cria repo GitHub (xpto-payment-service)
├── Commita 3 ArgoCD Applications (dev/hml/prd)
└── Para cada InfraResource → commita Crossplane Claim
              ↓
Estado reconciliado — Status atualizado no CR
```

### Step 5 — Lab Integration

Arquivos no vision-2026:
```
platform-api/api/v1alpha1/platformservice_types.go   ← define o CRD
platform-api/api/v1alpha1/infrarequest_types.go      ← define o CRD
platform-api/internal/controller/platformservice_controller.go  ← reconcile loop
platform-api/internal/controller/infrarequest_controller.go     ← reconcile loop
platform-api/config/crd/platformservice.yaml         ← YAML do CRD
platform-api/cmd/operator/main.go                    ← entry point do operator
```

Abra `platformservice_controller.go` e identifique:
- func `Reconcile(ctx, req)` — o loop principal
- `r.Get(ctx, req.NamespacedName, &ps)` — observa o CR
- `r.githubClient.EnsureRepo(...)` — reconcilia o estado

### Step 6 — Platform Engineering Context
O Operator Pattern transforma o Kubernetes no control plane da plataforma.
Em vez de scripts, você tem lógica declarativa e auto-healing.
Se o repo GitHub for deletado, o Operator recria — sem intervenção humana.

### Step 7 — Key Insight
> "Um Kubernetes Operator é a diferença entre uma plataforma que você opera
> e uma plataforma que se opera sozinha. O Reconciliation Loop é o coração
> de qualquer Control Plane moderno."

---

## Semana 3 — Crossplane e Infrastructure Abstraction

### Fonte
Platform Engineering on Kubernetes — Capítulo 5

### Conceito
Infrastructure as Code declarativo / Infrastructure Control Plane

### Pattern
Infrastructure Abstraction via Compositions

### Step 1 — Read
Capítulo 5: Multi-cloud infrastructure — como o Crossplane usa o mesmo
modelo de Reconciliation Loop do Kubernetes para gerenciar infra na AWS.

### Step 2 — Translate
Crossplane estende o Kubernetes para gerenciar recursos de cloud (RDS, S3, SQS)
da mesma forma que o K8s gerencia Pods. Você declara um `S3Bucket` e o Crossplane
reconcilia até que o bucket exista na AWS com as configurações corretas.

Compositions são abstrações: o dev pede um "banco de dados" sem saber se é RDS,
Aurora ou Cloud SQL. A plataforma decide.

### Step 3 — Explain
Problema: dev precisa de banco de dados. Hoje: abre ticket, aguarda 2 semanas.
Com Crossplane: aplica um YAML de 10 linhas, em 5 minutos o banco existe.
A plataforma é a intermediária entre o desejo do dev e a AWS.

### Step 4 — Architecture Insight
```
Dev cria InfraRequest CR
       ↓
infrarequest_controller.go (Operator)
       ↓
Commita Crossplane Claim no repo GitHub dedicado
       ↓
ArgoCD detecta o commit → aplica no cluster
       ↓
Crossplane Reconcile Loop → cria RDS na AWS
       ↓
Connection Secret criado no namespace da app
       ↓
App lê a connection string sem nunca ver a senha
```

### Step 5 — Lab Integration

Arquivos no vision-2026:
```
crossplane/xrds/rdsinstance.yaml          ← define a abstração
crossplane/compositions/rdsinstance.yaml  ← implementa o mapeamento para AWS
crossplane/install.sh                     ← instala providers e compositions
platform-api/internal/crossplane/manifest.go  ← gera os manifests dos Claims
```

Abra `crossplane/compositions/rdsinstance.yaml` e identifique:
- `compositeTypeRef` — qual XRD essa composition implementa
- `resources` — os recursos AWS reais que serão criados
- `patches` — como os valores do dev viram configuração AWS

### Step 6 — Platform Engineering Context
Crossplane é o Infrastructure Control Plane da plataforma.
O dev nunca acessa o console AWS. A plataforma provisiona, monitora e destrói.
`deletionPolicy: Delete` garante que o destroy limpa tudo — zero lixo na AWS.

### Step 7 — Key Insight
> "Crossplane não é Terraform. É o Kubernetes gerenciando infra.
> A diferença: Terraform é imperativo com estado em arquivo.
> Crossplane é declarativo com estado no etcd — e se auto-corrige."

---

## Semana 4 — Platform APIs e Developer Experience

### Fonte
Platform Engineering on Kubernetes — Capítulo 6 e 7
API Design Patterns — Capítulos de Resource Lifecycle

### Conceito
Platform API / Developer Self-Service

### Pattern
API as Product / Control Plane API

### Step 1 — Read
PE on K8s Cap 6: Platform APIs — a interface entre o dev e a plataforma.
API Design Patterns: Resource lifecycle — como modelar operações longas (LRO).

### Step 2 — Translate
A Platform API é a camada de abstração entre o desenvolvedor e a complexidade
da infraestrutura. O dev não precisa saber de Kubernetes, AWS ou Crossplane.
Ele usa uma API simples: "quero um serviço Python com banco de dados".

### Step 3 — Explain
Problema: o dev precisa conhecer 5 ferramentas diferentes para criar um serviço.
Solução: uma API única (Platform API) que orquestra tudo nos bastidores.
O dev é o cliente — a plataforma é o produto.

### Step 4 — Architecture Insight
```
Dev usa Backstage → preenche formulário
          ↓
Backstage chama Platform API REST /v1/services
          ↓
Platform API valida + autentica (Bearer token)
          ↓
Operator Reconcile Loop processa o PlatformService CR
          ↓
GitHub repo + ArgoCD apps + Crossplane Claims criados
          ↓
Dev recebe URL do repo + URL do ArgoCD em minutos
```

### Step 5 — Lab Integration

Arquivos no vision-2026:
```
platform-api/internal/handlers/github.go     ← handler REST para repos
platform-api/internal/handlers/argocd.go     ← handler REST para ArgoCD apps
platform-api/internal/handlers/crossplane.go ← handler REST para infra
platform-api/internal/middleware/auth.go      ← autenticação Bearer token
platform-api/internal/audit/log.go           ← auditoria de todas as ações
backstage/devops-portal/plugins/platform-broker/ ← plugin que chama a API
```

Abra `platform-api/internal/handlers/github.go` e identifique:
- validação do request
- chamada para `github.Client.EnsureRepo`
- resposta com repo URL

### Step 6 — Platform Engineering Context
A Platform API é o "product" da plataforma. O dev é o usuário.
Cada endpoint é uma capacidade de plataforma exposta como serviço.
O audit log garante rastreabilidade: quem pediu o quê, quando.

### Step 7 — Key Insight
> "Platform Engineering é Product Engineering.
> Sua API interna deve ter a mesma qualidade de UX que uma API pública.
> Se o dev precisa ler documentação para usar, a plataforma falhou."

---

## Semana 5 — Observability e DORA Metrics

### Fonte
Platform Engineering on Kubernetes — Capítulo 9
Cloud Native DevOps with Kubernetes — Capítulo Observability

### Conceito
Observability / DORA Metrics

### Pattern
Metrics → Traces → Logs (Golden Signals)

### Step 1 — Read
PE on K8s Cap 9: Measuring platforms — DORA metrics, CDEvents.
CN DevOps: como instrumentar aplicações cloud native.

### Step 2 — Translate
Observabilidade é a capacidade de entender o estado interno de um sistema
a partir de seus outputs externos (métricas, traces, logs).
DORA metrics medem a performance de entrega: Deployment Frequency,
Lead Time, MTTR e Change Failure Rate.

### Step 3 — Explain
Problema: você não sabe se a plataforma está funcionando bem.
Solução: métricas que respondem "quantos deploys por dia?" e "quanto tempo
para recuperar de um incidente?".

### Step 4 — Architecture Insight
```
Platform API expõe /metrics (Prometheus format)
       ↓
Prometheus scrape a cada 30s
       ↓
Grafana dashboard mostra:
  - Deploys por dia (Deployment Frequency)
  - Tempo médio de provisioning (Lead Time)
  - Audit log de todas as operações
```

### Step 5 — Lab Integration

Arquivos no vision-2026:
```
observability/install.sh                      ← instala Prometheus + Grafana
observability/prometheus/servicemonitor.yaml  ← scrape da Platform API
platform-api/internal/audit/log.go            ← eventos para métricas DORA
```

Próximo passo (não implementado ainda):
```
insights/dora-metrics.yaml   ← CDEvents para DORA
```

### Step 6 — Platform Engineering Context
Sem métricas, a plataforma é uma caixa preta.
DORA metrics transformam "achismo" em evidência para liderança técnica.
Um dashboard mostrando "87 deploys na semana, 0 rollbacks" é argumento
para mais investimento em plataforma.

### Step 7 — Key Insight
> "Você não pode melhorar o que não mede.
> DORA metrics são a linguagem que traduz engenharia de plataforma
> em valor de negócio."

---

## Semana 6 — Security e Governance

### Fonte
Kubernetes Patterns — Security Patterns
Cloud Native DevOps with Kubernetes — Security

### Conceito
Policy as Code / Shift-Left Security

### Pattern
Admission Control / Guardrails

### Step 1 — Read
K8s Patterns: Security patterns — como proteger workloads no K8s.
CN DevOps: como aplicar segurança sem bloquear velocidade de entrega.

### Step 2 — Translate
Policy as Code é o padrão onde as regras de governança são definidas em
arquivos versionados no Git — não em wikis ou emails.
Kyverno valida e muta recursos no momento da criação, antes de entrar no cluster.

### Step 3 — Explain
Problema: dev sobe container com tag `:latest` sem resource limits em produção.
Solução: Kyverno bloqueia o deploy antes de acontecer — com mensagem clara
explicando o que precisa ser corrigido.

### Step 4 — Architecture Insight
```
kubectl apply (ou ArgoCD sync)
       ↓
Kubernetes Admission Webhook
       ↓
Kyverno valida contra ClusterPolicies
       ├── disallow-latest-tag → BLOQUEADO se :latest
       ├── require-resource-limits → BLOQUEADO sem limits
       ├── require-labels → BLOQUEADO sem labels obrigatórias
       └── require-probes → BLOQUEADO sem liveness/readiness
       ↓
Aprovado → recurso entra no cluster
```

### Step 5 — Lab Integration

Arquivos no vision-2026:
```
guardrails/kyverno/disallow-latest-tag.yaml    ← bloqueia :latest
guardrails/kyverno/require-labels.yaml         ← labels obrigatórias
guardrails/kyverno/require-probes.yaml         ← liveness + readiness
guardrails/kyverno/require-resource-limits.yaml← cpu/memory obrigatórios
guardrails/kyverno/install.sh                  ← instalação
```

Abra `require-resource-limits.yaml` e conecte com:
Kubernetes Patterns — Predictable Demands (Cap 2)

### Step 6 — Platform Engineering Context
Guardrails não são barreiras — são proteções que permitem velocidade segura.
O dev não precisa saber as melhores práticas de K8s. A plataforma garante.
Isso é Developer Experience: liberdade com segurança embutida.

### Step 7 — Key Insight
> "Governance sem automação é só burocracia.
> Kyverno transforma políticas de segurança em código executável —
> aplicado consistentemente, sem depender de revisão humana."

---

## Mapa completo Conceito → Lab

| Conceito | Pattern | Arquivo no vision-2026 | Livro / Cap |
|---|---|---|---|
| GitOps | Declarative Deployment | `gitops/appsets/` | PE on K8s Cap 4 |
| Operator | Controller + Reconcile | `platform-api/internal/controller/` | K8s Patterns — Operator |
| CRD | Configuration Resource | `platform-api/api/v1alpha1/` | K8s Patterns — Config Resource |
| Crossplane | Infrastructure Control Plane | `crossplane/compositions/` | PE on K8s Cap 5 |
| Platform API | API as Product | `platform-api/internal/handlers/` | PE on K8s Cap 6 |
| CI/CD | Service Pipeline | `.github/workflows/ci.yaml + cd.yaml` | PE on K8s Cap 3 |
| Observability | Golden Signals | `observability/` | PE on K8s Cap 9 |
| Policy as Code | Admission Control | `guardrails/kyverno/` | K8s Patterns — Security |
| Health Probe | Liveness + Readiness | `require-probes.yaml` | K8s Patterns Cap 4 |
| Resource Limits | Predictable Demands | `require-resource-limits.yaml` | K8s Patterns Cap 2 |
| IDP | Developer Self-Service | `backstage/` | PE on K8s Cap 1 |
| Audit Log | Traceability | `platform-api/internal/audit/` | API Design Patterns |

---

## Como estudar com o lab ativo

Quando o lab estiver provisionado (`./deploy.sh` completo):

```bash
# Semana 1 — observe o GitOps em ação
kubectl get applications -n argocd -w

# Semana 2 — veja o Operator reconciliando
kubectl logs -n platform deployment/platform-operator -f

# Semana 3 — acompanhe o Crossplane provisionando
kubectl get managed --all-namespaces -w

# Semana 4 — teste a Platform API
curl https://platform-api.devopstia.com/v1/health
curl -H "Authorization: Bearer $TOKEN" \
     https://platform-api.devopstia.com/v1/audit

# Semana 5 — explore as métricas
open https://grafana.devopstia.com

# Semana 6 — teste uma policy violation
kubectl run test --image=nginx:latest -n default
# Esperado: BLOCKED por disallow-latest-tag
```

---

## Progresso

| Semana | Tópico | Status |
|---|---|---|
| 1 | GitOps e Environment Pipelines | 🔲 |
| 2 | Operator Pattern e Control Plane | 🔲 |
| 3 | Crossplane e Infrastructure Abstraction | 🔲 |
| 4 | Platform APIs e Developer Experience | 🔲 |
| 5 | Observability e DORA Metrics | 🔲 |
| 6 | Security e Governance | 🔲 |
