# ADR-0006: Use Helm for Online Boutique Kubernetes Deployments

- **Status:** Accepted
- **Date:** 2026-11-12
- **Deciders:** Jai Gupta

## Context

The Online Boutique application consists of 11 polyglot microservices that require consistent deployment, configuration management, and lifecycle orchestration across multiple Kubernetes environments (local development, staging, and production). We need a standardized packaging and templating tool to manage environment-specific overrides (such as replica counts, resource limits, and external service endpoints like Redis or Google Cloud Operations) without duplicating raw Kubernetes YAML manifests. 

Constraints shaping this decision include minimizing operational overhead, leveraging existing team familiarity with Go templating, and maintaining compatibility with upstream Online Boutique charts and CI/CD pipelines.

## Decision

We will use **Helm** as the standard packaging and deployment management tool for the Online Boutique application across all environments. We will structure the deployment using an umbrella chart or unified chart with environment-specific `values-*.yaml` files to manage configuration differences.

## Options considered

### Helm (chosen)
- **Pros:**
  - **First-class Upstream Support:** Google's Online Boutique repository officially maintains a robust, well-tested Helm chart, reducing initial setup and ongoing maintenance effort.
  - **Rich Templating & Logic:** Go templating allows conditional creation of resources (e.g., toggling Istio ServiceEntries, NetworkPolicies, or managed Redis vs. in-cluster Redis) using simple boolean flags in `values.yaml`.
  - **Release & Lifecycle Management:** Built-in versioning, atomic upgrades, and one-command rollbacks (`helm rollback`) provide strong operational safety guarantees.
  - **Packaging & Distribution:** Charts can be versioned and published to OCI-compliant registries, creating immutable deployment artifacts.
- **Cons:**
  - **Template Complexity:** Heavy use of Go templating and helper functions (`_helpers.tpl`) can make generated YAML harder to read and debug statically.
  - **Client-side/Tillerless State:** Helm stores release metadata in Kubernetes Secrets, which adds cluster state overhead and requires RBAC management.

### Kustomize
- **Pros:**
  - **Template-Free YAML:** Operates on pure, valid Kubernetes manifests using strategic merge patches and JSON patches, making base files easy to validate and read.
  - **Native `kubectl` Integration:** Built directly into `kubectl apply -k`, requiring no additional CLI binaries or release state secrets in the cluster.
- **Cons:**
  - **Verbose Patching for Polyglot Microservices:** Managing toggles across 11 distinct microservices (e.g., swapping out environment variables or sidecar injections across all deployments) requires repetitive patch files.
  - **Lack of Lifecycle & Rollback Features:** Kustomize is purely a manifest generator; it does not track release history or support native rollbacks without external GitOps controllers (e.g., ArgoCD or Flux).
  - **Higher Maintenance Drift:** Adapting upstream Online Boutique changes requires manually reconciling overlay patches rather than upgrading a versioned chart.

## Consequences

**Positive**
- **Accelerated Delivery:** Teams can immediately leverage the upstream Online Boutique Helm chart structure and customize deployments via clean `values.yaml` overrides.
- **Simplified Environment Parity:** Promoting a release from staging to production requires only changing the values file and image tags, ensuring structural consistency.
- **Safer Deployments:** Built-in `helm upgrade --atomic` and `helm rollback` capabilities reduce Mean Time to Recovery (MTTR) during failed deployments.

**Negative / risks**
- **Risk: Over-complicated templates.** Adding too many custom conditional blocks to the chart can degrade readability.
  - *Mitigation:* Enforce `helm template` and `helm lint` checks in CI pipelines, and keep custom logic minimal by relying on standard `values.yaml` overrides.
- **Risk: Configuration drift between environments.** Divergent `values-*.yaml` files can lead to unexpected behavior in production.
  - *Mitigation:* Maintain a strict schema (`values.schema.json`) to validate required configurations and types before deployment.

## Revisit when

- We adopt a pure GitOps workflow (such as ArgoCD or Flux) where declarative cluster state management replaces Helm's imperative release tracking, and the complexity of maintaining custom Helm templates outweighs the benefits of Kustomize overlays.
- The upstream Online Boutique repository deprecates its official Helm chart in favor of Kustomize bases.
