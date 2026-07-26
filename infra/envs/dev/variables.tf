variable "aws_region" {
  type        = string
  description = "Primary AWS region"
}

variable "project" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Environment name (dev/stage/prod)"
}

variable "owner" {
  type        = string
  description = "Owner tag"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR range"
}

variable "app_port" {
  type        = number
  description = "Application port"
  default     = 5000
}

variable "container_image_tag" {
  type        = string
  description = "Container image tag"
  default     = "bootstrap"
}

variable "git_sha" {
  type        = string
  description = "Git commit SHA of the deployed build (injected by CI)"
  default     = "dev"
}

variable "build_time" {
  type        = string
  description = "UTC build timestamp of the deployed image (injected by CI)"
  default     = "unknown"
}

variable "task_cpu" {
  type        = number
  description = "Fargate task CPU"
  default     = 256
}

variable "task_memory" {
  type        = number
  description = "Fargate task memory"
  default     = 512
}

variable "desired_count" {
  type        = number
  description = "ECS desired task count"
  default     = 1
}

variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS listener"
}

variable "alb_log_prefix" {
  type        = string
  description = "ALB access log prefix in the S3 logs bucket"
  default     = "alb-access"
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention (days)"
  default     = 365
}

variable "flow_log_retention_days" {
  type        = number
  description = "VPC flow log retention (days)"
  default     = 365
}

# Logging bucket lifecycle settings
variable "lifecycle_expire_days" {
  type        = number
  description = "Expire ALB logs after N days"
  default     = 365
}

variable "lifecycle_glacier_days" {
  type        = number
  description = "Transition ALB logs to Glacier after N days"
  default     = 90
}

# Replication (OPTIONAL)
variable "replication_enabled" {
  type        = bool
  description = "Enable cross-region replication for ALB logs"
  default     = false
}

variable "replication_region" {
  type        = string
  description = "Secondary region for replication (used by aws.replica provider alias)"
  default     = "us-east-1"
}

variable "health_check_path" {
  description = "Health check path for ALB target group"
  type        = string
  default     = "/health"
}

variable "terraform_role_name" {
  type        = string
  description = "Terraform deploy role name"
}

variable "alert_email" {
  type        = string
  description = "Email address subscribed to CloudWatch alarm notifications. Left empty by default so this never has to be committed to terraform.tfvars (public repo) — real applies must pass a value via -var, TF_VAR_alert_email, or a CI secret."
  default     = ""
}

variable "nat_gateway_per_az" {
  type        = bool
  description = "Whether each AZ receives its own NAT gateway."
  default     = true
}

variable "autoscaling_min_capacity" {
  type    = number
  default = 2
}

variable "autoscaling_max_capacity" {
  type    = number
  default = 10
}

variable "autoscaling_cpu_target" {
  type    = number
  default = 60
}

variable "autoscaling_memory_target" {
  type    = number
  default = 70
}

variable "waf_rate_limit" {
  type    = number
  default = 2000
}

variable "route53_zone_id" {
  type        = string
  description = "Route 53 hosted zone ID. Empty disables the managed alias."
  default     = ""
}

variable "fqdn" {
  type        = string
  description = "Application DNS name managed by Terraform when route53_zone_id is set."
  default     = ""
}
