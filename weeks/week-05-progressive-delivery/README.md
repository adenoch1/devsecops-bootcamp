DevSecOps Project – Week 5
Progressive Delivery: Rollback, Network Isolation, Tracing, Blue/Green
Overview

Weeks 1–4 built the pipeline, the infrastructure, the policy gates, and
runtime observability. Week 5 is about what happens when a deployment goes
wrong, and how much of the network path a request travels unnecessarily.

This week lands in stages rather than all at once — each stage is its own
PR, validated independently, because each is roughly the size of a
standalone feature:

1. Rollback parity (this stage — done)
2. VPC endpoints (next)
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

What Was Achieved in Week 5 (Stage 1)

✔ ECS deployment circuit breaker with automatic rollback
✔ Terraform/CDK parity restored (both sides now behave the same way on a
  failed deployment)

What's Next – Week 5 Stages 2–4

VPC endpoints (S3 gateway + ECR/CloudWatch Logs interface endpoints) so
task traffic to AWS services stays off the NAT/public path. Worth noting
honestly up front: at this scale (2 AZs, a handful of endpoints), the
interface endpoints likely cost *more* per month than the single NAT
gateway they don't replace — this is a security-posture improvement, not
a cost optimization, and the docs for that stage will say so plainly
rather than oversell it.

APM via AWS X-Ray: SDK instrumentation in the Flask app, an X-Ray daemon
sidecar in the task definition, and a service map showing real
request-level latency breakdowns.

CodeDeploy Blue/Green: a second target group, linear traffic shifting, and
the Week 4 CloudWatch alarms (`alb_5xx`, `app_error_rate`) wired as
automatic-rollback triggers *during* the shift — the point where "stronger
rollback" and "progressive deployment" become the same feature instead of
two separate ones.
