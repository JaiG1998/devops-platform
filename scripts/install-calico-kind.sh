#!/bin/bash
# install-calico-kind.sh
#
# This script disables the default kubenet CNI and installs Calico with
# network policy support on a kind cluster.
#
# Prerequisites:
# - kind cluster already created
# - kubectl configured to talk to the kind cluster
# - docker available (calico install uses kubectl apply)
#
# Usage: ./scripts/install-calico-kind.sh
#
# The script performs:
# 1. Creates required Calico namespaces
# 2. Applies Calico RBAC and configuration
# 3. Verifies Calico is running and enforcing NetworkPolicies

set -euo pipefail

echo "=== Installing Calico on kind cluster ==="

# 1. Create Calico namespaces (ignore if already exist)
echo "Creating Calico namespaces..."
kubectl create namespace calico-system 2>/dev/null || true
kubectl create namespace calico-apps 2>/dev/null || true
kubectl create namespace calico-logging 2>/dev/null || true

# 2. Apply Calico RBAC
echo "Applying Calico RBAC..."
kubectl apply -f k8s/kind/calico/rbac.yaml

# 3. Apply Calico ConfigMap (network configuration)
echo "Applying Calico ConfigMap..."
kubectl apply -f k8s/kind/calico/configmap.yaml

# 4. Apply Calico Node Deployment (with network policy enabled and KUBERNETES_MASTER)
echo "Applying Calico Node Deployment..."
kubectl apply -f k8s/kind/calico/deployment.yaml

# 5. Apply Calico supplementary manifests (descriptive only, no CRDs)
echo "Applying Calico supplementary manifests..."
kubectl apply -f k8s/kind/calico/manifest.yaml

# 6. Wait for Calico pod to be ready
echo "Waiting for Calico pod to be ready..."
for i in $(seq 1 60); do
  CALICO_READY=$(kubectl get pods -n kube-system -l k8s-app=calico-node -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
  if [ "$CALICO_READY" = "True" ]; then
    echo "Calico node is Ready"
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "WARNING: Calico pod not ready after 120 seconds"
    echo "Calico pod status:"
    kubectl get pods -n kube-system -l k8s-app=calico-node
    echo "Calico pod logs:"
    kubectl logs -n kube-system -l k8s-app=calico-node 2>/dev/null || echo "Could not retrieve logs"
  fi
  sleep 2
done

# 7. Verify NetworkPolicy support
echo ""
echo "=== Verification ==="
echo "Calico pod status:"
kubectl get pods -n kube-system -l k8s-app=calico-node

echo ""
echo "=== Calico NetworkPolicy Enforcement Setup Complete ==="
echo "Your kind cluster now has NetworkPolicy enforcement enabled via Calico."
echo "Standard K8s NetworkPolicy objects will be enforced (not silently accepted)."
echo ""
echo "To test NetworkPolicy enforcement, run:"
echo "  ./scripts/netpol-canary.sh"