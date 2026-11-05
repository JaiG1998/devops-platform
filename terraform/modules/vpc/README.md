# Custom AWS VPC Terraform Module

A lightweight, production-ready, and education-focused Terraform module that provisions an Amazon VPC optimized for containerized workloads (such as Amazon EKS) with multi-AZ support, dynamic CIDR slicing, flexible NAT strategies, and an integrated S3 Gateway Endpoint.

---

## Architecture Layout & Diagram

The module dynamically provisions network components across active Availability Zones (AZs) using Terraform data sources and the `cidrsubnet()` function.

```text
               +---------------------------------------------------------+
               |                       AWS VPC                           |
               |                     (10.10.0.0/16)                      |
               |                                                         |
   [ Internet ]<-----> (Internet Gateway) <-------------------------+    |
               |             |                                       |    |
               |             +----------------------------+          |    |
               |                                          |          |    |
               |    +-----------------------+   +---------v-------+  |    |
               |    | Public Subnet AZ-1    |   | Public Subnet   |  |    |
               |    | (10.10.0.0/24)        |   | AZ-2            |  |    |
               |    |                       |   | (10.10.1.0/24)  |  |    |
               |    +-----------+-----------+   +--------+--------+  |    |
               |                |                        |           |    |
               |                +-- [NAT Gateway] <------+           |    |
               |                     (Elastic IP)                    |    |
               |                          |                          |    |
               |    +---------------------+-----------------------+  |    |
               |    |                     |                       |  |    |
               |    v                     v                       v  |    |
               | +--+------------------+ +----------------------+  |    |
               | | Private Subnet AZ-1 | | Private Subnet AZ-2  |  |    |
               | | (10.10.16.0/20)     | | (10.10.32.0/20)      |  |    |
               | | [EKS Pods / Nodes]  | | [EKS Pods / Nodes]   |  |    |
               | +---------------------+ +----------------------+  |    |
               |                                                         |
               +---------------------------------------------------------+
                                            ^
                                            | (Bypasses NAT)
                                    [ S3 Gateway Endpoint ]