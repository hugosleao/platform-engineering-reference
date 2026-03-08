# Architecture Principles

The platform is designed using the following principles:

- **Self-service over ticket-driven infrastructure** — developers provision resources through a portal, not tickets
- **GitOps as the source of truth** — every desired state lives in Git; nothing is configured imperatively
- **Control planes instead of imperative automation** — the Platform API continuously reconciles desired vs actual state
- **Infrastructure exposed as APIs** — Crossplane XRDs abstract cloud resources behind Kubernetes CRDs
- **Policy enforcement at the platform layer** — Kyverno enforces standards automatically at admission time
- **Zero static credentials** — GitHub Actions OIDC + AWS STS, GitHub App JWT, no PATs

---

## Design Decisions

Architecture Decision Records document the key choices made in this platform.
See [docs/adr/](docs/adr/) for the full list.

| ADR | Decision | Status |
|---|---|---|
| [001](docs/adr/001-control-plane-architecture.md) | Control Plane Architecture using Kubernetes Operators | Accepted |
| [002](docs/adr/002-gitops-with-argocd.md) | GitOps with ArgoCD as deployment engine | Accepted |
| [003](docs/adr/003-infrastructure-with-crossplane.md) | Infrastructure abstraction with Crossplane | Accepted |

---

## Reference Reading

- **Platform Engineering on Kubernetes** — Mauricio Salatino (Manning)
- **Kubernetes Patterns** — Bilgin Ibryam & Roland Huß (O'Reilly)
- **Platform Engineering with Go** — Nels Lutiy (O'Reilly)
- [CNCF Platforms White Paper](https://tag-app-delivery.cncf.io/whitepapers/platforms/)
