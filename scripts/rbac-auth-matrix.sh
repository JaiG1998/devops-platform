#!/usr/bin/env bash
set -euo pipefail

# RBAC Authorization Matrix Test Script
# Tests kubectl auth can-i for viewer, developer, and admin groups
# across both dev and prod namespaces

NAMESPACE_DEV="online-boutique-dev"
NAMESPACE_PROD="online-boutique-prod"

# expected[role][action] = "allow" or "deny"
declare -A EXPECTED_DEV=(
  ["viewer.get.pods"]="allow"
  ["viewer.list.pods"]="allow"
  ["viewer.watch.pods"]="allow"
  ["viewer.create.pods"]="deny"
  ["viewer.delete.pods"]="deny"
  ["viewer.read.secrets"]="deny"
  ["viewer.exec.pods"]="deny"
  ["developer.get.pods"]="allow"
  ["developer.create.deployments"]="allow"
  ["developer.exec.pods"]="allow"
  ["developer.read.secrets"]="deny"
  ["developer.delete.pods"]="allow"
  ["admin.get.pods"]="allow"
  ["admin.create.deployments"]="allow"
  ["admin.read.secrets"]="allow"
  ["admin.delete.pods"]="allow"
)

declare -A EXPECTED_PROD=(
  ["viewer.get.pods"]="allow"
  ["viewer.read.secrets"]="deny"
  ["developer.create.deployments"]="allow"
  ["developer.read.secrets"]="deny"
  ["admin.get.pods"]="allow"
  ["admin.read.secrets"]="allow"
  ["admin.list.namespaces"]="allow"
)

PASS=0
FAIL=0

assert_test() {
  local test_name="$1"
  local expected="$2"
  local result="$3"

  # Normalize: kubectl returns "yes" or "no" (or empty)
  local normalized_result
  if [ "$result" = "yes" ]; then
    normalized_result="allow"
  elif [ "$result" = "no" ]; then
    normalized_result="deny"
  else
    normalized_result="unknown"
  fi

  if [ "$normalized_result" = "$expected" ]; then
    echo "PASS: $test_name (expected=$expected, got=$normalized_result)"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $test_name (expected=$expected, got=$normalized_result)"
    FAIL=$((FAIL + 1))
  fi
}

# Helper: run kubectl auth can-i and capture result
can_i() {
  local user_as="$1"
  local as_group="$2"
  local namespace="$3"
  local resource="$4"
  local verb="$5"
  local output
  # Use --ignore-not-found to avoid errors; capture stdout only
  output=$(kubectl auth can-i "${verb}" "${resource}" --as="${user_as}" --as-group="${as_group}" --namespace="${namespace}" 2>/dev/null) || true
  # Extract just the yes/no from output (kubectl may include warnings)
  output=$(echo "$output" | grep -oE '\b(yes|no)\b' | head -1)
  if [ -z "$output" ]; then
    output="no"
  fi
  echo "$output"
}

echo "============================================"
echo "RBAC Authorization Matrix Tests"
echo "============================================"
echo ""

# ---- DEV NAMESPACE TESTS ----
echo "--- Dev Namespace Tests ---"

# --- Viewer role tests ---
echo "Viewer group (online-boutique-viewers):"
result=$(can_i "system:serviceaccount:${NAMESPACE_DEV}:default" "online-boutique-viewers" "${NAMESPACE_DEV}" "pods" "get")
assert_test "Viewer: get pods (dev)" "${EXPECTED_DEV[viewer.get.pods]}" "$result"

result=$(can_i "system:serviceaccount:${NAMESPACE_DEV}:default" "online-boutique-viewers" "${NAMESPACE_DEV}" "pods" "list")
assert_test "Viewer: list pods (dev)" "${EXPECTED_DEV[viewer.list.pods]}" "$result"

result=$(can_i "system:serviceaccount:${NAMESPACE_DEV}:default" "online-boutique-viewers" "${NAMESPACE_DEV}" "pods" "watch")
assert_test "Viewer: watch pods (dev)" "${EXPECTED_DEV[viewer.watch.pods]}" "$result"

result=$(can_i "system:serviceaccount:${NAMESPACE_DEV}:default" "online-boutique-viewers" "${NAMESPACE_DEV}" "pods" "create")
assert_test "Viewer: create pods (dev)" "${EXPECTED_DEV[viewer.create.pods]}" "$result"

result=$(can_i "system:serviceaccount:${NAMESPACE_DEV}:default" "online-boutique-viewers" "${NAMESPACE_DEV}" "pods" "delete")
assert_test "Viewer: delete pods (dev)" "${EXPECTED_DEV[viewer.delete.pods]}" "$result"

result=$(can_i "system:serviceaccount:${NAMESPACE_DEV}:default" "online-boutique-viewers" "${NAMESPACE_DEV}" "secrets" "get")
assert_test "Viewer: read secrets (dev - should be denied)" "${EXPECTED_DEV[viewer.read.secrets]}" "$result"

result=$(can_i "system:serviceaccount:${NAMESPACE_DEV}:default" "online-boutique-viewers" "${NAMESPACE_DEV}" "pods" "exec")
assert_test "Viewer: exec into pods (dev - should be denied)" "${EXPECTED_DEV[viewer.exec.pods]}" "$result"

# --- Developer role tests ---
echo ""
echo "Developer group (online-boutique-developers):"
result=$(can_i "system:serviceaccount:${NAMESPACE_DEV}:default" "online-boutique-developers" "${NAMESPACE_DEV}" "pods" "get")
assert_test "Developer: get pods (dev)" "${EXPECTED_DEV[developer.get.pods]}" "$result"

result=$(can_i "system:serviceaccount:${NAMESPACE_DEV}:default" "online-boutique-developers" "${NAMESPACE_DEV}" "deployments" "create")
assert_test "Developer: create deployment (dev)" "${EXPECTED_DEV[developer.create.deployments]}" "$result"

result=$(can_i "system:serviceaccount:${NAMESPACE_DEV}:default" "online-boutique-developers" "${NAMESPACE_DEV}" "pods" "exec")
assert_test "Developer: exec into pods (dev)" "${EXPECTED_DEV[developer.exec.pods]}" "$result"

result=$(can_i "system:serviceaccount:${NAMESPACE_DEV}:default" "online-boutique-developers" "${NAMESPACE_DEV}" "secrets" "get")
assert_test "Developer: read secrets (dev - should be denied)" "${EXPECTED_DEV[developer.read.secrets]}" "$result"

result=$(can_i "system:serviceaccount:${NAMESPACE_DEV}:default" "online-boutique-developers" "${NAMESPACE_DEV}" "pods" "delete")
assert_test "Developer: delete pods (dev)" "${EXPECTED_DEV[developer.delete.pods]}" "$result"

# --- Admin role tests ---
echo ""
echo "Admin group (online-boutique-admins):"
result=$(can_i "system:serviceaccount:${NAMESPACE_DEV}:default" "online-boutique-admins" "${NAMESPACE_DEV}" "pods" "get")
assert_test "Admin: get pods (dev)" "${EXPECTED_DEV[admin.get.pods]}" "$result"

result=$(can_i "system:serviceaccount:${NAMESPACE_DEV}:default" "online-boutique-admins" "${NAMESPACE_DEV}" "deployments" "create")
assert_test "Admin: create deployment (dev)" "${EXPECTED_DEV[admin.create.deployments]}" "$result"

result=$(can_i "system:serviceaccount:${NAMESPACE_DEV}:default" "online-boutique-admins" "${NAMESPACE_DEV}" "secrets" "get")
assert_test "Admin: read secrets (dev)" "${EXPECTED_DEV[admin.read.secrets]}" "$result"

result=$(can_i "system:serviceaccount:${NAMESPACE_DEV}:default" "online-boutique-admins" "${NAMESPACE_DEV}" "pods" "delete")
assert_test "Admin: delete pods (dev)" "${EXPECTED_DEV[admin.delete.pods]}" "$result"

# ---- PROD NAMESPACE TESTS ----
echo ""
echo "--- Prod Namespace Tests ---"

# --- Viewer role tests ---
echo "Viewer group (online-boutique-viewers):"
result=$(can_i "system:serviceaccount:${NAMESPACE_PROD}:default" "online-boutique-viewers" "${NAMESPACE_PROD}" "pods" "get")
assert_test "Viewer: get pods (prod)" "${EXPECTED_PROD[viewer.get.pods]}" "$result"

result=$(can_i "system:serviceaccount:${NAMESPACE_PROD}:default" "online-boutique-viewers" "${NAMESPACE_PROD}" "secrets" "get")
assert_test "Viewer: read secrets (prod - should be denied)" "${EXPECTED_PROD[viewer.read.secrets]}" "$result"

# --- Developer role tests ---
echo ""
echo "Developer group (online-boutique-developers):"
result=$(can_i "system:serviceaccount:${NAMESPACE_PROD}:default" "online-boutique-developers" "${NAMESPACE_PROD}" "deployments" "create")
assert_test "Developer: create deployment (prod)" "${EXPECTED_PROD[developer.create.deployments]}" "$result"

result=$(can_i "system:serviceaccount:${NAMESPACE_PROD}:default" "online-boutique-developers" "${NAMESPACE_PROD}" "secrets" "get")
assert_test "Developer: read secrets (prod - should be denied)" "${EXPECTED_PROD[developer.read.secrets]}" "$result"

# --- Admin role tests ---
echo ""
echo "Admin group (online-boutique-admins):"
result=$(can_i "system:serviceaccount:${NAMESPACE_PROD}:default" "online-boutique-admins" "${NAMESPACE_PROD}" "pods" "get")
assert_test "Admin: get pods (prod)" "${EXPECTED_PROD[admin.get.pods]}" "$result"

result=$(can_i "system:serviceaccount:${NAMESPACE_PROD}:default" "online-boutique-admins" "${NAMESPACE_PROD}" "namespaces" "list")
assert_test "Admin: list another namespace (prod)" "${EXPECTED_PROD[admin.list.namespaces]}" "$result"

# ---- SUMMARY ----
echo ""
echo "============================================"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
  echo "SOME TESTS FAILED"
  exit 1
else
  echo "ALL TESTS PASSED"
  exit 0
fi