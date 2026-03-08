# ADR 002 — GitOps with ArgoCD

**Status:** Accepted  
**Date:** 2026-01

---

## Context

Deployments must be auditable, reproducible and decoupled from CI pipelines.
Options evaluated:

1. Push-based deployment (CI pipeline runs `kubectl apply`)
2. Flux CD (pull-based GitOps, CNCF graduated)
3. ArgoCD (pull-based GitOps, CNCF graduated, UI + ApplicationSets)

Key requirements:
- Multi-environment support (dev / hml / prd) from a single definition
- Visual dashboard for developers to see deployment status
- Integration with Backstage catalog

---

## Decision

Use **ArgoCD with ApplicationSets** as the GitOps deployment engine.

One `ApplicationSet` definition generates three ArgoCD Applications automatically, one per environment, driven by GitFlow branch mapping.

---

## Consequences

**Positive**
- Git is the single source of truth for cluster state — no out-of-band changes survive
- ApplicationSets eliminate per-environment duplication
- ArgoCD UI gives developers direct visibility into sync status, diff and rollback
- Full audit trail — every sync is logged with Git commit SHA
- Backstage ArgoCD plugin shows deployment status in the catalog

**Trade-offs**
- ArgoCD must be running inside the cluster (not suitable for external cluster management without additional config)
- ApplicationSet branch-based generator requires predictable GitFlow conventions
- Adds operational complexity vs simple `kubectl apply` for small teams
