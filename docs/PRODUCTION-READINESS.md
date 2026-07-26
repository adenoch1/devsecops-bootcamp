# Production readiness upgrade

This document is the operating contract for the upgraded platform. Terraform
and GitHub Actions implement the controls; values in GitHub Environments and
AWS accounts complete the deployment.

## Environment isolation and promotion

The same reviewed Terraform root is instantiated in three isolated S3 state
paths using Terraform workspaces:

| Environment | Workspace | CIDR | NAT | Tasks | Scaling |
|---|---|---:|---|---:|---|
| Development | `development` | `10.10.0.0/16` | one (cost optimized) | 1 | 1–3 |
| Staging | `staging` | `10.20.0.0/16` | one per AZ | 2 | 2–6 |
| Production | `production` | `10.30.0.0/16` | one per AZ | 2 | 2–10 |

Create matching protected GitHub Environments. Require reviewers for
`production` and `disaster-recovery`. Use separate AWS accounts and OIDC roles
for strongest isolation; the workflow already selects credentials from the
target GitHub Environment. Promote the same immutable digest from development
to staging and production after CI, active DAST, and performance gates pass.

## SLOs and recovery objectives

| Objective | Target | Source |
|---|---:|---|
| Availability SLI | successful non-WAF 2xx/3xx requests / valid requests | ALB metrics |
| Availability SLO | 99.9% per rolling 30 days | CloudWatch dashboard/alarm |
| Latency SLI | ALB target response time | ALB `TargetResponseTime` |
| Latency SLO | 95% below 500 ms; 99% below 1 s | CloudWatch and k6 |
| Error SLO | target 5xx below 1% | ALB metrics |
| RTO | 4 hours | quarterly DR exercise |
| RPO | 1 hour for operational data; immutable images/state retained | S3 versioning and cross-region replication |

At 99.9%, the monthly error budget is about 43 minutes. Freeze non-remediation
production releases after half the budget is consumed; at full exhaustion,
permit only incident fixes until the rolling window recovers.

## Security and supply-chain controls

- WAF managed rules are supplemented by a per-IP five-minute rate rule.
- The release workflow signs by digest with Sigstore and verifies the signature
  immediately before Terraform registers a deployable task definition.
- The signing identity and OIDC issuer are pinned. A missing or invalid
  signature fails closed.
- A quarterly workflow rotates the SSM SecureString and initiates a controlled
  deployment so new ECS tasks fetch the new value.
- PRs retain the safe passive ZAP baseline. A weekly authenticated active scan
  runs only against the isolated staging hostname.
- Security Hub aggregates every region. `securityhub_members` enrolls additional
  accounts; production should use an AWS Organizations delegated administrator.

## Capacity and performance

ECS target tracking scales on both CPU and memory. Scale-out cooldown is one
minute; scale-in waits five minutes to reduce oscillation. The scheduled k6
baseline enforces less than 1% failed requests, p95 below 500 ms, and p99 below
one second. Its 90-day artifacts provide a capacity history. Raise maximum
capacity only after checking downstream quotas and cost alarms.

## DNS and recovery

Set `route53_zone_id` and `fqdn` in each protected environment to create a
Terraform-managed Route 53 alias with target health evaluation. External
registrar delegation remains a one-time ownership concern, not a per-release
manual record update.

The quarterly DR workflow confirms replicated data exists and produces a
secondary-region recovery plan artifact retained for one year. Twice yearly,
an operator must also execute the plan in a temporary recovery account,
validate `/health`, measure RTO/RPO, then destroy the isolated exercise stack.
Record evidence using `docs/OPERATIONS-EVIDENCE.md`.

## Required protected values

Configure environment-scoped values rather than repository-wide secrets:

- AWS OIDC role ARNs and regions for development, staging, production, and DR
- ACM certificate ARN and Route 53 zone/FQDN for each environment
- `STAGING_URL` and a least-privilege `DAST_AUTH_TOKEN`
- SSM parameter name and KMS key ARN for secret rotation
- DR region, role, replicated bucket, certificate, and alert destination

No workflow can manufacture production users or an on-call team. Traffic and
support evidence is therefore captured as an auditable operational record,
with synthetic checks and load tests providing evidence before organic traffic
exists.
