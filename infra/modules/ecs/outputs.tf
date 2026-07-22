output "alb_dns_name" {
  value = aws_lb.this.dns_name
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
  description = "Target Group ARN for health checks"
}

output "alb_target_group_arn_suffix" {
  value       = aws_lb_target_group.app.arn_suffix
  description = "Target group ARN suffix, used as the TargetGroup dimension for CloudWatch metrics/alarms"
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
