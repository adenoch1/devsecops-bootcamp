# ---------------------------------------------------------------------------
# Week 4: CloudWatch dashboards, alarms, structured-log metric filter, SNS.
#
# Lives at the env level (not inside a module) because the alarms/dashboard
# need dimensions from both module.ecs and module.logging outputs. A separate
# SNS topic is created here rather than reusing infra/bootstrap's
# `ci_notifications` topic: bootstrap has no remote backend (its state is
# local-only, applied out-of-band), so there's no shared state for envs/dev
# to read its outputs from without adding a backend to bootstrap too — out of
# scope for this change.
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "alerts" {
  name              = "${local.name_prefix}-alerts"
  kms_master_key_id = module.logging.cloudwatch_logs_kms_key_arn

  tags = local.tags
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ---- Structured-log-based custom metric ----
# app/app.py emits JSON log lines with a top-level "level" field; this filter
# counts ERROR lines into a custom metric the alarm below watches.

resource "aws_cloudwatch_log_metric_filter" "app_errors" {
  name           = "${local.name_prefix}-app-errors"
  log_group_name = module.ecs.app_log_group_name
  pattern        = "{ $.level = \"ERROR\" }"

  metric_transformation {
    name          = "AppErrorCount"
    namespace     = "${local.name_prefix}/App"
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

# ---- Alarms ----

resource "aws_cloudwatch_metric_alarm" "app_error_rate" {
  alarm_name          = "${local.name_prefix}-app-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  namespace           = "${local.name_prefix}/App"
  metric_name         = aws_cloudwatch_log_metric_filter.app_errors.metric_transformation[0].name
  alarm_description   = "More than 5 application ERROR log lines in 5 minutes."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.name_prefix}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"

  dimensions = {
    LoadBalancer = module.ecs.alb_arn_suffix
  }

  alarm_description  = "ALB target 5xx responses exceeded threshold."
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "target_unhealthy" {
  alarm_name          = "${local.name_prefix}-target-unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"

  dimensions = {
    LoadBalancer = module.ecs.alb_arn_suffix
    TargetGroup  = module.ecs.alb_target_group_arn_suffix
  }

  alarm_description  = "One or more ALB targets are unhealthy."
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
}

# Error-budget burn signal: target 5xx responses exceed 1% of requests for
# three consecutive five-minute windows.
resource "aws_cloudwatch_metric_alarm" "availability_slo_burn" {
  alarm_name          = "${local.name_prefix}-availability-slo-burn"
  alarm_description   = "Target 5xx ratio exceeded the 99.9% availability SLO burn threshold."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  metric_query {
    id          = "error_rate"
    expression  = "IF(requests>0,100*errors/requests,0)"
    label       = "Target 5xx percentage"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = module.ecs.alb_arn_suffix
      }
    }
  }

  metric_query {
    id = "requests"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = module.ecs.alb_arn_suffix
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "latency_slo" {
  alarm_name          = "${local.name_prefix}-latency-p95-slo"
  alarm_description   = "ALB p95 target response time exceeded 500 ms."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = 0.5
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  extended_statistic  = "p95"
  period              = 300
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = module.ecs.alb_arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_running_below_desired" {
  alarm_name          = "${local.name_prefix}-ecs-running-below-desired"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  period              = 60
  statistic           = "Average"
  threshold           = var.desired_count
  namespace           = "ECS/ContainerInsights"
  metric_name         = "RunningTaskCount"

  dimensions = {
    ClusterName = module.ecs.ecs_cluster_name
    ServiceName = module.ecs.ecs_service_name
  }

  alarm_description  = "ECS service is running fewer tasks than desired."
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
}

# ---- Dashboard ----

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-platform"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "ECS CPU / Memory Utilization"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["ECS/ContainerInsights", "CpuUtilized", "ClusterName", module.ecs.ecs_cluster_name, "ServiceName", module.ecs.ecs_service_name],
            ["ECS/ContainerInsights", "MemoryUtilized", "ClusterName", module.ecs.ecs_cluster_name, "ServiceName", module.ecs.ecs_service_name]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "ALB Requests / Errors"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", module.ecs.alb_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", module.ecs.alb_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", module.ecs.alb_arn_suffix]
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title  = "ALB Target Response Time"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", module.ecs.alb_arn_suffix]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title  = "WAF Allowed / Blocked Requests"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["AWS/WAFV2", "AllowedRequests", "WebACL", module.ecs.waf_web_acl_name, "Region", var.aws_region, "Rule", "ALL"],
            ["AWS/WAFV2", "BlockedRequests", "WebACL", module.ecs.waf_web_acl_name, "Region", var.aws_region, "Rule", "ALL"]
          ]
        }
      },
      {
        type = "metric", x = 0, y = 12, width = 12, height = 6
        properties = {
          title  = "Application Error Rate"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["${local.name_prefix}/App", "AppErrorCount"]
          ]
        }
      }
    ]
  })
}
