DevSecOps Project – Week 4
Runtime Observability: Structured Logging, Dashboards, Alarms, and Alerting
Overview

Weeks 1–3 built the pipeline, the infrastructure, and the policy gates that
control how changes get in. Week 4 is about what happens after a change is
running: can we see it, and does it tell someone when it breaks.

Week 1 gave us CI security (tests, SAST, dependency/container scanning).
Week 2 gave us Terraform IaC with scanning.
Week 3 gave us policy enforcement and HTTPS.

Week 4 gives us runtime observability:

Structured application logs, not free-text strings

A CloudWatch dashboard covering compute, load balancer, and WAF signals

Alarms that page a human before an outage becomes an incident

An SNS topic wired to real alarms, not a topic sitting unused

Week 4 Theme: See it before a user reports it

The core objective of Week 4 is to implement:

Structured JSON application logging

A CloudWatch metric filter that turns log lines into a real metric

CloudWatch alarms for the failure modes that actually matter here (5xx rate,
unhealthy targets, ECS running below desired count, application error rate)

A single CloudWatch dashboard as the "one screen" view of the platform

Email alerting via SNS

What Changed

Structured logging (app/app.py)

Flask's logger now emits one JSON object per line: level, message, logger,
service, environment, git_sha. No more relying on stdout scraping — every
line is machine-parseable, and the git_sha field ties a log line straight
back to the commit that produced it (see Week 3b's build-metadata work).

CloudWatch log metric filter (infra/envs/dev/observability.tf)

A metric filter watches the existing application log group
(module.ecs.app_log_group_name) for { $.level = "ERROR" } and turns matches
into a custom AppErrorCount metric — the first metric in this project that
comes from application behavior rather than AWS-managed infrastructure
metrics.

Alarms

| Alarm | Signal | Why it matters |
|---|---|---|
| `app-error-rate` | Custom `AppErrorCount` metric | Catches application-level failures the infra layer can't see |
| `alb-5xx` | ALB `HTTPCode_Target_5XX_Count` | Catches upstream/app failures surfaced through the load balancer |
| `target-unhealthy` | ALB `UnHealthyHostCount` | Catches failing health checks before the ALB stops routing to a task |
| `ecs-running-below-desired` | ECS `RunningTaskCount` vs desired | Catches crash-looping or failed-to-start tasks |

All four alarms (and their OK transitions) publish to a dedicated SNS topic
(`aws_sns_topic.alerts`), subscribed by email.

Dashboard

One `aws_cloudwatch_dashboard` (`<name_prefix>-platform`) with five widgets:
ECS CPU/Memory, ALB request/4xx/5xx counts, ALB target response time, WAF
allowed/blocked request counts (the WAF managed rule groups from Week 3 were
already emitting these metrics — nothing was reading them until now), and
the new application error-rate metric.

Alert email handling

`alert_email` is a Terraform variable with an empty-string default —
deliberately never written into the committed `terraform.tfvars` (this is a
public repo). The real address is stored as the `ALERT_EMAIL` GitHub Actions
secret and passed to every `terraform plan`/`apply` in
`terraform-release.yml` via `-var="alert_email=${{ secrets.ALERT_EMAIL }}"`.

Why the SNS topic isn't the bootstrap one

`infra/bootstrap/github-actions-sns.tf` already defines a `ci_notifications`
SNS topic — but bootstrap has no remote backend (its state is local-only,
applied by hand as a one-time step), so `infra/envs/dev` has no shared state
to read that topic's ARN from without giving bootstrap a backend of its own.
Rather than take on that scope here, this Week creates its own topic at the
env level. Unifying the two is a reasonable future cleanup, not a blocker.

Repository Structure (Week 4 Additions)
```
app/
  app.py                      (structured JSON logging)

infra/
  envs/dev/
    observability.tf          (metric filter, alarms, dashboard, SNS)
    variables.tf              (alert_email)
  modules/ecs/
    outputs.tf                (alb_arn_suffix, alb_target_group_arn_suffix,
                                app_log_group_name, waf_web_acl_name)

.github/workflows/
  terraform-release.yml       (passes alert_email from the ALERT_EMAIL secret)
```

What Was Achieved in Week 4

✔ Structured JSON application logging
✔ CloudWatch log metric filter turning log lines into a real metric
✔ Four CloudWatch alarms covering app, ALB, and ECS failure modes
✔ One CloudWatch dashboard as the platform's "single pane of glass"
✔ SNS email alerting wired to real alarms
✔ WAF metrics (emitted since Week 3, unused until now) surfaced on the dashboard
✔ Secrets discipline: alarm email never committed to a public tfvars file

What's Next – Week 4b Preview

SSM Parameter Store secrets management was on the original Week 4 roadmap
but is deferred: there's no real application secret to manage yet (no DB
credentials, no third-party API keys), and adding SSM usage without a real
consumer would just be checkbox infrastructure. It'll land alongside
whichever future week introduces a real secret (e.g. RDS credentials).

Also upcoming: unify the bootstrap and env-level SNS topics once bootstrap
gets a remote backend, and X-Ray tracing for request-level latency
breakdowns.
