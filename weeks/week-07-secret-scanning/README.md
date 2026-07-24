DevSecOps Project – Week 7
Secret Scanning (Gitleaks)
Overview

Weeks 1–6 covered application security scanning (Bandit, pip-audit,
Trivy), infrastructure security scanning (tfsec/Checkov/cdk-nag/OPA), and
account-level threat detection (GuardDuty/Security Hub/Config). None of
those catch a hardcoded credential committed straight into source —
that's a different class of problem: a secret doesn't need a
vulnerability to be exploited, it just needs to be read.

What Changed

`.github/workflows/02-security.yml` gains a third job, `gitleaks`,
alongside the existing `sast-and-deps` (Bandit/pip-audit) and `trivy-fs`
jobs. Uses the official `gitleaks/gitleaks-action@v2` with
`fetch-depth: 0` on checkout.

Why full history, not just the PR diff: a secret committed and then
"removed" in a later commit still exists in git history — anyone who
clones the repo can `git log -p` their way to it. Scanning only the
current file tree would miss exactly the case secret scanning exists to
catch. `fetch-depth: 0` is required for gitleaks to see past commits at
all (the default shallow checkout only has the latest commit).

License note: `gitleaks-action@v2` is free for public repositories —
a license is only required for private repositories under a GitHub
*organization* account. This repo is public under a personal account, so
no license/secret setup was needed.

Verification before enabling this in CI: ran the `gitleaks` CLI directly
against this repo's full commit history locally before pushing the
workflow change (`gitleaks detect --source . --log-opts="--all"`) —
clean, no leaks, so the first real CI run wasn't a surprise either way
(a true finding requiring rotation, or a false positive requiring an
allowlist entry).

What Was Achieved in Week 7

✔ Every PR now scans full git history for hardcoded secrets, not just the
  diff
✔ Verified against real repo history before enabling in CI, rather than
  finding out the hard way on the first run
✔ Zero cost, zero license requirement (public repo, personal account)

What's Next

SBOM generation + cosign image signing (supply-chain security) — the
container images this project already builds and pushes to ECR every
deploy don't yet have a verifiable record of what's inside them or proof
they weren't tampered with between build and deploy.
