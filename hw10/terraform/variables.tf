# terraform/variables.tf

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "cs6650-microservices"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# Service configuration
variable "product_service_count" {
  description = "Number of Product Service tasks"
  type        = number
  default     = 2
}

variable "product_bad_service_count" {
  description = "Number of Bad Product Service tasks"
  type        = number
  default     = 1
}

variable "shopping_cart_service_count" {
  description = "Number of Shopping Cart Service tasks"
  type        = number
  default     = 2
}

variable "cca_service_count" {
  description = "Number of CCA Service tasks"
  type        = number
  default     = 2
}

variable "warehouse_service_count" {
  description = "Number of Warehouse Service tasks"
  type        = number
  default     = 1
}

variable "rabbitmq_service_count" {
  description = "Number of RabbitMQ tasks"
  type        = number
  default     = 1
}

# Container configuration
variable "product_service_cpu" {
  description = "CPU units for Product Service"
  type        = number
  default     = 256
}

variable "product_service_memory" {
  description = "Memory for Product Service (MB)"
  type        = number
  default     = 512
}

variable "shopping_cart_cpu" {
  description = "CPU units for Shopping Cart Service"
  type        = number
  default     = 256
}

variable "shopping_cart_memory" {
  description = "Memory for Shopping Cart Service (MB)"
  type        = number
  default     = 512
}

variable "cca_cpu" {
  description = "CPU units for CCA Service"
  type        = number
  default     = 256
}

variable "cca_memory" {
  description = "Memory for CCA Service (MB)"
  type        = number
  default     = 512
}

variable "warehouse_cpu" {
  description = "CPU units for Warehouse Service"
  type        = number
  default     = 256
}

variable "warehouse_memory" {
  description = "Memory for Warehouse Service (MB)"
  type        = number
  default     = 512
}

variable "rabbitmq_cpu" {
  description = "CPU units for RabbitMQ"
  type        = number
  default     = 512
}

variable "rabbitmq_memory" {
  description = "Memory for RabbitMQ (MB)"
  type        = number
  default     = 1024
}

# RabbitMQ configuration
variable "rabbitmq_user" {
  description = "RabbitMQ username"
  type        = string
  default     = "admin"
}

variable "rabbitmq_password" {
  description = "RabbitMQ password"
  type        = string
  default     = "admin123"
  sensitive   = true
}

# CloudWatch Logs
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

# Tags
variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "CS6650-hw10"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}