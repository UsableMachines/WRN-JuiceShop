variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_bucket" {
  description = "AWS S3 bucket for remote state"
  type        = string
  default     = "wrn-demo"
}
variable "app_name" {
  description = "Application name"
  type        = string
  default     = "juice-shop"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 3000
}

variable "container_cpu" {
  description = "Container CPU units"
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "Container memory"
  type        = number
  default     = 512
}