DevSecOps Project – Week 11
Written Threat Model
Overview

The last item on the roadmap that started after Week 5: everything built
in Weeks 1–10 scanned code, dependencies, containers, infrastructure, git
history, supply-chain provenance, and (Week 10) the running app itself —
but none of it stepped back to ask "what are we actually defending
against, as a system, and what haven't we covered?" That's what a threat
model answers, and unlike the weekly build notes, it's not about a
specific control — it's the synthesis across all of them.

Where it lives: **`THREAT-MODEL.md` at the repo root**, not buried in
`weeks/`, deliberately — this is the kind of document meant to be found
immediately, not archaeologically. This page is just the pointer + the
"why now, why this way" context; the actual analysis is there.

Why now, not earlier: a threat model written before Weeks 1–10 existed
would have been a list of hypothetical controls to build. Written after,
it's a list of *real, already-implemented* mitigations, each pointing at
actual code — plus an honest accounting of what's still a gap. That's a
meaningfully different, more credible document.

Structure: STRIDE (Spoofing, Tampering, Repudiation, Information
disclosure, Denial of service, Elevation of privilege) applied to four
areas — the public-facing edge (ALB/WAF), the application runtime (ECS),
the CI/CD pipeline and supply chain, and the account-level security
baseline (Week 6) — plus a trust-boundaries diagram and an explicit
Residual Risks section.

The current residual risks section focuses on boundaries that code cannot
honestly erase: AWS Organizations ownership for delegated multi-account
administration, protecting direct ECS deployment permissions so the pipeline's
Cosign admission gate cannot be bypassed, ensuring the staging DAST identity
continues to cover new application roles, completing timed restore/failback
exercises in addition to automated recovery-plan validation, and accumulating
real traffic and on-call evidence over time. WAF rate limiting, per-AZ
production NAT, autoscaling, scheduled secret rotation, authenticated active
DAST, deploy-time signature verification, and all-region Security Hub
aggregation are part of the current platform.

Scope note: the threat model covers the shared architecture both
`devsecops-bootcamp` and `devsecops-bootcamp-cdk` deploy — it isn't
duplicated in the CDK repo. See that repo's own note on this for the one
place a distinction actually matters (verification depth, not the threat
model's content).

What Was Achieved in Week 11

✔ A real, honest threat model — not a checklist exercise — with every
  mitigation tied to actual, already-built code
✔ An explicit, reasoned Residual Risks section instead of implying zero
  remaining risk
✔ The roadmap item that started after Week 5 is now closed
