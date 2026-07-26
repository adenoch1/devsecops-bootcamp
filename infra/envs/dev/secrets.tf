# ---------------------------------------------------------------------------
# Week 9: Real secrets management (SSM Parameter Store).
#
# Flask's own session/CSRF-signing key (`SECRET_KEY`) — the one secret
# every real Flask app has, whether or not sessions are actively used yet.
# The most natural first real secret for this project: everything else
# built so far (build metadata, config flags) is genuinely non-sensitive,
# so there was nothing honest to put here before now.
#
# Lives at the env level, not inside the ecs module, for the same reason
# observability.tf and codedeploy.tf do: it needs a cross-module wire
# (module.iam's execution role) that the ecs module itself doesn't own.
# ---------------------------------------------------------------------------

# Dedicated KMS key rather than reusing module.logging's CloudWatch Logs
# key — matches this project's established one-key-per-purpose convention
# (tfstate, dynamodb, alb-logs, cloudwatch-logs are all already separate).
# Small honest cost add: ~$1/month for the CMK itself, same as every other
# dedicated key in this project.
resource "aws_kms_key" "ssm_secrets" {
  description             = "KMS CMK for SSM Parameter Store secrets (Week 9)"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootPermissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowExecutionRoleDecrypt"
        Effect    = "Allow"
        Principal = { AWS = module.iam.ecs_task_execution_role_arn }
        Action    = ["kms:Decrypt", "kms:DescribeKey"]
        Resource  = "*"
      }
    ]
  })

  tags = merge(local.tags, { Name = "${local.name_prefix}-ssm-secrets-kms" })
}

resource "aws_kms_alias" "ssm_secrets" {
  name          = "alias/${local.name_prefix}-ssm-secrets"
  target_key_id = aws_kms_key.ssm_secrets.key_id
}

# Generated once, stored in Terraform state (already KMS-encrypted via the
# S3 backend — infra/bootstrap/main.tf) rather than typed anywhere in code.
# Rotating it is a `terraform taint` + apply away; nothing about that
# workflow depends on a human ever seeing the value.
resource "random_password" "flask_secret_key" {
  length  = 64
  special = true
}

resource "aws_ssm_parameter" "flask_secret_key" {
  name   = "/${local.name_prefix}/flask-secret-key"
  type   = "SecureString"
  key_id = aws_kms_key.ssm_secrets.arn
  value  = random_password.flask_secret_key.result

  tags = local.tags

  # The scheduled rotation workflow owns subsequent values. Terraform creates
  # the initial value and manages metadata without reverting a rotated secret.
  lifecycle {
    ignore_changes = [value]
  }
}

# The ECS *task execution* role fetches/decrypts secrets before the
# container starts (not the task role — that's a common mix-up). Scoped to
# exactly this one parameter and this one key, not a wildcard.
data "aws_iam_policy_document" "ecs_exec_ssm_read" {
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameters"]
    resources = [aws_ssm_parameter.flask_secret_key.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.ssm_secrets.arn]
  }
}

resource "aws_iam_role_policy" "ecs_exec_ssm_read" {
  name   = "${local.name_prefix}-ecs-exec-ssm-read"
  role   = module.iam.ecs_task_execution_role_name
  policy = data.aws_iam_policy_document.ecs_exec_ssm_read.json
}
