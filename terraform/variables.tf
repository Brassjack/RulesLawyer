variable "aws_region" {
  type        = string
  description = "AWS region for ECR, ECS, and logs."
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Prefix for resource names."
  default     = "rules-lawyer-bot"
}

variable "image_tag" {
  type        = string
  description = "Container image tag pushed to ECR (e.g. latest or a git sha)."
  default     = "latest"
}

variable "discord_bot_token" {
  type        = string
  description = "Discord bot token (Bot section in the Discord Developer Portal)."
  sensitive   = true
}

variable "anthropic_api_key" {
  type        = string
  description = "Anthropic API key for Claude."
  sensitive   = true
}

variable "fargate_cpu" {
  type        = number
  description = "Fargate task CPU units (256 = 0.25 vCPU)."
  default     = 256
}

variable "fargate_memory" {
  type        = number
  description = "Fargate task memory in MiB."
  default     = 512
}
