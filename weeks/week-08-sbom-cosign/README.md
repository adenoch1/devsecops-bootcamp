DevSecOps Project – Week 8
Supply-Chain Security: SBOM + Cosign Image Signing
Overview

Weeks 1–7 scanned code, dependencies, containers, infrastructure, and
git history for known problems. None of that answers a different
question: when the ECS task pulls an image from ECR, how would anyone —
an engineer, an auditor, an incident responder — know exactly what's
inside that image, or prove it's the exact artifact this pipeline built
and nothing else slipped in between build and deploy? That's what an
SBOM (Software Bill of Materials) and image signing answer.

What Changed

`.github/workflows/03-release.yml` (the reusable build-and-push job used
by every deploy) gains four steps after the existing "Build and push
image to ECR" step:

1. **Install cosign** (`sigstore/cosign-installer@v3`).
2. **Generate an SBOM** (`anchore/sbom-action@v0`, wrapping Syft) directly
   against the pushed image reference, SPDX-JSON format — every package
   and library actually in the final image, not just what's in
   `requirements.txt` (SPDX-JSON also captures OS packages from the base
   image layer).
3. **Attach the SBOM as an in-toto attestation** (`cosign attest`) —
   stored in the ECR registry alongside the image itself, not as a
   separate build artifact someone has to remember to go find.
4. **Sign the image** (`cosign sign`), **keyless** — no private key
   generated, stored as a GitHub secret, or rotated. Cosign requests a
   short-lived certificate from Sigstore's Fulcio CA using this specific
   workflow run's own GitHub Actions OIDC identity, and logs the
   signature in Sigstore's public Rekor transparency log. `id-token:
   write` (already granted at the workflow level for AWS OIDC) is the
   only permission this needs — no new secret to manage.
5. **Verify the signature** — a sanity-check step in the same job:
   `cosign verify` against the expected certificate identity (this repo)
   and OIDC issuer. If signing silently failed or produced something
   unverifiable, the build fails here instead of shipping an image no
   one can actually verify.

Signed and attested **once, by digest** — every tag pushed in the same
job (the deploy tag, and `bootstrap`/`latest` when applicable) points at
the same manifest digest from one build, so one signature and one SBOM
attestation covers all of them.

Why keyless over a traditional key pair: a long-lived signing key is
itself a secret that needs generating, storing, and rotating — one more
thing that can leak. Sigstore's keyless flow ties the signature to *this
specific workflow run's* verified GitHub identity instead, with no key
material for anyone to steal in the first place.

IAM note: no new permissions needed. `cosign sign`/`attest` push
additional OCI artifacts (a signature manifest, an attestation manifest)
to the same ECR repository using the same `ecr:PutImage`/layer-upload
actions the image push itself already used — checked the `github-ecr-role`
policy before writing this, and it already covers it (wildcard-scoped to
`repository/*`, not tied to specific image tags).

Verified live before merging: triggered `03-release.yml` directly via
`workflow_dispatch` on the feature branch — this workflow only pushes to
ECR, it doesn't touch the running ECS service, so it was safe to test in
isolation before opening a PR.

What Was Achieved in Week 8

✔ Every image this pipeline builds now has a real, queryable SBOM
  attached in the registry — not a spreadsheet someone updates by hand
✔ Every image is signed with a verifiable, keyless signature tied to the
  exact workflow run that built it
✔ A self-verification step in the same job — a broken signing step fails
  the build instead of silently shipping an unverifiable image
✔ Zero new secrets to manage (keyless signing)

What's Next

ZAP (dynamic application security testing) — everything so far has
scanned source code, dependencies, and container/infrastructure
configuration statically. Nothing yet has actually attacked the running
application the way a real client (or attacker) would.
