# ADR-0005: GitHub Actions CI/CD Pipeline Strategy for Terraform

## Status
Approved

## Context
We are implementing a modular, custom AWS EKS infrastructure utilizing Terraform. To ensure robust code quality, compliance, and automated validation before merging changes into the `main` branch, we need a standardized GitHub Actions CI/CD pipeline. 

The pipeline must support pull request validation for formatting, syntax, static code analysis (linting), security scanning (`checkov`), and a live `terraform plan` execution. Applying changes remains a manual operator action for now.

---

## Decision Drivers
1. **Developer Experience & Feedback Speed:** Failures must be caught early and clearly isolated in parallel jobs.
2. **Security & Compliance:** Prevent misconfigurations and compliance drift using automated static security analysis.
3. **Least-Privilege Security:** The CI runner requires precise IAM permissions to run a Terraform plan and acquire state locks without granting broad administrator privileges.
4. **Maintenance & Stability:** Third-party actions and CLI tools must be pinned to exact versions to prevent breaking changes.

---

## Considered Options

### 1. Job Layout
* **Option A: Single monolithic job with sequential steps.** Simpler to write, but slower because failures don't isolate clearly, and it prevents granular branch protection rules per check.
* **Option B: Parallel per-check jobs (Selected).** Separate jobs for formatting, validation, linting, security, and planning. Allows independent status checks in GitHub branch protection.

### 2. Checkov Enforcement Strategy
* **Option A: Soft-fail indefinitely.** Low friction, but security findings accumulate and are ignored over time.
* **Option B: Immediate hard-fail from day one.** Blocks all PRs until resolved, causing high developer friction and frustration.
* **Option C: Triaged Baseline with Written Suppressions (Selected).** Implement a soft-fail or structured triage period, require inline code suppressions with a written justification (`#checkov:skip=<id>: reason`), and subsequently enforce hard-failures.

### 3. Path Filtering & PR Status Management
* **Option A: Run on all PRs unconditionally.** Safe, but wastes runner minutes when non-Terraform files change.
* **Option B: Path filters (`paths: ['terraform/**']`) with branch protection.** Saves time, but if a PR touches only application code, the required Terraform status checks remain "pending" forever, blocking the merge.
* **Option C: Conditional execution / Always run with cheap early exit (Selected).** Use path filters on lightweight jobs, or configure jobs to skip gracefully while satisfying branch protection requirements.

### 4. Least-Privilege Plan Role Permissions
* **Option A:** Attach `AdministratorAccess` to the CI IAM role for simplicity. (Rejected: Violates security best practices).
* **Option B (Selected):** Provide read-only permissions for AWS resources refreshed during a plan, combined with precise read/write access to the S3 state backend and DynamoDB lock table.

---

## Decision Outcome

1. **Job Layout:** We choose **Per-check parallel jobs** (`fmt`, `validate`, `tflint`, `checkov`, `plan`) to maximize feedback speed and granularity for branch protection rules.
2. **Execution Scope:** The CI pipeline triggers exclusively on pull requests targeting `envs/dev` when Terraform files under `terraform/**` are modified.
3. **Checkov Enforcement:** We utilize Checkov with structured inline suppressions (`#checkov:skip=<id>: reason`). Global rules are enforced with a zero-tolerance policy for unsuppressed high-severity findings.
4. **Path Filtering:** Path filters will target `terraform/**` with explicit handling to ensure branch protection checks do not lock out non-infrastructure PRs.
5. **Plan Permissions:** The CI IAM role is restricted to read access on target infrastructure services and read/write access on the Terraform remote state S3 bucket and locking table.
6. **Version Pinning:** We explicitly pin all third-party GitHub Actions, CLI versions (Terraform, TFLint, Checkov), and provider versions.