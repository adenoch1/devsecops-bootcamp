output "alb_dns_name" {
  description = "ALB DNS name (if ECS module is enabled)"
  value       = try(module.ecs.alb_dns_name, null)
}

output "ecr_repository_url" {
  description = "ECR repository URL (if ECR module is enabled)"
  value       = try(module.ecr.repository_url, null)
}

output "alb_arn" {
  description = "ALB ARN (if ECS module is enabled)"
  value       = try(module.ecs.alb_arn, null)
}


output "alb_target_group_arn" {
  description = "ALB Target Group ARN"
  value       = try(module.ecs.alb_target_group_arn, null)
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = try(module.ecs.ecs_cluster_name, null)
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = try(module.ecs.ecs_service_name, null)
}

output "task_definition_arn" {
  description = "Current ECS task definition ARN — the deploy workflow reads this after `terraform apply` to build the CodeDeploy AppSpec for the revision just registered"
  value       = try(module.ecs.task_definition_arn, null)
}

output "app_container_name" {
  description = "App container name, used by the deploy workflow's CodeDeploy AppSpec"
  value       = try(module.ecs.app_container_name, null)
}

output "app_container_port" {
  description = "App container port, used by the deploy workflow's CodeDeploy AppSpec"
  value       = try(module.ecs.app_container_port, null)
}

output "codedeploy_app_name" {
  description = "CodeDeploy application name, used by the deploy workflow's create-deployment call"
  value       = try(aws_codedeploy_app.this.name, null)
}

output "codedeploy_deployment_group_name" {
  description = "CodeDeploy deployment group name, used by the deploy workflow's create-deployment call"
  value       = try(aws_codedeploy_deployment_group.this.deployment_group_name, null)
}
