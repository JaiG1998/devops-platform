# ADR-0004: Amazon EKS Cluster Architecture, Security, and Access Design

* **Status:** Accepted  
* **Date:** 2026-11-05 
* **Deciders:** Jai Gupta 

---

## Context

To transition from raw network infrastructure (VPC) to a fully functional container orchestration layer, we must establish the core architectural configuration for our Amazon EKS cluster. Because this is a learning-focused project optimized for maximum skill acquisition and cost efficiency, every component choice balances real-world enterprise applicability against unnecessary operational or financial overhead.

---

## Key Decisions

### 1. Custom Module vs. Community Module (`terraform-aws-modules/eks`)
* **Decision:** Build a custom, lightweight Terraform EKS module from scratch.
* **Rationale:** While the upstream community EKS module is industry-standard, it is massive, heavily abstracted, and undergoes frequent major interface shifts. Writing our own lean configuration exposes the raw interactions between the EKS control plane, IAM cluster roles, OIDC providers, worker node groups, and networking security groups.

### 2. Kubernetes Version Selection
* **Decision:** Pin the Kubernetes version to **`1.35`** via an input variable.
* **Rationale:** AWS EKS supports versions currently in standard support (such as `1.35`, `1.36`, and `1.37`). Selecting `1.35` guarantees full feature parity and bug fixes without entering **Extended Support**, which levies an additional penalty charge of **$0.50 per cluster-hour** ($0.60 total).

### 3. Cluster Endpoint Access & Home IP Management
* **Decision:** Use a public cluster endpoint restricted exclusively to a personal IP whitelist (`public_access_cidrs`), leaving private-only access disabled.
* **Rationale:** A fully private cluster requires a complex jump host, Bastion, or AWS Client VPN setup, adding significant cost and configuration friction for a single-person learning project. Restricting the public endpoint to your current public IP via `public_access_cidrs` provides a secure, practical compromise.
* **Operational Note:** Since home dynamic IP addresses change periodically, update your local IP in your terraform variables file (`var.public_access_cidrs = ["YOUR_CURRENT_IP/32"]`) and run `terraform apply` when access fails due to an IP change.

### 4. Cluster Access Method (Access Entries vs. `aws-auth` ConfigMap)
* **Decision:** Configure authentication mode as `API_AND_CONFIG_MAP` (or strictly `API`) and provision native **EKS Access Entries** to grant the administrator role `cluster-admin`.
* **Rationale:** The legacy `aws-auth` ConfigMap workflow is being deprecated in favor of native EKS Access Entries. Managing access through `aws_eks_access_entry` and `aws_eks_access_policy_association` provides modern, robust AWS IAM-to-Kubernetes RBAC mapping aligned with modern enterprise standards.

### 5. Pod IAM Method (IRSA vs. EKS Pod Identity)
* **Decision:** Implement **IRSA (IAM Roles for Service Accounts)** using an OIDC provider and service account annotations.
* **Rationale:** While newer EKS Pod Identity agents simplify setup for greenfield clusters, IRSA remains universally deployed across legacy and modern enterprise environments. Mastering OIDC trust relationships, thumbprints, and service account annotations provides deep fundamental knowledge of cloud-native security federation. *(Note: EKS Pod Identity is fully recognized as the newer alternative).*

### 6. Node Sizing & Instance Allocation
* **Decision:** Use `t3.medium` instances (2 vCPUs, 4 GiB RAM) across our multi-AZ private subnets, bound by strict pod density limits.
* **Rationale:** Provides an economical footprint for learning workloads while adhering to the AWS VPC CNI networking constraint where maximum pod density is strictly governed by the underlying instance type's network interface limits.

### 7. Control Plane Logging & Secrets Encryption
* **Decision:** 
  * Enable critical control plane log types: `api`, `audit`, and `authenticator`.
  * Set CloudWatch log retention to **7 days**.
  * **Omit** a dedicated customer-managed KMS key for envelope secrets encryption at rest.
* **Rationale:** Enabling core log types is essential for debugging and security visibility. Setting a short 7-day retention window avoids accumulating unnecessary CloudWatch storage costs. Omitting a dedicated KMS key prevents a flat $1/month resource fee plus KMS request costs, prioritizing cost-efficiency for a dev learning environment while accepting the default AWS-managed encryption.

---

## Consequences & Checkov Security Waivers

* **Pros:** Complete transparency into EKS mechanics, minimized AWS billing footprint (no extended support fees, no dedicated KMS costs, single NAT gateway), and alignment with modern EKS Access Entry standards.
* **Cons / Accepted Risks:** 
  * Using a restricted public endpoint creates a minor external attack surface if home IP ranges are overly broad.
  * Omitting custom KMS secrets encryption triggers standard static analysis (**Checkov**) warnings regarding Kubernetes secret storage, which are explicitly accepted for this non-production learning scope via inline code suppressions (`# bridgecheck:skip=CKV_AWS_39`).