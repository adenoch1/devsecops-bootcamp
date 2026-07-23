data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.name_prefix}-ecs-task-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-task-exec"
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec_managed" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name               = "${var.name_prefix}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-task-role"
  })
}

# Least-privilege equivalent of the AWSXRayDaemonWriteAccess managed policy —
# only what the daemon sidecar actually calls: segment/telemetry writes, plus
# sampling-rule reads (the SDK polls these to decide what to trace; without
# read access it silently falls back to its built-in default rule, so this
# isn't strictly required, but denying it would spam CloudWatch with quiet
# AccessDenied noise on every poll interval).
data "aws_iam_policy_document" "xray_write" {
  statement {
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries",
    ]
    resources = ["*"] # X-Ray API actions do not support resource-level scoping
  }
}

resource "aws_iam_role_policy" "ecs_task_xray" {
  name   = "${var.name_prefix}-ecs-task-xray"
  role   = aws_iam_role.ecs_task_role.id
  policy = data.aws_iam_policy_document.xray_write.json
}
