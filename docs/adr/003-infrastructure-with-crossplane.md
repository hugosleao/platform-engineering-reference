# ADR 003 — Infrastructure Abstraction with Crossplane

**Status:** Accepted  
**Date:** 2026-01

---

## Context

Developers should be able to request cloud infrastructure (databases, queues, storage) without:
- Writing Terraform
- Opening AWS console
- Creating support tickets

Options evaluated:

1. Terraform modules triggered by CI/CD
2. AWS Service Catalog
3. Crossplane XRDs + Compositions (Kubernetes-native)

Key requirements:
- Infrastructure request must follow the same GitOps loop as application deployments
- Connection strings must be injected automatically as Kubernetes Secrets
- Developer API must be Kubernetes-native (same tools as application delivery)

---

## Decision

Use **Crossplane 2.0 with XRDs and Compositions** to abstract cloud infrastructure.

Developers submit a Kubernetes Claim (e.g., `kind: Database`).
Crossplane Compositions translate the Claim into AWS resources (RDS, S3, SQS).
Connection strings are automatically written to a Kubernetes Secret in the service namespace.

---

## Consequences

**Positive**
- Infrastructure request follows the same GitOps loop (no separate Terraform pipeline)
- Developer API is Kubernetes-native — same `kubectl` + GitOps workflow
- Connection strings auto-injected — no secrets management burden on developers
- Crossplane is CNCF graduated — mature, production-ready
- Compositions can enforce organizational standards (instance sizes, encryption, backup policies) transparently

**Trade-offs**
- Crossplane Compositions are complex to author (requires deep knowledge of AWS provider CRDs)
- Crossplane must be running in the cluster before any Claims can be fulfilled
- State is managed by Crossplane — destroying the Crossplane provider deletes all managed resources
- More operational overhead than Terraform for simple one-time provisioning
