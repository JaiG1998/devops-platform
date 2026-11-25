# RBAC Access Grant / Revoke Runbook

## Grant Access (give a human IAM role access to Online Boutique namespaces)

### Prerequisites
- AWS CLI configured with sufficient permissions
- `kubectl` configured to target the correct EKS cluster
- IAM role ARN identified (see below)

### Steps to Grant Access

1. **Identify the role ARN** — obtain the IAM role ARN that needs Kubernetes access.

2. **Add the role to the EKS Access Entry** — ensure the role is included in the appropriate Terraform variable:
   - **Viewer access**: add ARN to `viewer_role_arns` in `terraform/envs/<env>/main.tf`
   - **Developer access**: add ARN to `developer_role_arns` in `terraform/envs/<env>/main.tf`
   - **Admin access**: add ARN to `admin_role_arns` in `terraform/envs/<env>/main.tf`

3. **Apply Terraform changes** — from the repository root:
   ```bash
   terraform init
   terraform apply
   ```
   This will create the `aws_eks_access_entry` and `aws_eks_access_policy_association` resources, mapping the IAM role to the appropriate Kubernetes group (`online-boutique-viewers`, `online-boutique-developers`, or `online-boutique-admins`).

4. **Verify access** — test with `kubectl`:
   ```bash
   # As the newly-granted user/role:
   kubectl auth can-i get pods --as=<user> --as-group=online-boutique-viewers --namespace=online-boutique-dev
   kubectl auth can-i create deployment --as=<user> --as-group=online-boutique-developers --namespace=online-boutique-dev
   kubectl auth can-i get pods --as=<user> --as-group=online-boutique-admins --namespace=online-boutique-prod
   ```

## Revoke Access (remove a human IAM role's Kubernetes access)

### Steps to Revoke Access

1. **Remove the role from the EKS Access Entry** — edit `terraform/envs/<env>/main.tf` and remove the ARN from the appropriate variable (`viewer_role_arns`, `developer_role_arns`, or `admin_role_arns`).

2. **Apply Terraform changes** — from the repository root:
   ```bash
   terraform init
   terraform apply -target=aws_eks_access_entry.<resource> -target=aws_eks_access_policy_association.<resource>
   ```
   Or simply run `terraform apply` to refresh the state.

3. **Verify revocation** — confirm access is denied:
   ```bash
   kubectl auth can-i get pods --as=<user> --as-group=online-boutique-viewers --namespace=online-boutique-dev
   # Should return "no"
   ```

## Debugging a "Forbidden" Error

When a user reports `forbidden` or `access denied` errors, follow these steps:

1. **Check the user's group membership** — verify the user is associated with the correct Kubernetes group:
   ```bash
   kubectl auth can-i get pods --as=<user> --as-group=<group-name> --namespace=<ns>
   ```

2. **Check the RoleBinding/ClusterRoleBinding** — confirm the group is bound to the correct Role/ClusterRole:
   ```bash
   kubectl get rolebinding <binding-name> -n <namespace> -o yaml
   kubectl get clusterrolebinding <binding-name> -o yaml
   ```

3. **Check the ServiceAccount** — verify the `serviceAccountName` on the pod matches the expected account, and that the account is in the correct namespace:
   ```bash
   kubectl get pod <pod-name> -o yaml | grep serviceAccountName
   kubectl describe sa <sa-name> -n <namespace>
   ```

4. **Check the EKS Access Entry** — confirm the IAM role has an access entry:
   ```bash
   # Via AWS CLI
   aws eks list-access-entries --cluster-name <cluster-name> --region <region>
   aws eks list-access-policy-associations --cluster-name <cluster-name> --region <region>
   ```

5. **Check for namespace scope** — remember that viewer/developer policies are namespace-scoped (`access_scope type = "namespace"`). The user must be in the correct namespace for the rules to apply.

6. **Check for `automountServiceAccountToken`** — ensure the pod's ServiceAccount has `automountServiceAccountToken: false` if token-based access is not needed (this project's default).

7. **Debug with `kubectl describe`** — use `kubectl describe timeout ...` or `kubectl get events` to see if authorization failures are logged.

8. **Re-apply Terraform** — after any changes to access entries or policy associations, always run `terraform apply` to propagate changes to the EKS control plane (may take a few minutes).