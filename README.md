# DevSecOps Bootcamp (12-Week Project)

A hands-on DevSecOps bootcamp project where we build a production-style application delivery platform on AWS and evolve it week-by-week with security, governance, automation, and observability.

This repository is designed for:
- YouTube learners following the weekly series
- Engineers who want a real-world DevSecOps reference implementation
- Interview preparation (architecture + pipeline + security + monitoring)

> **Also available in AWS CDK (Python):** [devsecops-bootcamp-cdk](https://github.com/adenoch1/devsecops-bootcamp-cdk)
> is a parallel implementation of this same app and architecture using CDK
> instead of Terraform — same security posture, different IaC tool, so you
> can compare the two directly. This repo (Terraform) stays the canonical,
> more mature one with the full weekly build history.

---

## What You’ll Learn

By the end of this bootcamp, you will understand how real teams:
- Build and test applications in CI
- Scan code, dependencies, and containers for vulnerabilities
- Provision AWS infrastructure using Terraform (IaC)
- Enforce security and compliance using Policy as Code (OPA / Conftest)
- Deploy via protected branches and approval gates
- Centralize logs, metrics, dashboards, and alarms
- Manage secrets securely (SSM / Secrets Manager)
- Produce production-grade documentation and reproducible environments

---

## Bootcamp Standards (Non-Negotiable)

### 1) Security Requirements
- **Least Privilege IAM** — only required AWS permissions
- **Secrets Management** — SSM or Secrets Manager (no secrets in Git)
- **Encryption Everywhere** — S3 / EBS / RDS / TLS
- **Vulnerability Scanning** — container scans (Trivy / Grype)
- **Dependency Scanning** — pip-audit / npm audit / Dependabot
- **IaC Security Scanning** — Checkov / tfsec / cdk-nag

### 2) Automation Standards
- **CI/CD Pipeline** — build, test, scan, deploy automatically
- **Pre-Commit Hooks** — linting + security checks
- **Infrastructure as Code** — Terraform/CDK for all cloud resources
- **Reproducible Environments** — one command to deploy

### 3) Observability Requirements
- **Logs** — structured logs + centralization
- **Metrics** — CPU, memory, latency, errors, custom metrics
- **Dashboards** — CloudWatch or Grafana
- **Alerts** — critical error alerts configured

### 4) Production Standards
- **Branching Strategy** — feature → dev → staging → main (evolves by week)
- **Pull Requests** — approval + automated checks required
- **Versioning** — weekly releases tagged clearly
- **High Availability** — Multi-AZ when applicable
- **Backups** — snapshot policies enabled where relevant

### 5) Reproducibility Requirements
- **README** — clear setup + usage
- **Architecture Diagram** — required each week
- **Bootstrap Scripts** — install/init scripts where needed
- **Environment Files** — provide `.env.example`
- **One-Click Deployment** — other engineers can deploy easily

**Final Check**
- Does it look production-ready?
- Does it include security, automation, IaC, logs, monitoring?
- Can another engineer clone and deploy it?
- Can I confidently explain it in an interview?

---

## Repo Structure

- `app/` (or your application folder) — application source code
- `infra/` — Terraform infrastructure (modules + environments)
- `policy/` — OPA / Conftest policies (Policy as Code)
- `.github/workflows/` — CI/CD pipelines (PR checks + release deploy)
- `weeks/` — weekly documentation and teaching notes (see below)

> The root README is the index.
> Each week has its own README inside `weeks/` for learners who want the exact weekly steps.

---

## Weekly Episodes (Start Here)

> Tip: This repo evolves weekly.  
> If you want the exact code of a specific week, check the **GitHub Releases/Tags** (e.g., `week-01`, `week-02`, `week-03`).

### ✅ Week 01 — CI/CD + Security Scanning
- Tests: Pytest
- SAST: Bandit
- Dependency scanning: pip-audit
- Container scanning: Trivy
- Branch protection + PR gating

📄 Notes: `weeks/week-01-ci-cd/README.md`

### ✅ Week 02 — Terraform IaC + IaC Scanning
- Terraform modules + environments
- PR pipeline checks for Terraform
- tfsec + Checkov scans

📄 Notes: `weeks/week-02-terraform-iac/README.md`

### ✅ Week 03 — Policy as Code + HTTPS + Governance
- OPA / Conftest policy enforcement gate
- Protected main (PR must pass)
- Release workflow (apply after merge + approval)
- HTTPS with ACM certificate
- Domain: `app.clevernews.org` (GoDaddy DNS → ALB)

📄 Notes: `weeks/week-03-opa-https/README.md`

### ✅ Week 04 — Runtime Observability
- Structured JSON application logging
- CloudWatch log metric filter (application error rate)
- CloudWatch alarms: ALB 5xx, unhealthy targets, ECS running-task count, app error rate
- CloudWatch dashboard (ECS, ALB, WAF, application metrics)
- SNS email alerting

📄 Notes: `weeks/week-04-observability/README.md`

### ✅ Week 05 — Progressive Delivery
- ✅ Stage 1: ECS deployment circuit breaker (automatic rollback on failed deploys) — superseded by Stage 4
- ✅ Stage 2: VPC endpoints (S3 gateway + ECR/CloudWatch Logs interface endpoints)
- ✅ Stage 3: APM / distributed tracing via AWS X-Ray
- ✅ Stage 4: CodeDeploy Blue/Green with alarm-gated automatic rollback

📄 Notes: `weeks/week-05-progressive-delivery/README.md`

### ✅ Week 06 — Account Security Baseline (GuardDuty + Security Hub + Config)
- GuardDuty (account-wide threat detection, 15-minute finding frequency)
- Security Hub (AWS Foundational Security Best Practices standard)
- AWS Config (7 rules curated to this project's actual resource types)
- All three routed to Week 4's existing SNS alert topic via filtered EventBridge rules
- Lives in `infra/bootstrap/` (account-level singletons, applied manually — see the notes for why) and is **not** ported to the CDK sibling, by design

📄 Notes: `weeks/week-06-security-baseline/README.md`

### ✅ Week 07 — Secret Scanning (Gitleaks)
- Full git history scanned on every PR, not just the diff
- Verified against real repo history locally before enabling in CI
- Free for public repos, no license/setup cost

📄 Notes: `weeks/week-07-secret-scanning/README.md`

### 🚧 Week 08 — Supply-Chain Security (SBOM + Cosign)
- SBOM (SPDX-JSON, via Syft) generated for every image and attached as an in-toto attestation in ECR
- Every image signed keyless (Sigstore Fulcio + Rekor) using the workflow's own GitHub Actions OIDC identity — no signing key to manage
- Self-verification step in the same job — a broken signature fails the build
- Signed/attested once by digest, covers every tag pushed from the same build

📄 Notes: `weeks/week-08-sbom-cosign/README.md`

> Upcoming: ZAP (dynamic application security testing).

---

## Branching & Governance Model

- `main` is protected (no direct pushes)
- Work happens in feature branches:
  - `feature/week-04-monitoring`
  - `feature/week-05-waf`
- Pull Requests run security + policy gates
- Only compliant PRs can be merged

### CI/CD Flow (High Level)
1. Feature branch → PR to `main`
2. PR workflow runs: fmt/validate → tfsec/checkov → plan → OPA/Conftest
3. If checks pass → PR can be merged
4. Merge triggers release workflow → Terraform apply (with environment approval gate)

---

## How to Use This Repo

### For viewers (recommended)
- Start with the week you are watching:
  - `weeks/week-01-ci-cd/README.md`
  - `weeks/week-02-terraform-iac/README.md`
  - `weeks/week-03-opa-https/README.md`
  - `weeks/week-04-observability/README.md`
- If you need the exact code of that week, use Releases/Tags.

### For engineers cloning the project
- Follow the latest week notes (main branch) and deploy using the documented workflow.
- Infrastructure is deployed via GitHub Actions (not manual local apply).

---

## Security Notes
- No secrets should be committed to Git.
- Use SSM Parameter Store / Secrets Manager for sensitive values.
- Prefer GitHub OIDC for AWS auth (no long-lived access keys).
- Policy as Code must block non-compliant infrastructure.

---

## License
Add your license here (MIT/Apache-2.0/etc.) if desired.

---

## Author / Series
Built week-by-week as part of the “DevSecOps Bootcamp” YouTube series.
