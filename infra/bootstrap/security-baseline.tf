# -----------------------------------------------------------------------
# Week 6: Account Security Baseline (GuardDuty + Security Hub + Config)
#
# Lives here, not in infra/envs/dev, because all three services are
# account+region singletons — AWS allows exactly one GuardDuty detector,
# one Security Hub subscription, one Config recorder per account per
# region. They aren't scoped to envs/dev's VPC/ECS service the way
# Weeks 1-5 were; they monitor the whole account, including resources
# this project's CDK sibling deploys. Applied manually/out-of-band like
# the rest of bootstrap (no CI workflow references infra/bootstrap, no
# remote backend) — not ported to the CDK repo for the same singleton
# reason: a second aws_guardduty_detector there wouldn't duplicate this
# one, it would conflict with it.
#
# Honest cost note: none of these three services are free. Rough scale
# for an account this small: GuardDuty analyzes CloudTrail/VPC Flow Log/
# DNS activity (typically low single-digit $/month at this event volume);
# Security Hub bills ~$0.0010 per security check per region (dozens of
# checks in the Foundational Security Best Practices standard); Config
# bills ~$0.003 per recorded configuration item + ~$0.001 per rule
# evaluation. Combined, realistically a handful of dollars a month.
# -----------------------------------------------------------------------

# ---- GuardDuty ----

resource "aws_guardduty_detector" "this" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  tags = merge(var.tags, { Name = "${var.name_prefix}-guardduty" })
}

# ---- Security Hub ----

resource "aws_securityhub_account" "this" {
  enable_default_standards = false
}

resource "aws_securityhub_standards_subscription" "fsbp" {
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.this]
}

# ---- AWS Config ----

data "aws_iam_policy" "config_role" {
  arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role" "config" {
  name = "${var.name_prefix}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, { Name = "${var.name_prefix}-config-role" })
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = data.aws_iam_policy.config_role.arn
}

resource "aws_config_configuration_recorder" "this" {
  name     = "${var.name_prefix}-config-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported = true
    # all_supported alone only covers regional resource types. Global
    # resources (IAM roles/policies — this project has many) need this
    # explicitly set too. Only one Config recorder per account should set
    # this to true, to avoid duplicate global-resource recording across
    # regions; since this account has exactly one recorder, that's moot.
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "this" {
  name           = "${var.name_prefix}-config-delivery"
  s3_bucket_name = aws_s3_bucket.logs.id
  s3_key_prefix  = "config"

  # Neither of these is referenced in an argument above, so Terraform
  # otherwise has no dependency edge to either and can create this
  # concurrently with the recorder — AWS's Config API rejects a delivery
  # channel with "Configuration recorder is not available" if the
  # recorder isn't created first. Found via a real apply attempt.
  depends_on = [aws_s3_bucket_policy.logs, aws_config_configuration_recorder.this]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}

# Curated, not exhaustive — each rule checks a resource type this project
# actually has, so every rule produces a real, meaningful evaluation
# against real resources instead of evaluating against nothing.
locals {
  config_rules = {
    s3-sse-enabled          = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED" # every S3 bucket in this project is KMS-encrypted
    s3-no-public-read       = "S3_BUCKET_PUBLIC_READ_PROHIBITED"         # every bucket already blocks public access
    s3-no-public-write      = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"        # same
    cloudtrail-enabled      = "CLOUD_TRAIL_ENABLED"                      # the pre-existing management-events trail
    vpc-flow-logs-enabled   = "VPC_FLOW_LOGS_ENABLED"                    # Week 1-2's network module already has these
    iam-no-admin-statements = "IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS"
    alb-waf-enabled         = "ALB_WAF_ENABLED" # Week 1-3's ALB has WAFv2 attached
  }
}

resource "aws_config_config_rule" "this" {
  for_each = local.config_rules

  name = "${var.name_prefix}-${each.key}"

  source {
    owner             = "AWS"
    source_identifier = each.value
  }

  depends_on = [aws_config_configuration_recorder.this]
}

# ---- Alerting: reuse envs/dev's real, already-subscribed SNS topic ----
# Bootstrap has its own aws_sns_topic.ci_notifications (github-actions-
# sns.tf), but nothing is actually subscribed to it in Terraform anywhere
# — it's unused. The topic that genuinely delivers to a human today is
# envs/dev's aws_sns_topic.alerts (Week 4, has a real email subscription).
# Bootstrap has no remote-state coupling to envs/dev, so this is a simple
# by-name lookup rather than a cross-state dependency.

data "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"
}

resource "aws_sns_topic_policy" "alerts_eventbridge" {
  arn = data.aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowEventBridgePublish"
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = data.aws_sns_topic.alerts.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = [
              aws_cloudwatch_event_rule.guardduty_findings.arn,
              aws_cloudwatch_event_rule.securityhub_findings.arn,
              aws_cloudwatch_event_rule.config_noncompliant.arn,
            ]
          }
        }
      }
    ]
  })
}

# Medium+ only — skip Low/informational findings to keep the inbox useful.
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name = "${var.name_prefix}-guardduty-findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 4] }]
    }
  })

  tags = merge(var.tags, { Name = "${var.name_prefix}-guardduty-findings" })
}

resource "aws_cloudwatch_event_target" "guardduty_findings" {
  rule = aws_cloudwatch_event_rule.guardduty_findings.name
  arn  = data.aws_sns_topic.alerts.arn
}

# High/Critical only — the FSBP standard alone produces dozens of checks;
# most findings at Low/Medium aren't worth an email.
resource "aws_cloudwatch_event_rule" "securityhub_findings" {
  name = "${var.name_prefix}-securityhub-findings"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["HIGH", "CRITICAL"]
        }
        Workflow = {
          Status = ["NEW"]
        }
      }
    }
  })

  tags = merge(var.tags, { Name = "${var.name_prefix}-securityhub-findings" })
}

resource "aws_cloudwatch_event_target" "securityhub_findings" {
  rule = aws_cloudwatch_event_rule.securityhub_findings.name
  arn  = data.aws_sns_topic.alerts.arn
}

# Non-compliant only — compliant evaluations aren't actionable alerts.
resource "aws_cloudwatch_event_rule" "config_noncompliant" {
  name = "${var.name_prefix}-config-noncompliant"

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      messageType = ["ComplianceChangeNotification"]
      newEvaluationResult = {
        complianceType = ["NON_COMPLIANT"]
      }
    }
  })

  tags = merge(var.tags, { Name = "${var.name_prefix}-config-noncompliant" })
}

resource "aws_cloudwatch_event_target" "config_noncompliant" {
  rule = aws_cloudwatch_event_rule.config_noncompliant.name
  arn  = data.aws_sns_topic.alerts.arn
}
