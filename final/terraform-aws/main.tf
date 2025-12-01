# Network infrastructure (VPC, subnets, security groups)
module "network" {
  source         = "./modules/network"
  service_name   = "order-pipeline"
  container_port = var.container_port
}

# Logging infrastructure
module "logging_order" {
  source            = "./modules/logging"
  service_name      = var.order_service_name
  retention_in_days = var.log_retention_days
}

module "logging_processor" {
  source            = "./modules/logging"
  service_name      = var.processor_service_name
  retention_in_days = var.log_retention_days
}

module "logging_notification" {
  source            = "./modules/logging"
  service_name      = var.notification_service_name
  retention_in_days = var.log_retention_days
}

# Messaging infrastructure (SQS + SNS with DLQ)
module "messaging" {
  source       = "./modules/messaging"
  service_name = "order-pipeline"
}

# IAM Role (reuse LabRole)
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# Default VPC
data "aws_vpc" "default" {
  default = true
}

# ============================================
# ECR Repositories for 3 services
# ============================================

module "ecr_order" {
  source          = "./modules/ecr"
  repository_name = var.order_service_name
}

module "ecr_processor" {
  source          = "./modules/ecr"
  repository_name = var.processor_service_name
}

module "ecr_notification" {
  source          = "./modules/ecr"
  repository_name = var.notification_service_name
}

# ============================================
# Application Load Balancer (only for Order Service)
# ============================================

module "alb" {
  source             = "./modules/alb"
  service_name       = var.order_service_name
  container_port     = var.container_port
  vpc_id             = data.aws_vpc.default.id
  subnet_ids         = module.network.subnet_ids
  security_group_ids = [module.network.security_group_id]
}

# ============================================
# ECS Service: Order Service (with ALB)
# ============================================

module "ecs_order" {
  source             = "./modules/ecs"
  service_name       = var.order_service_name
  image              = "${module.ecr_order.repository_url}:latest"
  container_port     = var.container_port
  subnet_ids         = module.network.subnet_ids
  security_group_ids = [module.network.security_group_id]
  execution_role_arn = data.aws_iam_role.lab_role.arn
  task_role_arn      = data.aws_iam_role.lab_role.arn
  log_group_name     = module.logging_order.log_group_name
  ecs_count          = var.min_capacity
  region             = var.aws_region
  cpu                = var.order_cpu
  memory             = var.order_memory

  # Messaging configuration
  sqs_queue_url = module.messaging.sqs_queue_url
  sns_topic_arn = ""  # Order service only publishes to SQS
  num_workers   = 0   # No workers in order service

  # Load Balancer
  target_group_arn   = module.alb.target_group_arn
  enable_autoscaling = false
}

# ============================================
# ECS Service: Processor Service (no ALB)
# ============================================

module "ecs_processor" {
  source             = "./modules/ecs"
  service_name       = var.processor_service_name
  image              = "${module.ecr_processor.repository_url}:latest"
  container_port     = var.container_port
  subnet_ids         = module.network.subnet_ids
  security_group_ids = [module.network.security_group_id]
  execution_role_arn = data.aws_iam_role.lab_role.arn
  task_role_arn      = data.aws_iam_role.lab_role.arn
  log_group_name     = module.logging_processor.log_group_name
  ecs_count          = var.min_capacity
  region             = var.aws_region
  cpu                = var.processor_cpu
  memory             = var.processor_memory

  # Messaging configuration
  sqs_queue_url = module.messaging.sqs_queue_url
  sns_topic_arn = module.messaging.sns_topic_arn
  num_workers   = var.num_processor_workers

  # No load balancer
  target_group_arn   = ""
  enable_autoscaling = false

  #
  failure_rate = var.processor_failure_rate
}

# ============================================
# ECS Service: Notification Service (no ALB)
# ============================================

module "ecs_notification" {
  source             = "./modules/ecs"
  service_name       = var.notification_service_name
  image              = "${module.ecr_notification.repository_url}:latest"
  container_port     = var.container_port
  subnet_ids         = module.network.subnet_ids
  security_group_ids = [module.network.security_group_id]
  execution_role_arn = data.aws_iam_role.lab_role.arn
  task_role_arn      = data.aws_iam_role.lab_role.arn
  log_group_name     = module.logging_notification.log_group_name
  ecs_count          = var.min_capacity
  region             = var.aws_region
  cpu                = var.notification_cpu
  memory             = var.notification_memory

  # Messaging configuration
  sqs_queue_url = module.messaging.notification_queue_url
  sns_topic_arn = ""  # Notification service only consumes from SQS
  num_workers   = 1

  # No load balancer
  target_group_arn   = ""
  enable_autoscaling = false
}

# ============================================
# Build and Push Docker Images to ECR
# ============================================

# Order Service Image
resource "docker_image" "order" {
  name = "${module.ecr_order.repository_url}:latest"
  build {
    context = "../order-service"
  }
}

resource "docker_registry_image" "order" {
  name = docker_image.order.name
  depends_on = [module.ecr_order]
}

# Processor Service Image
resource "docker_image" "processor" {
  name = "${module.ecr_processor.repository_url}:latest"
  build {
    context = "../processor-service"
  }
}

resource "docker_registry_image" "processor" {
  name = docker_image.processor.name
  depends_on = [module.ecr_processor]
}

# Notification Service Image
resource "docker_image" "notification" {
  name = "${module.ecr_notification.repository_url}:latest"
  build {
    context = "../notification-service"
  }
}

resource "docker_registry_image" "notification" {
  name = docker_image.notification.name
  depends_on = [module.ecr_notification]
}