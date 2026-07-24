DevSecOps Project – Week 9
Real Secrets Management (SSM Parameter Store)
Overview

The README has said "Manage secrets securely (SSM / Secrets Manager)"
since Week 1, and `weeks/week-05-progressive-delivery/README.md` flagged
"SSM Parameter Store secrets (once there's a real secret to manage)" as
upcoming — honestly, because until now there wasn't one. Every env var
this app used (service name, git SHA, build time, image tag) is genuinely
non-sensitive build metadata; putting it in SSM would have been theater,
not security.

What the secret actually is: Flask's own session/CSRF-signing key
(`SECRET_KEY`). Every real Flask app has one, whether or not it's
actively using sessions yet — it's the standard, natural first real
secret for a project like this, not a contrived one invented to justify
the feature.

What Changed

`infra/envs/dev/secrets.tf` (new file, env-level like `observability.tf`
and `codedeploy.tf` — needs a cross-module wire to `module.iam`'s
execution role):

1. **A dedicated KMS key** (`aws_kms_key.ssm_secrets`) — matches this
   project's established one-key-per-purpose convention (`tfstate`,
   `dynamodb`, `alb-logs`, `cloudwatch-logs` are already separate).
   Small honest cost add: ~$1/month for the CMK, same as every other
   dedicated key here.
2. **`random_password.flask_secret_key`** — generated once by Terraform,
   never typed anywhere in code. Stored in Terraform state, which is
   already KMS-encrypted via the S3 backend (`infra/bootstrap/main.tf`).
   Rotating it is a `terraform taint` + apply away.
3. **`aws_ssm_parameter.flask_secret_key`** — `SecureString`, encrypted
   with the dedicated key above.
4. **An inline IAM policy on the ECS *task execution* role** (not the
   task role — a common mix-up) granting exactly `ssm:GetParameters` on
   this one parameter's ARN and `kms:Decrypt` on this one key's ARN. The
   execution role is what fetches and decrypts secrets before the
   container starts; the task role never sees the SSM API at all.

`infra/modules/ecs/main.tf` / `variables.tf`: a new `container_secrets`
variable, wired into the app container definition's native ECS `secrets`
field (`infra/envs/dev/main.tf` passes `FLASK_SECRET_KEY` →
`aws_ssm_parameter.flask_secret_key.arn`) — distinct from the existing
`environment` field. ECS injects `secrets` entries as environment
variables at container startup too, but the value is fetched and
decrypted by the execution role and never appears in the task definition
JSON, `terraform plan` output, or CloudWatch — `environment` entries are
plaintext in all three.

`app/app.py`: `app.secret_key = os.getenv("FLASK_SECRET_KEY", "local-dev-only-not-a-real-secret")`.
The literal fallback only ever runs locally — every real deployment
always sets `FLASK_SECRET_KEY` via the mechanism above, so it's
unreachable outside a laptop. Verified clean with `bandit -r app -ll -ii`
before committing (its hardcoded-secret check, B105, doesn't flag it at
the severity/confidence thresholds this project's CI already enforces).

IAM note: like every stage this session that introduces a genuinely new
AWS resource type, the GitHub Actions apply/plan roles needed new
permissions — `ssm:PutParameter`/`GetParameters`/`DescribeParameters`/
`AddTagsToResource`/`ListTagsForResource`/`DeleteParameter` were entirely
missing. Checked and fixed before the first live apply, continuing the
pattern established in Weeks 5–6.

What Was Achieved in Week 9

✔ A real, non-contrived secret — Flask's session-signing key — generated
  by Terraform, never committed, never typed by a human
✔ SSM Parameter Store (SecureString) + a dedicated KMS key, matching this
  project's existing per-purpose key convention
✔ Injected via ECS's native `secrets` field, not plaintext `environment`
  — the value never appears in the task definition, `terraform plan`
  output, or CloudWatch
✔ Least-privilege IAM: the execution role can read exactly this one
  parameter and decrypt exactly this one key, nothing broader
✔ The README's multi-week-old "upcoming" note is finally true

What's Next

ZAP (dynamic application security testing) and a written threat model —
the two roadmap items still outstanding after this week.
