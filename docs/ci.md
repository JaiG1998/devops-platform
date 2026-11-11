# CI/CD Pipeline & Quality Gates Documentation

This repository uses a secure, automated CI/CD pipeline powered by **GitHub Actions** and **AWS OIDC** authentication to enforce code quality, security standards, and infrastructure correctness before changes merge into `main`.

---

## 1. Pipeline Overview

On every Pull Request, the pipeline runs the following parallel validation gates:
1. **Terraform Format (`fmt`):** Ensures all `.tf` files adhere to standard HCL styling conventions.
2. **Terraform Validate (`validate`):** Initializes local backend validation to check syntax, references, and parameter structures.
3. **TFlint (`tflint`):** Scans Terraform code recursively using the AWS ruleset to catch deprecated attributes, unused variables, and best-practice violations.
4. **Checkov (`checkov`):** Performs Static Application Security Testing (SAST) against your infrastructure code to catch misconfigurations (e.g., unencrypted storage, public S3 buckets).
5. **Terraform Plan (`plan`):** Generates an infrastructure execution plan using secure OIDC role assumption and posts/updates a collapsible summary comment directly on the Pull Request.

---

## 2. Running Checks Locally

To maintain development velocity and ensure your local changes pass all CI gates before pushing, use the provided `Makefile` targets from the repository root.

### Prerequisites
Make sure you have the following tools installed locally:
* `terraform`
* `tflint`
* `checkov`

### Available Makefile Commands
* **Format Check:** Checks if your files match canonical formatting.
  ```bash
  make fmt
  ```

* **Validation:** Recursively runs terraform init and validate across your module directories.

  ```bash
  make validate
  ```

* **Linting:** Executes tflint recursively.

  ```bash
  make tflint
  ```

* **Security Scanning: Runs checkov against your configuration files.

  ```bash
  make checkov
  ```

* **Run All Local CI Checks: Executes all verification steps sequentially.

  ```bash
  make ci-local
  ```