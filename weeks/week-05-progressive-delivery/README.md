DevSecOps Project – Week 5
Progressive Delivery: Rollback, Network Isolation, Tracing, Blue/Green
Overview

Weeks 1–4 built the pipeline, the infrastructure, the policy gates, and
runtime observability. Week 5 is about what happens when a deployment goes
wrong, and how much of the network path a request travels unnecessarily.

This week lands in stages rather than all at once — each stage is its own
PR, validated independently, because each is roughly the size of a
standalone feature:

1. Rollback parity — done
2. VPC endpoints — done
3. APM / distributed tracing via X-Ray (next)
4. Progressive deployment via CodeDeploy Blue/Green (last — the biggest
   piece, folds the Week 4 alarms into automatic rollback during a live
   traffic shift)

Week 5 Theme: Deploy safely, see the whole request, keep traffic off the
public path where it doesn't need to be

Stage 1 — Rollback Parity (ECS Deployment Circuit Breaker)

What changed: `aws_ecs_service.app` now has

```hcl
deployment_circuit_breaker {
  enable   = true
  rollback = true
}
```

Why this was missing here first: the CDK sibling
(`devsecops-bootcamp-cdk`) got this before the Terraform original did —
`ecs.FargateService(circuit_breaker=ecs.DeploymentCircuitBreaker(rollback=True))`
was added while porting the ECS stack, on a cdk-nag recommendation. This
closes that gap the other direction.

What it actually does: if a new task definition fails to reach a stable,
healthy state (crash loop, failing health checks, bad image, etc.), ECS
detects the failed rollout itself and automatically redeploys the previous
known-good task definition — no human, no alarm-response runbook, no
manual `terraform apply` of a revert. This is deployment-time protection:
it fires during the rollout itself, before the Week 4 alarms would even
have a chance to notice a problem in already-running traffic.

What it doesn't do (yet): this is still an all-at-once/rolling replacement
under the hood — there's no traffic shifting, no canary window, no
alarm-gated pause partway through a shift. That's Stage 4 (CodeDeploy
Blue/Green), which builds directly on top of both this and the Week 4
alarms.

Stage 2 — VPC Endpoints

What changed: `infra/modules/network/endpoints.tf` adds a Gateway endpoint
for S3 (free — ECR image layers are actually fetched from S3 under the
hood, so this covers image pulls even though it looks unrelated to ECR at
first glance) and 3 Interface endpoints (`ecr.api`, `ecr.dkr`, `logs`) in
the private subnets, behind a dedicated security group that only allows
HTTPS from inside the VPC.

Why a dedicated security group instead of reusing the ECS tasks SG: the
ECS security group lives in the `ecs` module, which itself depends on this
`network` module's subnet outputs. Scoping the endpoint SG to the ECS SG
would create a circular module dependency. Scoping to the VPC CIDR instead
still means only resources inside this VPC can reach the endpoints — not
as tight as "only the ECS tasks," but not open to anything outside the VPC
either.

**Honest cost note**: at 2 AZs and 3 interface endpoints
(~$0.01/hr × endpoint × AZ), this is roughly **$40–45/month** —
comparable to or more than the single NAT gateway it doesn't replace
(~$32–45/month, kept in place as a fallback for anything not covered by an
endpoint). This is a security-posture improvement (task traffic to
ECR/CloudWatch Logs never touches the public internet or NAT), not a cost
optimization, at this scale. A team running many services in one VPC
would see this math flip — the marginal cost per additional service using
the same shared endpoints drops to zero, while NAT data-processing charges
scale with traffic. Worth being able to explain both sides of that in an
interview rather than just claiming "cheaper."

What Was Achieved in Week 5 (Stages 1–2)

✔ ECS deployment circuit breaker with automatic rollback
✔ Terraform/CDK parity restored (both sides now behave the same way on a
  failed deployment)
✔ S3 gateway endpoint + 3 interface endpoints (ECR API, ECR Docker
  registry, CloudWatch Logs)
✔ Dedicated, VPC-scoped security group for the interface endpoints

What's Next – Week 5 Stages 3–4

APM via AWS X-Ray: SDK instrumentation in the Flask app, an X-Ray daemon
sidecar in the task definition, and a service map showing real
request-level latency breakdowns.

CodeDeploy Blue/Green: a second target group, linear traffic shifting, and
the Week 4 CloudWatch alarms (`alb_5xx`, `app_error_rate`) wired as
automatic-rollback triggers *during* the shift — the point where "stronger
rollback" and "progressive deployment" become the same feature instead of
two separate ones.
