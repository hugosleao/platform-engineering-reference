# ADR 001 — Control Plane Architecture

**Status:** Accepted  
**Date:** 2026-01

---

## Context

The platform must provide self-service infrastructure and application delivery for developers.
Initial approaches considered:

1. Plain REST API — Backstage calls endpoints that trigger Terraform/scripts
2. Pure GitOps broker — Backstage writes directly to Git
3. Kubernetes Operator (control plane) — desired state declared as CRD, platform reconciles

The platform needs to guarantee that when a developer requests a service, the system converges to the correct state even in the face of partial failures (GitHub API down, ArgoCD unavailable, etc).

---

## Decision

Adopt a **control plane architecture using Kubernetes Operators** (`controller-runtime`).

Developers submit intent as a `PlatformService` CRD.
The Operator reconciles continuously until actual state matches desired state.

---

## Consequences

**Positive**
- Declarative platform model — intent is always visible in `kubectl get platformservice`
- Self-healing — partial failures are retried automatically on next reconciliation cycle
- Audit trail — CRD `.status` tracks every provisioning step
- Kubernetes-native — operates like any other controller (Crossplane, Flux, cert-manager)
- Observable — Prometheus metrics on reconciliation duration, error rate, queue depth

**Trade-offs**
- Requires Go knowledge to extend (vs simpler Python/Node scripts)
- Operator must run inside EKS — not suitable for bootstrap phase
- More complex than a simple REST-to-Git bridge for simple use cases
