# ---------------------------------------------------------------------------
# Week 5 Stage 4: CodeDeploy Blue/Green for the ECS service.
#
# Lives at the env level (not inside the ecs module) for the same reason
# observability.tf does: it needs cross-resource references the ecs module
# doesn't own — the CloudWatch alarms defined in observability.tf, plus the
# blue/green target groups and listener exposed as module.ecs outputs.
# ---------------------------------------------------------------------------

resource "aws_iam_role" "codedeploy" {
  name = "${local.name_prefix}-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "codedeploy.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "codedeploy_ecs" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

resource "aws_codedeploy_app" "this" {
  name             = "${local.name_prefix}-app"
  compute_platform = "ECS"

  tags = local.tags
}

resource "aws_codedeploy_deployment_group" "this" {
  app_name               = aws_codedeploy_app.this.name
  deployment_group_name  = "${local.name_prefix}-dg"
  service_role_arn       = aws_iam_role.codedeploy.arn
  deployment_config_name = "CodeDeployDefault.ECSLinear10PercentEvery1Minutes"

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  # Reroute traffic to green as soon as its tasks are healthy — no manual
  # "continue-deployment" gate. This is a personal/interview-reference
  # project without an on-call human to gate on; the alarm-triggered
  # auto-rollback below is what keeps this safe unattended.
  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  # The point of Stage 4: an alarm firing mid-shift now aborts and reverts
  # the deployment automatically, not just a failed ECS health check
  # (which Stage 1's now-removed circuit breaker was limited to).
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  alarm_configuration {
    enabled = true
    alarms = [
      aws_cloudwatch_metric_alarm.alb_5xx.alarm_name,
      aws_cloudwatch_metric_alarm.app_error_rate.alarm_name,
    ]
  }

  ecs_service {
    cluster_name = module.ecs.ecs_cluster_name
    service_name = module.ecs.ecs_service_name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [module.ecs.alb_https_listener_arn]
      }

      target_group {
        name = module.ecs.alb_target_group_name
      }

      target_group {
        name = module.ecs.alb_target_group_green_name
      }
    }
  }

  tags = local.tags
}
