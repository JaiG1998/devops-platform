# Architecture Decision Records

Each ADR records one significant decision: context, options, choice, and
trade-offs. ADRs are immutable once accepted. To change a decision, write
a new ADR that supersedes the old one and update the status of both.

To add one: copy `template.md` to `NNNN-short-title.md`, fill it in, and
add a line to the index below in the same PR.

## Index

| ADR | Title | Status |
|---|---|---|
| [0001](0001-core-tooling-choices.md) | Core tooling choices (Terraform, EKS, GitHub Actions) | Accepted |
| [0002](0002-state-file-locking-choices.md) | Terraform state Locking choices (Terraform, EKS, GitHub Actions) | Accepted |
| [0003](0003-vpc-architecture-subnet-planning.md) | VPC Architecture and Subnet Planning (Terraform, EKS, GitHub Actions) | Accepted |
| [0004](0004-eks-architecture.md) | EKS Architecture (Terraform, EKS, GitHub Actions) | Accepted |
| [0005](0005-cicd-pipeline-strategy.md) | CICD Pipeline Strategy (Terraform, EKS, GitHub Actions) | Accepted |
