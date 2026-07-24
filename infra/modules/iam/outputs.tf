output "ecs_task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_execution_role_name" {
  value       = aws_iam_role.ecs_task_execution_role.name
  description = "Used at the env level to attach the SSM read/decrypt policy for Week 9's Flask secret key"
}

output "ecs_task_role_arn" {
  value = aws_iam_role.ecs_task_role.arn
}
