# ADR-0001: Core tooling choices (Terraform, EKS, GitHub Actions)

- **Status:** Accepted
- **Date:** 2026-10-13
- **Deciders:** Jai Gupta

## Context

I am building a production-style platform to run the Online Boutique
microservices app, following practices a company would use: infrastructure
as code, pull-request-driven changes, automated security checks, and GitOps
delivery. The project is a self-funded learning environment, so cost and
ease of teardown matter. The platform must be reproducible from a clean
checkout.

## Decision

1. **Infrastructure as code: Terraform** (modules + per-environment configs)
2. **Kubernetes platform: Amazon EKS** with managed node groups
3. **CI: GitHub Actions**, authenticating to AWS via OIDC (no static keys)

## Options considered

### IaC
| Option | Pros | Cons |
|---|---|---|
| Terraform | Industry standard, large module ecosystem, I use it professionally | State management needs care; BSL license |
| OpenTofu | Open source fork, mostly compatible | Smaller ecosystem and fewer job listings |
| CloudFormation | Native to AWS | AWS-only, verbose, not portable |

### Kubernetes
| Option | Pros | Cons |
|---|---|---|
| EKS | Most common managed K8s in industry, realistic IAM/VPC integration | Control plane costs ~$0.10/hr, not free tier |
| Self-managed (kubeadm, k3s) | Cheap, full control | Not what most companies run; hides cloud integration work |
| GKE / AKS | Good products | I would need to create new accounts; AWS is my main target |
| kind (local only) | Free, fast | No real IAM, networking, or cloud behavior |

### CI
| Option | Pros | Cons |
|---|---|---|
| GitHub Actions | Lives next to the code, huge action ecosystem, native OIDC | Less powerful pipeline modelling than some alternatives |
| GitLab CI / Jenkins | Widely used in enterprises | Extra hosting and maintenance, or a platform migration |

## Consequences

**Positive**
- Every change is reviewable, repeatable, and scannable before apply
- Skills transfer directly to most employers' stacks

**Negative / risks**
- EKS costs money while running. Mitigation: AWS Budget alarm, destroy
  environments after each session, spot instances for nodes, and `kind`
  for day-to-day iteration
- Terraform state is a single point of failure. Mitigation: versioned,
  encrypted S3 bucket with locking

## Revisit when

- Monthly cost exceeds budget, or EKS startup time slows iteration too much
  (then consider doing more work on `kind` and creating EKS only for
  integration checks)