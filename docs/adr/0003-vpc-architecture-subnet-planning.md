# ADR-0003: VPC Module Architecture and Subnet Planning

* **Status:** Accepted  
* **Date:** 2026-11-04
- **Deciders:** Jai Gupta  

---

## Context

To run EKS clusters reliably across `dev`, `staging`, and `prod` environments, we need a clean, structured VPC foundation. Standard EKS networking (AWS VPC CNI) assigns secondary IP addresses from private subnets directly to Pods, requiring careful upfront planning for subnet capacity, multi-AZ deployment, NAT Gateway costs, and CIDR allocation.

---

## Key Decisions

### 1. Custom Module vs. Community Module
* **Decision:** Write a custom, lightweight Terraform VPC module instead of using `terraform-aws-modules/vpc`.
* **Rationale:** As this is a learning project focused on mastering underlying infrastructure, building a module from scratch provides a clear understanding of the dependencies between VPCs, Internet Gateways, Route Tables, Subnets, and NAT Gateways. Keeping the module deliberately small ensures easy code reviews and manageable maintenance.

### 2. CIDR Allocation Strategy
* **Decision:** Allocate distinct, non-overlapping `/16` CIDR blocks for each environment to facilitate future VPC peering or transit gateway integration without IP collisions.

| Environment | VPC CIDR Block | Description |
| :--- | :--- | :--- |
| `dev` | `10.10.0.0/16` | Development / Sandbox cluster workloads |
| `staging` | `10.20.0.0/16` | Staging / Pre-production validation |
| `prod` | `10.30.0.0/16` | Production workload isolation |

### 3. Subnet Sizing & EKS IP Capacity
* **Decision:** Assign `/20` subnets to private subnets and `/24` subnets to public subnets per Availability Zone across 3 AZs.
* **Rationale:** EKS Pods consume IP addresses directly from private subnets via the AWS VPC CNI. 
  * **Private Subnets (`/20`):** Provides ~4,091 usable IPs per AZ to prevent IP exhaustion under heavy container scaling.
  * **Public Subnets (`/24`):** Provides ~251 usable IPs per AZ, sufficient for load balancers and NAT Gateways.

### 4. NAT Gateway Strategy
* **Decision:** Use a single shared NAT Gateway for `dev` environments, controlled via an input variable (`single_nat_gateway = true`).
* **Rationale:** Highly available production setups require one NAT Gateway per AZ (3 total), but for a learning environment, a single shared NAT Gateway significantly reduces hourly AWS infrastructure costs while maintaining internet connectivity for private subnets.

### 5. Availability Zone Selection
* **Decision:** Dynamically discover active AWS Availability Zones using the `aws_availability_zones` data source instead of hardcoding zone names (e.g., `us-east-1a`).
* **Rationale:** Guarantees portability across different AWS regions and accounts where AZ naming mappings differ.

---

## Consequences

* **Pros:** Deep hands-on learning, reduced AWS running costs during development, robust CIDR plan preventing IP conflicts, and automated multi-AZ placement.
* **Cons:** Custom module code requires direct maintenance and does not automatically pull upstream bug fixes or enhancements from community modules. Single NAT Gateway setup in `dev` creates a single point of failure for outbound internet traffic across AZs (acceptable trade-off for dev).