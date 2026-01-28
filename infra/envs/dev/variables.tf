variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ca-central-1"
}

variable "project" {
  description = "Project name (used in naming/tagging)"
  type        = string
  default     = "devsecops-flask"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner tag value"
  type        = string
  default     = "enoch"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "app_port" {
  description = "Container port exposed by Flask app"
  type        = number
  default     = 5000
}

variable "container_image_tag" {
  description = "ECR image tag to run"
  type        = string
  default     = "v1.0.5"
}

variable "ecs_desired_count" {
  description = "Number of tasks"
  type        = number
  default     = 1
}

variable "task_cpu" {
  description = "Fargate CPU units (e.g., 256, 512, 1024)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate memory (MB) (e.g., 512, 1024, 2048)"
  type        = number
  default     = 512
}
