#!/usr/bin/env bash
set -euo pipefail

NAMESPACE_DIR="${1:-k8s/namespaces}"
kubectl apply -f "${NAMESPACE_DIR}"
kubectl get ns -l app.kubernetes.io/part-of=online-boutique --show-labels