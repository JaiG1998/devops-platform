# ADR-0008: NetworkPolicy Enforcement Approach for EKS and kind

- **Status:** Accepted
- **Date:** 2026-11-26
- **Deciders:** Jai Gupta

## Context

This project requires Kubernetes NetworkPolicies to be actually enforced across both EKS and kind clusters. The goal is to have standard NetworkPolicy objects work consistently in both environments without vendor-specific CRDs.

**Key constraints:**
- NetworkPolicies must enforce (not just be accepted silently)
- Must work the same way in both EKS and kind
- No vendor CRDs (use standard K8s NetworkPolicy API only)
- Prefer native solutions where possible (least extra to run)

## Decision

### EKS: Native VPC CNI network policy support

**Chosen approach:** Enable network policy enforcement via the AWS VPC CNI add-on's `configuration_values` parameter, setting `enableNetworkPolicy = true`.

**Why:**
- Kubernetes 1.35 already deployed (well above the minimum 1.24 requirement)
- AWS VPC CNI >= 1.11.0 supports the `enableNetworkPolicy` feature flag
- No additional CNI software to install or manage
- Behave consistently with standard K8s NetworkPolicy objects
- Least extra infrastructure required ("Native means the least extra to run")

**Implementation:** Added `configuration_values = jsonencode({ enableNetworkPolicy = true })` to the `aws_eks_addon.vpc_cni` resource in `terraform/modules/eks/addon.tf`.

### kind: Disable default CNI, install Calico with pinned version

**Chosen approach:** After cluster creation, disable the default kubenet CNI and install Calico v3.25.0 with network policy support.

**Why:**
- `kubenet` (the default kind CNI) does NOT enforce NetworkPolicy objects - policies are accepted but have no effect
- Calico is a widely-adopted CNI that provides full NetworkPolicy enforcement
- Can pin the version for reproducibility
- Behaves consistently with EKS's native VPC CNI implementation
- Standard K8s NetworkPolicy objects work the same way in both environments

**Implementation:**
1. Updated `k8s/kind/kind-config.yaml` with documentation note about Calico setup
2. Created Calico manifests under `k8s/kind/calico/`:
   - `namespace.yaml` - required namespaces
   - `rbac.yaml` - RBAC for calico-node
   - `deployment.yaml` - Calico node deployment with NetworkPolicy enabled
   - `configmap.yaml` - Calico configuration
3. Calico installed via: `kubectl apply -f k8s/kind/calico/`

## Options considered

### Option A: Keep kubenet in kind, document that NetworkPolicies don't enforce
- **Pros:** No additional setup, zero cost
- **Cons:** NetworkPolicies accepted but silently ignored - violates the core requirement; defeats the purpose of having policies

### Option B: Keep kubenet in kind, use NodeNetworkPolicy (Calico CRD)
- **Pros:** No need to disable kubenet
- **Cons:** Uses Calico CRDs (projectcalico.org), violates "no vendor CRDs" requirement; behavior differs from EKS native CNI

### Option C: Disable default CNI, install Calico with pinned version (CHOSEN)
- **Pros:** Standard K8s NetworkPolicy objects enforce in both places; consistent behavior; industry-standard CNI; pinned version for reproducibility
- **Cons:** Additional setup steps; requires Calico installation; slightly more complex kind cluster init

## Consequences

### Positive
- NetworkPolicies are actually enforced in both EKS and kind clusters
- Standard K8s NetworkPolicy API used consistently in both environments
- No vendor lock-in or CRD-specific resources in manifests
- EKS uses native CNI setting (no extra software)
- kind uses Calico with pinned version for reproducibility
- Canary test script (`scripts/netpol-canary.sh`) validates enforcement

### Negative / risks
- kind cluster requires additional Calico installation steps
- Calico adds some resource overhead (typically ~200m CPU, ~128Mi memory per node)
- Must remember to install Calico when spinning up new kind clusters
- If Caligo version becomes incompatible, may need to update pinned version

## Revisit when

- AWS changes the VPC CNI `enableNetworkPolicy` behavior or requirements
- A new CNI emerges that offers better performance or features
- The project migrates to a different Kubernetes version
- Need to support clusters where Calico cannot be installed

**Related:** ADR-0004 (EKS Architecture), kind-config.yaml, terraform/modules/eks/addon.tf, scripts/netpol-canary.sh