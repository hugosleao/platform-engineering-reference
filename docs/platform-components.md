# Platform Components

> Reference for each component: what it does, why it was chosen, and how it connects to the rest of the platform.

---

## Component Map

```
┌─────────────────────────────────────────────────────────────────┐
│                     Developer Interface                         │
│                         Backstage                               │
└───────────────────────────┬─────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│                      Control Plane                              │
│                Platform API (Go Operator)                       │
│            GitHub App · PlatformService CRD                     │
└──────┬────────────────────┬────────────────────────┬────────────┘
       │                    │                        │
┌──────▼──────┐    ┌────────▼────────┐    ┌──────────▼──────────┐
│   GitHub    │    │    ArgoCD       │    │    Crossplane        │
│ Repos · CI  │    │  GitOps Engine  │    │  Infra Abstraction   │
└─────────────┘    └────────┬────────┘    └──────────┬──────────┘
                            │                        │
                   ┌────────▼────────┐               │
                   │    Kyverno      │               │
                   │  Policy Layer   │               │
                   └────────┬────────┘               │
                            │                        │
                   ┌────────▼────────────────────────▼──────────┐
                   │             EKS Runtime                     │
                   │    Namespaces · Workloads · Secrets         │
                   └───────────────────────────┬─────────────────┘
                                               │
                                    ┌──────────▼──────────┐
                                    │    AWS Cloud         │
                                    │  RDS · S3 · SQS      │
                                    └─────────────────────┘
```

---

## Backstage — Developer Portal

| Property | Value |
|---|---|
| **Role** | Self-service interface — software catalog, templates, scorecards |
| **Created by** | Spotify (2020), donated to CNCF (2022) |
| **Used by** | 3000+ companies — Spotify, American Airlines, Zalando, Siemens |
| **Auth** | GitHub App OAuth (same App used by Platform API) |
| **Catalog** | Auto-registers services created by Platform API |
| **Templates** | Java Spring Boot, Python FastAPI (extensible) |

**Key integrations:**
- Platform API plugin → calls `/api/v1/services` to create services
- ArgoCD plugin → shows deployment status per service
- GitHub → reads `catalog-info.yaml` from each repo

---

## Platform API — Go Operator

| Property | Value |
|---|---|
| **Role** | Control plane — receives intent, reconciles state |
| **Language** | Go 1.22 + `controller-runtime` v0.18 |
| **Pattern** | Kubernetes Operator (level-triggered reconciliation) |
| **CRDs** | `PlatformService`, `InfraRequest` |
| **Auth to GitHub** | GitHub App JWT (RS256, 10-minute tokens) |
| **Build** | GitHub Actions (Kaniko) — no local Docker required |
| **Deploy** | EKS `platform` namespace, IAM Pod Identity for AWS access |

See [control-plane.md](control-plane.md) for full design.

---

## ArgoCD — GitOps Engine

| Property | Value |
|---|---|
| **Role** | Watches `gitops-repo`, syncs desired state to EKS |
| **Version** | 2.x |
| **Pattern** | Pull-based GitOps (ArgoCD polls Git, not push) |
| **Multi-env** | ApplicationSets — one definition → dev/hml/prd applications |
| **Access** | `https://argocd.devopstia.com` |

**ApplicationSet strategy:**

```yaml
# One ApplicationSet generates 3 ArgoCD Applications
generators:
  - list:
      elements:
        - env: dev    branch: develop    namespace: payment-service-dev
        - env: hml    branch: release/*  namespace: payment-service-hml
        - env: prd    branch: master     namespace: payment-service-prd
```

---

## Crossplane — Infrastructure Abstraction

| Property | Value |
|---|---|
| **Role** | Translates Kubernetes Claims → AWS resources |
| **Version** | 2.0 |
| **Provider** | `provider-aws` (official, maintained by Upbound) |
| **Resources** | RDS PostgreSQL, S3 Bucket, SQS Queue |
| **Pattern** | XRD (schema) + Composition (implementation) |

**How it works:**

```
Developer writes:
  kind: Database
  spec: { engine: postgres, size: small }

Crossplane creates:
  AWS RDS PostgreSQL (db.t3.micro, Multi-AZ: false for lab)
  Connection string → K8s Secret (auto-injected into namespace)
```

Developer never sees Terraform, CloudFormation or AWS console.

---

## Kyverno — Policy Engine

| Property | Value |
|---|---|
| **Role** | Admission webhook — enforces platform standards at deploy time |
| **Mode** | Enforce (hard block) + Audit (report only) |
| **Policies** | 4 active policies |

| Policy | Type | Effect |
|---|---|---|
| `require-labels` | ClusterPolicy | Enforce — rejects pods without `app`, `owner`, `team` |
| `require-resource-limits` | ClusterPolicy | Enforce — rejects pods without CPU/memory limits |
| `disallow-latest-tag` | ClusterPolicy | Enforce — rejects `:latest` image tags |
| `require-probes` | ClusterPolicy | Audit — reports pods without health probes |

---

## GitHub — Source of Truth

| Property | Value |
|---|---|
| **Role** | Stores all state: code, workflows, GitOps manifests |
| **Auth** | Single GitHub App — catalog, CI/CD, Platform API, Backstage auth |
| **Repos** | `gitops-repo` (ArgoCD), `platform-templates` (Backstage), one repo per service |

**Single GitHub App strategy:**

One App with scopes for: `contents`, `pull_requests`, `checks`, `metadata`, `workflows`.
Used by: Platform API (JWT), Backstage (OAuth), GitHub Actions (OIDC).

No PATs. No user-bound tokens. Full audit trail.

---

## cert-manager + Route53 — TLS Automation

| Property | Value |
|---|---|
| **Role** | Automatic TLS certificates for all platform services |
| **Issuer** | Let's Encrypt (prod) via DNS-01 challenge |
| **DNS** | Route53 — cert-manager creates TXT records automatically |
| **Result** | Every service gets `*.devopstia.com` HTTPS, zero manual steps |

---

## Terraform — Base Infrastructure

| Property | Value |
|---|---|
| **Role** | Provisions base AWS infrastructure (not changed at runtime) |
| **Modules** | `00-backend`, `01-vpc`, `02-eks`, `03-networking`, `04-platform` |
| **State** | S3 + DynamoDB (auto-detected by `setup.sh`) |
| **Auth** | AWS IAM user (`serveless-user`) for initial provisioning |

Terraform is used **once** to build the platform foundation.
Everything that changes at runtime (services, infra for services) goes through Crossplane.

---

## Prometheus + Grafana — Observability

| Property | Value |
|---|---|
| **Role** | Metrics collection and visualization |
| **Stack** | `kube-prometheus-stack` Helm chart |
| **Dashboards** | Platform API operations, ArgoCD sync status, application metrics |
| **Access** | `https://grafana.devopstia.com` |

Platform API exposes `/metrics` in Prometheus format.
Grafana shows: reconciliation duration, CRD creation rate, GitHub API error rate, Crossplane claim status.

---

## EKS — Runtime Platform

| Property | Value |
|---|---|
| **Version** | 1.31 |
| **Node type** | SPOT `t3.medium` (cost-optimized for lab) |
| **Node count** | 2 (auto-scaling 2–4) |
| **Storage** | EBS gp3 (PostgreSQL PVC) |
| **Networking** | AWS VPC CNI, NGINX Ingress |
| **Estimated cost** | ~$0.30/hour when running |
