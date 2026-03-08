# ${{ values.name }}

${{ values.description }}

**Time:** ${{ values.team }} | **Runtime:** ${{ values.runtime }} | **Sigla:** ${{ values.sigla }}

---

## Estrutura do projeto

```
.
├── .github/
│   └── workflows/
│       ├── ci.yaml       ← build + test + sonar (toda branch)
│       └── cd.yaml       ← push ECR + deploy (develop/release/master)
├── .pipeline.yaml        ← account_id por ambiente
├── src/                  ← código-fonte
├── Dockerfile
└── pom.xml
```

---

## GitFlow — Como fazer deploy

Dois workflows separados. Regra simples:

| Branch | CI | Deploy | Ambiente |
|---|---|---|---|
| `feature/*` | ✅ | ❌ | — |
| `fix/*` | ✅ | ❌ | — |
| `develop` | ✅ | ✅ | DEV |
| `release/*` | ✅ | ✅ | HML |
| `master` | ✅ | ✅ | PRD |

### Fluxo no dia a dia

```bash
# Nova funcionalidade
git checkout develop
git checkout -b feature/minha-feature

git push origin feature/minha-feature
# → ci.yaml roda (build + test + sonar) — sem deploy

# Merge em develop → deploy automático no DEV
# Cria release/1.0.0 → deploy automático no HML
# Merge em master → deploy automático no PRD
```

> `feature/*` e `fix/*` **nunca** fazem deploy.
> Apenas `develop`, `release/*` e `master` acionam o CD.

---

## CI — O que roda em toda branch

```bash
# ci.yaml executa:
mvn clean verify          # build + testes unitários
mvn sonar:sonar           # qualidade de código
```

## CD — O que roda nas branches de entrega

```bash
# cd.yaml executa (apenas develop, release/*, master):
# 1. Determina ambiente pela branch (dev/hml/prd)
# 2. OIDC → AWS STS → role temporária (sem credencial estática)
# 3. docker build + push ECR com tag {env}-{sha}
# 4. Atualiza image-tag.yaml no gitops-repo
# 5. ArgoCD detecta mudança → sync automático
```

---

## Desenvolvimento local

```bash
mvn clean install
mvn spring-boot:run
```

---

## Infraestrutura provisionada

Os recursos abaixo foram criados via Crossplane ao registrar o serviço no Backstage.
A connection string já está injetada como variável de ambiente — sem configuração manual.

| Recurso | Nome | Env var |
|---|---|---|
| RDS PostgreSQL | ${{ values.name }}-db | `DB_URL`, `DB_USER`, `DB_PASS` |
| SQS Queue | ${{ values.name }}-queue | `SQS_QUEUE_URL` |

> Adicionar novos recursos: acesse o Backstage → Catalog → ${{ values.name }} → **Add Resource**
