#!/bin/bash
# NetworkPolicy Canary Test Script
#
# This script tests that Kubernetes NetworkPolicies are actually enforced:
# 1. Creates client and server pods in a scratch namespace
# 2. Confirms connectivity works (no policies applied)
# 3. Applies a default-deny NetworkPolicy
# 4. Confirms connectivity is blocked
# 5. Removes the NetworkPolicy
# 6. Confirms connectivity works again
#
# Usage: ./scripts/netpol-canary.sh [namespace]
#   namespace: optional, defaults to "netpol-canary"

set -euo pipefail

NAMESPACE="${1:-netpol-canary}"
IMAGE="busybox:1.36"

echo "=== NetworkPolicy Canary Test ==="
echo "Namespace: $NAMESPACE"

# Create scratch namespace if it doesn't exist
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "Creating namespace: $NAMESPACE"
  kubectl create namespace "$NAMESPACE"
fi

# Switch to the namespace
kubectl config set-context --current --namespace="$NAMESPACE"

# ============================================
# Step 1: Deploy client and server pods
# ============================================
echo ""
echo "--- Step 1: Deploy client and server pods ---"

# Deploy server pod
echo "Deploying server pod..."
kubectl run server --image="$IMAGE" --restart=Sleepy --command -- sleep 3600 >/dev/null 2>&1 || true

# Deploy client pod
echo "Deploying client pod..."
kubectl run client --image="$IMAGE" --restart=Never --command -- wget -q -O- http://server:8080 2>/dev/null | head -1 || true

# Wait for pods to be ready
echo "Waiting for pods to be ready..."
for i in $(seq 1 30); do
  SERVER_READY=$(kubectl get pod server -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
  CLIENT_READY=$(kubectl get pod client -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
  if [ "$SERVER_READY" = "True" ] && [ "$CLIENT_READY" = "True" ]; then
    echo "Both pods are Ready"
    break
  fi
  sleep 2
done

# ============================================
# Step 2: Confirm connectivity works (no policies)
# ============================================
echo ""
echo "--- Step 2: Confirm connectivity works (no policies applied) ---"

CONNECTIVITY_BEFORE=$(kubectl exec client -- wget -q -O- http://server:8080 2>/dev/null | head -1 || echo "BLOCKED")
echo "Connectivity before NetworkPolicy: $CONNECTIVITY_BEFORE"

if echo "$CONNECTIVITY_BEFORE" | grep -q "BLOCKED\|error\|failed"; then
  echo "WARNING: Connectivity already blocked before applying NetworkPolicy"
  echo "This may indicate a NetworkPolicy is already active"
fi

# ============================================
# Step 3: Apply default-deny NetworkPolicy
# ============================================
echo ""
echo "--- Step 3: Apply default-deny NetworkPolicy ---"

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: $NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  # Empty rules section = default deny for all traffic
EOF

echo "Default-deny NetworkPolicy applied"

# ============================================
# Step 4: Confirm connectivity is blocked
# ============================================
echo ""
echo "--- Step 4: Confirm connectivity is blocked ---"

CONNECTIVITY_AFTER=$(kubectl exec client -- wget -q -O- http://server:8080 2>/dev/null | head -1 || echo "BLOCKED")
echo "Connectivity after NetworkPolicy: $CONNECTIVITY_AFTER"

if echo "$CONNECTIVITY_AFTER" | grep -q "BLOCKED"; then
  echo "SUCCESS: Connectivity is blocked by default-deny NetworkPolicy"
else
  echo "FAIL: Connectivity is NOT blocked - NetworkPolicy may not be enforced"
  exit 1
fi

# ============================================
# Step 5: Remove the NetworkPolicy
# ============================================
echo ""
echo "--- Step 5: Remove NetworkPolicy ---"

kubectl delete networkpolicy default-deny -n "$NAMESPACE" 2>/dev/null || true
echo "NetworkPolicy removed"

# Wait a moment for the policy to be fully removed
sleep 2

# ============================================
# Step 6: Confirm connectivity works again
# ============================================
echo ""
echo "--- Step 6: Confirm connectivity works again ---"

CONNECTIVITY_AFTER_REMOVE=$(kubectl exec client -- wget -q -O- http://server:8080 2>/dev/null | head -1 || echo "BLOCKED")
echo "Connectivity after NetworkPolicy removed: $CONNECTIVITY_AFTER_REMOVE"

if ! echo "$CONNECTIVITY_AFTER_REMOVE" | grep -q "BLOCKED"; then
  echo "SUCCESS: Connectivity works again after NetworkPolicy removal"
else
  echo "FAIL: Connectivity still blocked after NetworkPolicy removal"
  exit 1
fi

# ============================================
# Cleanup
# ============================================
echo ""
echo "--- Cleanup ---"

# Delete pods
kubectl delete pod server client -n "$NAMESPACE" 2>/dev/null || true

# Optionally delete namespace (comment out to keep)
# kubectl delete namespace "$NAMESPACE"

echo ""
echo "=== NetworkPolicy Canary Test Complete ==="
echo "All steps passed: NetworkPolicies are properly enforced"