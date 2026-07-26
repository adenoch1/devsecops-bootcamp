# Terraform AWS Infrastructure (ECS Fargate)

The same root module is instantiated through isolated `development`, `staging`,
and `production` workspaces using `infra/envs/dev/config/*.tfvars`. Staging and
production use per-AZ NAT gateways, a two-task minimum, autoscaling, WAF rate
limiting, cross-region log replication, and optional Terraform-managed Route
53 aliases. See `docs/PRODUCTION-READINESS.md` before applying.

## What this creates

- Two-AZ VPC with public ALB and private ECS subnets
- Internet gateway plus environment-specific NAT gateways and private routes
- VPC endpoints for S3, ECR, CloudWatch Logs, and X-Ray
- ECR repository with scanning, encryption, and immutable tags
- Least-privilege ECS execution and task roles
- ECS Fargate service with CPU/memory target-tracking autoscaling
- HTTPS ALB, blue/green target groups, WAF managed rules, and rate limiting
- KMS-encrypted application, ALB, WAF, and VPC flow logs
- SLO alarms, dashboard, SNS alerting, and distributed tracing
- Optional Route 53 alias with target-health evaluation

## Environment profiles

| Environment | NAT gateways | ECS task range |
|---|---:|---:|
| Development | 1 | 1–3 |
| Staging | 2 | 2–6 |
| Production | 2 | 2–10 |

## Validate locally

```bash
cd infra/envs/dev
terraform init
terraform workspace select development
terraform fmt -recursive
terraform validate
terraform plan -var-file=config/development.tfvars
```

Real applies run through the protected GitHub Actions release workflow.
Existing state must be inspected and migrated before the first workspace-based
apply; never create an empty development state and apply over live resources.
