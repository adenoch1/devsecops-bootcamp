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

The residual risks section is the part most worth reading closely: no
WAF rate-based rule, a single NAT gateway (availability, not security),
no automated secret rotation, ZAP baseline being passive-only (not a full
active scan), no deploy-time signature *enforcement* (signatures exist
and are checked in CI, but nothing blocks an unsigned image pushed
outside the pipeline), the CDK repo's controls being verified "as
designed" rather than "as running" since it has no live deployment right
now, and the account security baseline being single-account/single-region
by design. None of these are oversights — each is named with the
reasoning for accepting it at this project's scale.

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
