variable "service_name" {
  description = "Name of the service"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where RDS will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for RDS subnet group"
  type        = list(string)
}

variable "ecs_security_group_ids" {
  description = "Security group IDs of ECS tasks that need database access"
  type        = list(string)
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "shopping_cart"
}

variable "master_username" {
  description = "Master username for the database"
  type        = string
  default     = "admin"
}

variable "master_password" {
  description = "Master password for the database"
  type        = string
  sensitive   = true
}
