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
3. APM / distributed tracing via X-Ray — done
4. Progressive deployment via CodeDeploy Blue/Green — done (the biggest
   piece, folds the Week 4 alarms into automatic rollback during a live
   traffic shift, and supersedes Stage 1's circuit breaker)

Week 5 Theme: Deploy safely, see the whole request, keep traffic off the
public path where it doesn't need to be

```mermaid
graph TB
    Client["Client / Browser"]
    CodeDeploy["CodeDeploy<br/>(deployment group)"]
    Alarms["CloudWatch Alarms<br/>(alb_5xx, app_error_rate)"]

    subgraph VPC["VPC 192.168.0.0/16"]
        IGW["Internet Gateway"]

        subgraph Public["Public Subnets (2 AZs)"]
            ALB["Application Load Balancer<br/>HTTPS listener"]
            NAT["NAT Gateway"]
        end

        subgraph TGs["Target Groups (Stage 4)"]
            BlueTG["Blue TG<br/>(current live)"]
            GreenTG["Green TG<br/>(new deployment)"]
        end

        subgraph Private["Private Subnets (2 AZs)"]
            App["app container<br/>(Flask, X-Ray SDK)"]
            XrayD["xray-daemon container<br/>(sidecar, essential=false)"]
        end

        subgraph Endpoints["VPC Endpoints (Stage 2 + Stage 3)"]
            S3EP["S3 Gateway Endpoint"]
            EcrApiEP["ECR API<br/>Interface Endpoint"]
            EcrDkrEP["ECR Docker<br/>Interface Endpoint"]
            LogsEP["CloudWatch Logs<br/>Interface Endpoint"]
            XrayEP["X-Ray<br/>Interface Endpoint"]
        end
    end

    S3[("S3<br/>(image layers)")]
    ECR[("ECR<br/>(container registry)")]
    CWLogs[("CloudWatch Logs")]
    XrayAPI[("X-Ray API<br/>(traces, service map)")]
    Other[("Everything else<br/>(KMS, SNS...)")]

    Client -->|"HTTPS 443"| IGW
    IGW --> ALB
    ALB -->|"linear traffic shift<br/>10% / 1 min"| BlueTG
    ALB -.->|"shifts here during<br/>a deployment"| GreenTG
    BlueTG --> App
    GreenTG -.-> App

    CodeDeploy -.->|"registers new task set,<br/>flips ALB routing"| GreenTG
    Alarms -.->|"DEPLOYMENT_STOP_ON_ALARM<br/>= auto-rollback"| CodeDeploy

    App -.->|"UDP 2000<br/>(same task,<br/>shared network ns)"| XrayD

    App --> EcrApiEP --> ECR
    App --> EcrDkrEP --> ECR
    App -.->|"image layer data"| S3EP -.-> S3
    App --> LogsEP --> CWLogs
    XrayD --> XrayEP --> XrayAPI
    App -.->|"anything not covered<br/>by an endpoint"| NAT -.-> IGW -.-> Other

    style Endpoints fill:#e0e7ff,stroke:#3730a3
    style NAT fill:#fef3c7,stroke:#b45309
    style XrayD fill:#dcfce7,stroke:#15803d
    style TGs fill:#fce7f3,stroke:#a21caf
    style CodeDeploy fill:#fce7f3,stroke:#a21caf
```

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

Stage 3 — APM / Distributed Tracing via AWS X-Ray

What changed: three pieces, wired together.

1. `app/app.py` — `aws-xray-sdk` added to `requirements.txt`;
   `XRayMiddleware` wraps the Flask app, recording a segment for every
   request with `xray_recorder.configure(daemon_address=..., context_missing="LOG_ERROR")`.
   `context_missing="LOG_ERROR"` instead of the default (which raises) so a
   missing trace context — a background thread, a local run with no
   daemon — logs a warning instead of crashing a request.
2. `infra/modules/ecs/main.tf` — `aws_ecs_task_definition.app` gains a
   second container, `xray-daemon` (`public.ecr.aws/xray/aws-xray-daemon`,
   UDP 2000, `essential = false`). The app container gets `dependsOn:
   [{containerName: "xray-daemon", condition: "START"}]` so it doesn't
   start racing the daemon, and an `AWS_XRAY_DAEMON_ADDRESS=127.0.0.1:2000`
   env var — `127.0.0.1` works because `awsvpc` network mode means every
   container in the task shares one network namespace, same as `localhost`
   between processes on one host.
3. `infra/modules/iam/main.tf` — a new inline policy on `ecs_task_role`
   (previously empty) granting exactly what the daemon calls:
   `xray:PutTraceSegments`, `PutTelemetryRecords`, and the three
   `GetSampling*` reads the SDK polls for its sampling rules. All five
   require `Resource: "*"` — the X-Ray API has no resource-level ARNs to
   scope to.

Why `essential = false` on the daemon: if X-Ray's daemon crashes or can't
reach its endpoint, that should never be a reason the whole task cycles
and traffic drops. Tracing is an observability nice-to-have layered on top
of a working app, not a dependency the app's availability rides on.

VPC endpoint: `infra/modules/network/endpoints.tf`'s `interface_endpoints`
map gains a fourth entry, `xray`. Same reasoning as Stage 2 — without it,
the daemon's calls to the X-Ray API would go out via the NAT gateway, the
exact path Stage 2 exists to avoid for everything else.

Stage 4 — CodeDeploy Blue/Green

What changed: `infra/modules/ecs/main.tf` gains a second ("green") target
group, identical in shape to the existing ("blue") one. `aws_ecs_service.app`
switches from ECS's own rolling-update controller to
`deployment_controller { type = "CODE_DEPLOY" }`, and a new
`infra/envs/dev/codedeploy.tf` defines the CodeDeploy application,
deployment group, and IAM service role that actually own the traffic
shift going forward.

Why the target group is duplicated rather than reused: CodeDeploy's
blue/green model needs two independent, health-checkable groups to shift
between — it stands up the new deployment's tasks in the green group,
health-checks them behind the same ALB, then moves listener traffic over
once they're healthy. A single target group has nowhere to put the "new"
tasks that isn't also the "old" tasks.

Traffic shift: `CodeDeployDefault.ECSLinear10PercentEvery1Minutes` (a
predefined AWS deployment config, referenced by name) — 10% of traffic
every minute, full cutover in about 10 minutes. No test listener; the
green target group only receives traffic once CodeDeploy reroutes the
production listener, not before — a genuine pre-production test listener
is a real CodeDeploy feature but adds a second listener/cert concern this
project has no current use for.

Rollback, made stronger than Stage 1: `auto_rollback_configuration` is
enabled for both `DEPLOYMENT_FAILURE` and `DEPLOYMENT_STOP_ON_ALARM`, with
`alarm_configuration` wired directly to the Week 4 alarms
(`alb_5xx`, `app_error_rate` — `infra/envs/dev/observability.tf`). This is
the concrete version of "stronger automated rollback built on Week 4": if
either alarm fires *while traffic is still shifting*, CodeDeploy aborts
and reverts automatically — a failure mode Stage 1's circuit breaker could
never catch, since it only watched ECS-level task health, never
application error rate or ALB 5xx responses.

Why Stage 1's circuit breaker had to be removed, not layered on top: AWS
rejects `deployment_circuit_breaker` and a `CODE_DEPLOY` deployment
controller being set together — they're mutually exclusive rollout
mechanisms. Not a capability regression: `auto_rollback_configuration`'s
`DEPLOYMENT_FAILURE` event covers the exact case the circuit breaker
handled (new tasks failing to stabilize), plus the new alarm-triggered
case above.

Full automation, no manual gate: `deployment_ready_option` is
`CONTINUE_DEPLOYMENT` (traffic reroutes as soon as green is healthy, no
human "continue-deployment" call required) and the old blue task set
terminates automatically 5 minutes after a successful cutover
(`terminate_blue_instances_on_deployment_success`) — a short buffer window
without needing a human in the loop, appropriate for a personal project
with no on-call rotation to gate on.

A deploy-pipeline change this stage required: once
`aws_ecs_service.app.task_definition`/`load_balancer` are
`lifecycle`-ignored (CodeDeploy's job now, not Terraform's — see the
comment in `infra/modules/ecs/main.tf`), a plain `terraform apply` in
`.github/workflows/terraform-release.yml`'s `deploy` job still registers a
new task definition revision, but no longer *ships* it. The `deploy` job
now builds a CodeDeploy AppSpec referencing that new revision and calls
`aws deploy create-deployment`, then waits on
`aws deploy wait deployment-successful` instead of
`aws ecs wait services-stable` — CodeDeploy owns the actual rollout from
here.

A second, related fix bundled into this stage: Gate 1 (Infra Bootstrap)
has applied with `desired_count=0` on every push since Week 1 — a
bootstrap-time default from before this project had a real image to run,
harmless when the Deploy job unconditionally set it back to 1 right after.
With blue/green traffic shifting, that same "scale to 0, then back up"
cycle on every deploy would destroy the very "blue" baseline the shift is
supposed to happen against before it even starts — a zero-downtime
feature that begins from zero running tasks isn't zero-downtime.
`desired_count` joins `task_definition`/`load_balancer` in the service's
`ignore_changes`, making Gate 1's `=0` a true no-op after the environment
first exists, and leaving CodeDeploy as sole owner of scale from then on.

What Was Achieved in Week 5 (all 4 stages)

✔ ECS deployment circuit breaker with automatic rollback (Stage 1),
  superseded by CodeDeploy's stronger, alarm-aware rollback (Stage 4)
✔ Terraform/CDK parity restored (both sides now behave the same way on a
  failed deployment) — CDK's blue/green port is a deliberate follow-up,
  once this stage is live-verified
✔ S3 gateway endpoint + 4 interface endpoints (ECR API, ECR Docker
  registry, CloudWatch Logs, X-Ray)
✔ Dedicated, VPC-scoped security group for the interface endpoints
✔ Flask app instrumented end-to-end with AWS X-Ray, daemon sidecar
  isolated from app availability via `essential = false`
✔ Least-privilege X-Ray IAM policy on the task role (5 actions, no managed
  policy)
✔ Real CodeDeploy blue/green traffic shifting, alarm-gated automatic
  rollback wired to the Week 4 alarms, and a deploy pipeline that ships
  through CodeDeploy instead of a direct ECS service update

Week 5 is complete. The CDK port of Stage 4 (`devsecops-bootcamp-cdk`) is
tracked as a follow-up PR — CloudFormation's handling of
`CODE_DEPLOY`-controlled services differs from Terraform's in ways worth
confirming against a real deployment first, same sequencing every other
Week 5 stage used.
