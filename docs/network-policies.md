# Network Policies Documentation

This document describes the Kubernetes NetworkPolicy objects that enforce communication rules for the Online Boutique application.

## Architecture Overview

The following diagram illustrates the service dependencies and allowed communication flows:

```
graph TD
    %% Entry Point
    Client((User / Browser)) -->|HTTP / Port 8080| Frontend[frontend]

    %% Frontend calls downstream gRPC services
    Frontend -->|gRPC| ProductCatalog[productcatalogservice]
    Frontend -->|gRPC| Cart[cartservice]
    Frontend -->|gRPC| Currency[currencyservice]
    Frontend -->|gRPC| Recommendation[recommendationservice]
    Frontend -->|gRPC| Shipping[shippingservice]
    Frontend -->|gRPC| Ad[adservice]
    Frontend -->|gRPC| Checkout[checkoutservice]

    %% Checkout service orchestration
    Checkout -->|gRPC| Cart
    Checkout -->|gRPC| ProductCatalog
    Checkout -->|gRPC| Currency
    Checkout -->|gRPC| Shipping
    Checkout -->|gRPC| Payment[paymentservice]
    Checkout -->|gRPC| Email[emailservice]

    %% Stateful and Support Services
    Cart -->|TCP / Redis Protocol| Redis[(redis-cart)]
    Frontend -->|gRPC| LoadGen[loadgenerator]

    subgraph Namespace Boundary
        Frontend
        ProductCatalog
        Cart
        Currency
        Recommendation
        Shipping
        Ad
        Checkout
        Payment
        Email
        Redis
        LoadGen
    end
```

## Dependency Table

The following table lists every allowed network flow derived from the service environment variables in the Helm chart values.yaml:

| Source Service | Destination Service | Port | Protocol | Direction |
| -------------- | ------------------- | ---- | -------- | --------- |
| Frontend | ProductCatalog | 3550 | TCP | Egress |
| Frontend | Cart | 7070 | TCP | Egress |
| Frontend | Currency | 7000 | TCP | Egress |
| Frontend | Recommendation | 8080 | TCP | Egress |
| Frontend | Shipping | 50051 | TCP | Egress |
| Frontend | Ad | 9555 | TCP | Egress |
| Frontend | Checkout | 5050 | TCP | Egress |
| Frontend | LoadGen | 8080 | TCP | Egress |
| Cart | Redis | 6379 | TCP | Egress |
| Checkout | Cart | 7070 | TCP | Egress |
| Checkout | ProductCatalog | 3550 | TCP | Egress |
| Checkout | Currency | 7000 | TCP | Egress |
| Checkout | Shipping | 50051 | TCP | Egress |
| Checkout | Payment | 50051 | TCP | Egress |
| Checkout | Email | 8080 | TCP | Egress |
| Payment | Email | 8080 | TCP | Egress |

## Default-Deny Policy

The baseline posture is **deny all ingress and egress** in the application namespace. This policy is applied first, and then minimal allow rules are added based on the dependency table above.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress: []
  egress: []
```

## DNS Egress Policy

Allow DNS resolution (UDP and TCP port 53) to the cluster DNS pods using namespace selector:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: default
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

## Per-Service Ingress Rules

### Redis - ingress only from Cart service

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: redis-ingress-from-cart
  namespace: default
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: cartservice
  egress: []
```

### Per-Service Egress Rules to Dependencies

Each service has egress allow rules to its declared dependencies based on the env vars:

```yaml
# Example template for per-service egress rules
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: <service>-egress-allowances
  namespace: default
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - selector:
            app.kubernetes.io/name: <destination-service>
      ports:
        - protocol: TCP
          port: <destination-port>
```

## External Access / Frontend

**Important:** There is no ingress controller configured yet. External access to the frontend is documented as a **placeholder**. Currently, access is reached via `kubectl port-forward`.

### Frontend Port-Forward Verification

With NetworkPolicies applied, `kubectl port-forward` should still work because port-forward uses the API server proxy, not nodeport/services of type ClusterIP subject to NetworkPolicy rules. However, verify that:

1. The frontend service remains `ClusterIP` type (not `NodePort` or `LoadBalancer`)
2. Port-forward continues to function after policies are applied

```bash
kubectl port-forward svc/frontend 8080:8080 -n default
```

## Rollout Strategy

Policies are applied incrementally:

1. **Step 1**: Apply `deny-all` policy and observe what breaks
2. **Step 2**: Add DNS egress policy (`allow-dns-egress`)
3. **Step 3**: Add per-service ingress/egress rules one service at a time
4. **Step 4**: Verify full functionality

Use stable labels in selectors (`app.kubernetes.io/name` from Helm chart labels) and document them in this file.

### Load Generator Policy

The load generator has egress only to the frontend:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: loadgenerator-egress-frontend
  namespace: default
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - selector:
            matchLabels:
              app.kubernetes.io/name: frontend
      ports:
        - protocol: TCP
          port: 8080
```

## Stable Labels for Selectors

All deployments generated by the Helm chart use the following stable labels:

- `app.kubernetes.io/name`: The service name (e.g., `frontend`, `cartservice`, `redis`)
- `app.kubernetes.io/component`: The component type
- `app.kubernetes.io/instance`: Release name

NetworkPolicy selectors should use `app.kubernetes.io/name` to target specific services.

## Troubleshooting

If a service cannot communicate after policies are applied:

1. Check that the target pods have the expected labels
2. Verify the NetworkPolicy `policyTypes` include the correct direction (Ingress/Egress)
3. Ensure port numbers match exactly between the service definition and the policy
4. Use `kubectl describe networkpolicy <policy-name>` to debug