# ADR-0002: Terraform Remote State Storage and Locking Strategy

- **Status:** Accepted
- **Date:** 2026-10-22
- **Deciders:** Jai Gupta

## Context and Problem Statement

To manage infrastructure safely and collaboratively using Terraform, we need a reliable backend for storing Terraform state files (`.tfstate`). The backend must support concurrent access prevention (locking), secure data storage (encryption), environment isolation, and follow AWS naming conventions to avoid global S3 bucket name collisions.


## Decision Drivers

* **Operational Simplicity:** Minimize unnecessary resource management (e.g., maintaining additional services).
* **Cost Efficiency:** Avoid unexpected costs for low-complexity or learning environments.
* **Security & Isolation:** Ensure state data is encrypted and environments are appropriately separated.
* **AWS & Terraform Standards:** Align with current best practices and avoid deprecated patterns.


## Considered Options & Decisions

### 1. State Locking Method

* **Option A:** AWS S3 Native State Locking (`use_lockfile = true`)
* **Option B:** AWS DynamoDB Table Locking

#### **Decision:** Option A — AWS S3 Native State Locking

* **Rationale:** 
  * S3 native locking removes the operational overhead and cost of creating and managing a dedicated DynamoDB state locking table.
  * Native S3 locking is fully supported in Terraform 1.10 and newer via S3 conditional writes.
  * DynamoDB locking is legacy functionality that is being phased out in newer Terraform workflows.


### 2. S3 Bucket Structure & Environment Isolation

* **Option A:** Single S3 bucket with path-based isolation (`dev/`, `staging/`, `prod/`)
* **Option B:** Separate S3 buckets per environment (e.g., `dev-bucket`, `prod-bucket`)

#### **Decision:** Option A — Single S3 Bucket with Path-Based Isolation

* **Rationale:** 
  * For a single-account setup or early-stage learning project, managing a single S3 bucket keeps backend configuration and deployment scripts clean and simple.
  * Key paths (`dev/terraform.tfstate`, `staging/terraform.tfstate`, `prod/terraform.tfstate`) provide logical separation without the clutter of multi-bucket provisioning.
  * *Future Consideration:* If moving to a multi-account architecture or strict privilege-separated production environment, transitioning to separate buckets per environment/account will be evaluated.


### 3. State File Encryption

* **Option A:** Server-Side Encryption with Amazon S3 Managed Keys (`SSE-S3`)
* **Option B:** AWS Key Management Service with Customer Managed Keys (`SSE-KMS`)

#### **Decision:** Option A — SSE-S3 Encryption (`AES256`)

* **Rationale:** 
  * `SSE-S3` meets basic compliance and security requirements by encrypting state data at rest without additional cost or key policy complexity.
  * `SSE-KMS` adds extra KMS API costs and requires explicit key permissions setup, which is unnecessary for this scale of project.


### 4. S3 Bucket Naming Strategy

#### **Decision:** Use globally unique naming convention with Account ID and Region

* **Format:** `<project>-tfstate-<account-id>-<region>`
* **Example:** `myproject-tfstate-123456789012-us-east-1`
* **Rationale:** 
  * S3 bucket names are globally unique across all AWS accounts.
  * Including the AWS Account ID and Region prevents collisions across organizations, developer accounts, and deployments.

### 5. Bootstrap State Management Strategy

* **Decision:** Option A — Local state management for the bootstrap configuration.
* **Rationale:** 
  * The bootstrap configuration consists primarily of the S3 state bucket and associated policies, which are deployed once and rarely change.
  * Storing bootstrap state locally avoids circular dependencies (managing an S3 bucket's state inside that same S3 bucket).
  * Local state for bootstrap is safe as long as the generated `terraform.tfstate` file is kept secure and excluded from version control via `.gitignore`.

## Consequences

### Positive
* **Lower Overhead:** No extra AWS resources (DynamoDB or KMS keys) to deploy or track.
* **Zero Additional Cost:** Leverages free tier-friendly S3 native encryption and locking features.
* **Clean Naming:** Standardized naming convention prevents naming conflicts.

### Negative / Trade-offs
* **Prerequisite Dependency:** Requires Terraform CLI version `1.10+` for S3 native locking support.
* **Access Boundary:** A single bucket relies on strict IAM path-level policies if different developers need access restricted to specific environment paths.