# ADR-0007: RBAC Model — Per-Service ServiceAccounts + Human Roles via EKS Access Entries

**Status:** Accepted  
**Date:** 2026-11-25  
**Deciders:** Jai Gupta  

## Context

This repository runs the Google Online Boutique microservices demo on Kubernetes. The need to control human access to the cluster while giving each microservice its own ServiceAccount drove this decision. Previously, all 11 services shared a single ServiceAccount with no human RBAC (only cluster-admin via the administrator's IAM role). This ADR replaces that model with per-service isolation and granular human role management.

## Decision

### 1. Per-Service ServiceAccounts (Option A)

- **Choice:** Each of the 11 Online Boutique services gets its own `ServiceAccount` named `<service>-sa` (e.g., `adservice-sa`, `frontend-sa`), with `automountServiceAccountToken: false`.
- **Rationale:**
  - Eliminates the "confused deputy" risk — no service can impersonate another or the default ServiceAccount.
  - Aligns with the principle of least privilege: services only have access they absolutely need (none, since Online Boutique services don't call the Kubernetes API).
  - The Helm chart now generates 11 `ServiceAccount` objects (one per enabled service) and each Deployment sets `serviceAccountName: <name>-sa` explicitly.
- **Consequences:** Slightly more YAML surface area (11 SA objects vs 1), but significantly improved security posture. No `Role`/`RoleBinding` is bound to these service SAs (they have no Kubernetes API access).

### 2. Human RBAC via EKS Access Entries + Kubernetes Groups (Option A)

- **Choice:** Human access (viewer, developer, admin) is granted through AWS IAM roles mapped to Kubernetes groups via EKS Access Entries → `aws_eks_access_entry` + `aws_eks_access_policy_association`. Each group is bound to a `Role` (viewer/developer, namespaced) or `ClusterRole` (admin, cluster-wide) using `RoleBinding`/`ClusterRoleBinding`.

- **Role set and mappings:**

  | Human Role | Kubernetes Group | Bound Resource | RBAC Object | Policy (EKS access entry) |
  |------------|----------------|----------------|-------------|--------------------------|
  | **viewer** | `online-boutique-viewers` | Namespaced (dev/prod) | `Role online-boutique-viewer` + `RoleBinding online-boutique-viewers` | `AmazonEKSViewPolicy`, `access_scope = namespace` |
  | **developer** | `online-boutique-developers` | Namespaced (dev/prod) | `Role online-boutique-developer` + `RoleBinding online-boutique-developers` | `AmazonEKSEditPolicy`, `access_scope = namespace` |
  | **admin** | `online-boutique-admins` | Cluster-wide | `ClusterRole online-boutique-admin` + `ClusterRoleBinding online-boutique-admins` | `AmazonEKSClusterAdminPolicy`, `access_scope = cluster` |

- **Rationale (Option A over Option B):**
  - The issue explicitly asks for fine-grained control: "no exec in prod", "developer: no secret reads", "viewer: read-only including logs".
  - EKS-managed access policies (`AmazonEKSViewPolicy`/`EditPolicy`/`AdminPolicy`) are coarse-grained and cannot express "no exec in prod" per-namespace or "developer no secret reads". They grant the named permission scope globally or per-namespace but not with selective denials.
  - Custom Roles give the exact control needed: the developer Role omits `secrets` verbs entirely (RBAC additive = no secret access), and the viewer Role omits `create/update/delete` on all resources.
  - The Terraform module is small: two new variables (`viewer_role_arns`, `developer_role_arns`) and three new resources per role (`aws_eks_access_entry`, `aws_eks_access_policy_association`).

- **Consequences:** More Terraform and YAML to author compared to managed policies, but the trade-off is precise, auditable control that matches the project's security requirements. The admin role retains cluster-admin via the existing `admin_role_arns` mechanism (no change needed).

### 3. ServiceAccount-Only for Online Boutique Services

- **Choice:** The Online Boutique services do not call the Kubernetes API, so each service gets a ServiceAccount with `automountServiceAccountToken: false` but **no** Roles or RoleBindings bound to them.
- **Rationale:** Following the principle of least privilege — the services' ServiceAccounts exist purely for identity if some future add-on requires it, but they have no cluster access.

## Consequences

### Positive
- **Per-service ServiceAccount isolation** eliminates cross-service permission leakage.
- **Fine-grained human RBAC**: viewer (get/list/watch pods + read logs), developer (create/update/delete pods+deployments + exec/port-forward, no secrets), admin (full cluster access, break-glass only).
- **No wildcard verbs or resources** anywhere in the RBAC rules.
- **Small Terraform footprint**: two new input variables, three new resources per role group, mapping through existing EKS Access Entry infrastructure.
- **Auditability**: IAM role → Access Entry → Kubernetes Group → RoleBinding → Role rules is a clear, traceable chain.
- **Checkov/tflint/Hellman compliance**: all existing gates pass; no new wildcard rules introduced.

### Negative / Risks
- **Operational overhead**: 11 ServiceAccounts + 6 RBAC objects (2 Roles × 2 namespaces + 1 ClusterRole + 2 RoleBindings × 2 namespaces + 1 ClusterRoleBinding) vs the previous single SA + no human RBAC.
- **Terraform state changes**: Adding `viewer_role_arns`/`developer_role_arns` variables and access entry resources will change the Terraform plan; existing `admin_role_arns` users will continue to work unchanged.
- **Misconfigured group bindings**: If the Kubernetes `RoleBinding`/`ClusterRoleBinding` is missing or the group name is mismatched, IAM roles will not grant access — debugging requires checking both the EKS access entries and the K8s bindings.
- **Namespace scoping**: Viewer/developer policies are namespace-scoped. A user in the wrong namespace (e.g., viewer in prod when they expected dev) will appear denied. The runbook documents this.

## Revisit When

- We adopt a pure GitOps workflow (ArgoCD/Flux) where cluster state is managed declaratively and the RBAC model is reconciled by the GitOps tool.
- The upstream Online Boutique repository changes its service communication patterns and services start calling the Kubernetes API directly (would require Roles bound to service SAs).
- AWS introduces new managed access policies that can express selective denials (e.g., "view secrets except...").

---

## Related

- **ADR-0004:** EKS Architecture — defines `access_config` and `API_AND_CONFIG_MAP` authentication mode.
- **ADR-0006:** Helm for Online Boutique Deployments — charts the Helm packaging tool decision.
- **Runbook:** `docs/runbooks/rbac-access.md` — grant/revoke access and debug forbidden errors.
- **Terraform module:** `terraform/modules/eks/` — access entries and policy associations.
- **Script:** `scripts/rbac-auth-matrix.sh` — kubectl auth can-i test matrix.
- **RBAC YAML:** `k8s/rbac-dev.yaml`, `k8s/rbac-prod.yaml`, `k8s/rolebindings-dev.yaml`, `k8s/rolebindings-prod.yaml`.