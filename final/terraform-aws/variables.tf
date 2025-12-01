variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "log_retention_days" {
  type    = number
  default = 7
}

# Order Service variables
variable "order_service_name" {
  type    = string
  default = "order-service"
}

variable "order_cpu" {
  type    = string
  default = "256"
}

variable "order_memory" {
  type    = string
  default = "512"
}

# Processor Service variables
variable "processor_service_name" {
  type    = string
  default = "processor-service"
}

variable "processor_cpu" {
  type    = string
  default = "256"
}

variable "processor_memory" {
  type    = string
  default = "512"
}

variable "processor_failure_rate" {
  type        = string
  default     = "0"
  description = "Failure rate for processor (0.0 to 1.0). Set to 0.5 for 50% failure rate during testing"
}

variable "num_processor_workers" {
  type    = number
  default = 2
}

# Notification Service variables
variable "notification_service_name" {
  type    = string
  default = "notification-service"
}

variable "notification_cpu" {
  type    = string
  default = "256"
}

variable "notification_memory" {
  type    = string
  default = "512"
}

# Scaling settings
variable "min_capacity" {
  type    = number
  default = 1
}

variable "max_capacity" {
  type    = number
  default = 1
}