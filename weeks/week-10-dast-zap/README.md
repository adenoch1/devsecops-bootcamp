DevSecOps Project – Week 10
Dynamic Application Security Testing (OWASP ZAP)
Overview

Weeks 1–9 scanned source code, dependencies, containers, infrastructure,
git history, and supply-chain provenance — all *static* analysis, none of
it ever sent a single HTTP request to the running application. Week 10 is
the first tool in this project that actually talks to the app the way a
real client (or attacker) would.

What Changed

`.github/workflows/05-dast-zap.yml` (new): builds the exact image
`docker/Dockerfile` produces, runs it locally in the CI job, waits for
`/health` to respond, then runs the official `zaproxy/action-baseline`
against `http://localhost:5000`.

**Current platform:** the passive local baseline remains the required PR gate.
`.github/workflows/06-active-dast.yml` also runs a scheduled authenticated
active scan against an isolated staging hostname. It requires a
least-privilege `DAST_AUTH_TOKEN`, refuses a target that does not identify as
staging, and sends active payloads only there.

**Scans a locally-run copy of the image, not the live deployed app** —
deliberately. A ZAP *baseline* scan is passive-only (crawls + inspects
real responses, never sends attack payloads), so it's safe for CI either
way, but scanning the actual production ALB would still have real
downstream effects worth avoiding in a routine PR check: this project's
own CloudWatch alarms (`alb_5xx`, `app_error_rate` — Week 4) and GuardDuty
(Week 6) are tuned to notice exactly the kind of unusual traffic pattern
a scanner produces, even a passive one. Scanning a disposable local
container sidesteps all of that while still testing the identical image
that ships to production.

**Findings, and what was actually fixed** (not just suppressed) — a real
scan against this app before any changes:

```
WARN-NEW: Missing Anti-clickjacking Header [10020] x 1
WARN-NEW: X-Content-Type-Options Header Missing [10021] x 4
WARN-NEW: Content Security Policy (CSP) Header Not Set [10038] x 3
WARN-NEW: Storable and Cacheable Content [10049] x 6
WARN-NEW: Permissions Policy Header Not Set [10063] x 3
WARN-NEW: Cross-Origin-Embedder-Policy Header Missing or Invalid [90004] x 6
FAIL-NEW: 0    WARN-NEW: 6    PASS: 61
```

All six are real, and all six were fixed in `app/app.py` via a single
`after_request` hook — not a scanner-appeasement exercise, genuine
security headers with no compatibility cost (this app serves no
third-party resources and no per-user sensitive content):

- `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`
- `Content-Security-Policy: default-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'`
  — `base-uri`/`form-action`/`frame-ancestors` don't fall back to
  `default-src` per the CSP spec; a second scan pass caught this
  (`CSP: Failure to Define Directive with No Fallback [10055]`) after the
  first-pass policy only set `default-src`/`frame-ancestors`.
- `Permissions-Policy: geolocation=(), microphone=(), camera=()`
- The cross-origin-isolation trio: `Cross-Origin-Embedder-Policy: require-corp`,
  `Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Resource-Policy: same-origin`
  — setting COEP alone isn't sufficient; a second scan pass caught the
  missing CORP header too.
- `Cache-Control: no-store, must-revalidate` — resolves "Storable and
  Cacheable Content".
- `Strict-Transport-Security: max-age=31536000; includeSubDomains` — ZAP's
  HSTS check only fires over HTTPS, so it never flagged this against the
  plain-HTTP local scan target, but this same app code serves real HTTPS
  traffic through the ALB's listener in every deployed environment, where
  it matters for real. Added anyway rather than only fixing what the
  local scan could see.

**One finding allowlisted, not fixed — because "fixing" it would be a
regression**: after adding `Cache-Control: no-store`, ZAP started
reporting `Non-Storable Content [10049]` on the same endpoints that
previously showed the opposite problem (`Storable and Cacheable
Content`). This is ZAP's baseline ruleset surfacing the fact
informationally, not flagging a real issue — the non-storable state *is*
the correct, intentional one for this app's dynamic endpoints. Allowlisted
in `.zap/rules.tsv` with that reasoning written inline, not silently
dropped.

Final scan, with the allowlist applied:

```
FAIL-NEW: 0    WARN-NEW: 0    IGNORE: 1    PASS: 66
```

What Was Achieved in Week 10

✔ First dynamic (request-sending) security test in this project — every
  prior tool only ever read source/config/history
✔ 6 real findings, all genuinely fixed (not suppressed) with headers that
  have zero functional cost for this app
✔ Iterative verification: found new findings on a second scan pass after
  the first round of fixes (CSP no-fallback directives, missing CORP) —
  caught and fixed those too before calling it done
✔ One informational, non-issue finding allowlisted with a written reason,
  not silently ignored
✔ Scans the exact image that ships to production, without the operational
  side effects of scanning the live system

The current threat model and production operating model are linked from the
repository root.
