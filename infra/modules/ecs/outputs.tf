output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "alb_zone_id" {
  value       = aws_lb.this.zone_id
  description = "Canonical hosted zone ID used by Route 53 aliases."
}

output "alb_arn" {
  value = aws_lb.this.arn
}

output "alb_name" {
  value = aws_lb.this.name
}

output "alb_arn_suffix" {
  value       = aws_lb.this.arn_suffix
  description = "ALB ARN suffix, used as the LoadBalancer dimension for CloudWatch metrics/alarms"
}

output "alb_target_group_arn" {
  value       = aws_lb_target_group.app.arn
  description = "Blue target group ARN for health checks"
}

output "alb_target_group_arn_suffix" {
  value       = aws_lb_target_group.app.arn_suffix
  description = "Blue target group ARN suffix, used as the TargetGroup dimension for CloudWatch metrics/alarms"
}

output "alb_target_group_name" {
  value       = aws_lb_target_group.app.name
  description = "Blue target group name, used by CodeDeploy's target_group_pair_info"
}

output "alb_target_group_green_name" {
  value       = aws_lb_target_group.green.name
  description = "Green target group name, used by CodeDeploy's target_group_pair_info"
}

output "alb_https_listener_arn" {
  value       = aws_lb_listener.https.arn
  description = "HTTPS listener ARN, used by CodeDeploy's target_group_pair_info prod_traffic_route"
}

output "app_container_name" {
  value       = "app"
  description = "App container name within the task definition, used by CodeDeploy's AppSpec"
}

output "app_container_port" {
  value       = local.app_port
  description = "App container port, used by CodeDeploy's AppSpec"
}

output "task_definition_arn" {
  value       = aws_ecs_task_definition.app.arn
  description = "Current task definition ARN — read by the deploy workflow to build the CodeDeploy AppSpec for each new revision"
}

output "ecs_cluster_name" {
  value       = aws_ecs_cluster.this.name
  description = "ECS cluster name"
}

output "ecs_service_name" {
  value       = aws_ecs_service.app.name
  description = "ECS service name"
}

output "app_log_group_name" {
  value       = aws_cloudwatch_log_group.app.name
  description = "CloudWatch Logs group for the application container, used by metric filters"
}

output "waf_web_acl_name" {
  value       = aws_wafv2_web_acl.alb.name
  description = "WAFv2 Web ACL name, used as the WebACL dimension for CloudWatch metrics"
}
