variable "name_prefix" {
  type        = string
  description = "Prefix for naming resources"
}

variable "tags" {
  type        = map(string)
  description = "Common tags"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs (ALB here)"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs (ECS tasks here)"
}

variable "ecr_repository_url" {
  type        = string
  description = "ECR repository URL"
}

variable "ecs_task_execution_role_arn" {
  type        = string
  description = "ECS task execution role ARN"
}

variable "ecs_task_role_arn" {
  type        = string
  description = "ECS task role ARN"
}

variable "app_port" {
  type        = number
  description = "Application port"
}

variable "container_image_tag" {
  type        = string
  description = "Image tag"
  default     = "latest"
}

variable "desired_count" {
  type        = number
  description = "Desired tasks"
  default     = 1
}

variable "task_cpu" {
  type        = number
  description = "Fargate CPU"
  default     = 256
}

variable "task_memory" {
  type        = number
  description = "Fargate memory (MB)"
  default     = 512
}
