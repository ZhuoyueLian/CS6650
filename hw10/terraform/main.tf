# terraform/main.tf - Complete Terraform Configuration

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_caller_identity" "current" {}

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group
resource "aws_security_group" "services" {
  name        = "${var.project_name}-sg"
  description = "Security group for microservices"
  vpc_id      = data.aws_vpc.default.id

  # Allow HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow 8080 for services
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all traffic within security group
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  # Allow RabbitMQ AMQP
  ingress {
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow RabbitMQ Management
  ingress {
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-sg"
  })
}

# ECR Repositories
resource "aws_ecr_repository" "product_service" {
  name                 = "product-service"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  tags                 = var.tags
}

resource "aws_ecr_repository" "product_service_bad" {
  name                 = "product-service-bad"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  tags                 = var.tags
}

resource "aws_ecr_repository" "shopping_cart_service" {
  name                 = "shopping-cart-service"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  tags                 = var.tags
}

resource "aws_ecr_repository" "credit_card_authorizer" {
  name                 = "credit-card-authorizer"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  tags                 = var.tags
}

resource "aws_ecr_repository" "warehouse_service" {
  name                 = "warehouse-service"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  tags                 = var.tags
}

resource "aws_ecr_repository" "rabbitmq" {
  name                 = "rabbitmq"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  tags                 = var.tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "services" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
  tags = var.tags
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.services.id]
  subnets            = data.aws_subnets.default.ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-alb"
  })
}

# Target Groups
resource "aws_lb_target_group" "product_service" {
  name        = "product-service-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = var.tags
}

resource "aws_lb_target_group" "product_service_bad" {
  name        = "product-service-bad-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 10  # Higher threshold since it returns 503s
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = var.tags
}

resource "aws_lb_target_group" "shopping_cart" {
  name        = "shopping-cart-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = var.tags
}

resource "aws_lb_target_group" "cca" {
  name        = "cca-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = var.tags
}

# ALB Listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Service not found. Available paths: /products, /shopping-carts, /authorize"
      status_code  = "404"
    }
  }
}

# Listener Rules - Route by path
resource "aws_lb_listener_rule" "product" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.product_service.arn
  }

  condition {
    path_pattern {
      values = ["/products*"]
    }
  }
}

resource "aws_lb_listener_rule" "shopping_cart" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.shopping_cart.arn
  }

  condition {
    path_pattern {
      values = ["/shopping-carts*"]
    }
  }
}

resource "aws_lb_listener_rule" "cca" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 300

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cca.arn
  }

  condition {
    path_pattern {
      values = ["/authorize*"]
    }
  }
}

# ========================================
# ECS Task Definitions and Services
# ========================================

# RabbitMQ Task Definition
resource "aws_ecs_task_definition" "rabbitmq" {
  family                   = "rabbitmq-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.rabbitmq_cpu
  memory                   = var.rabbitmq_memory
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([{
    name      = "rabbitmq"
    image     = "${aws_ecr_repository.rabbitmq.repository_url}:latest"
    essential = true

    portMappings = [
      {
        containerPort = 5672
        protocol      = "tcp"
      },
      {
        containerPort = 15672
        protocol      = "tcp"
      }
    ]

    environment = [
      {
        name  = "RABBITMQ_DEFAULT_USER"
        value = var.rabbitmq_user
      },
      {
        name  = "RABBITMQ_DEFAULT_PASS"
        value = var.rabbitmq_password
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.services.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "rabbitmq"
      }
    }
  }])

  tags = var.tags
}

# RabbitMQ Service
resource "aws_ecs_service" "rabbitmq" {
  name            = "rabbitmq-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.rabbitmq.arn
  desired_count   = var.rabbitmq_service_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.services.id]
    assign_public_ip = true
  }

  tags = var.tags
}

# Product Service Task Definition
resource "aws_ecs_task_definition" "product_service" {
  family                   = "product-service-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.product_service_cpu
  memory                   = var.product_service_memory
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([{
    name      = "product-service"
    image     = "${aws_ecr_repository.product_service.repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.services.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "product-service"
      }
    }
  }])

  tags = var.tags
}

# Product Service
resource "aws_ecs_service" "product_service" {
  name            = "product-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.product_service.arn
  desired_count   = var.product_service_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.services.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.product_service.arn
    container_name   = "product-service"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.main]

  tags = var.tags
}

# Product Service Bad Task Definition
resource "aws_ecs_task_definition" "product_service_bad" {
  family                   = "product-service-bad-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.product_service_cpu
  memory                   = var.product_service_memory
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([{
    name      = "product-service-bad"
    image     = "${aws_ecr_repository.product_service_bad.repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.services.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "product-service-bad"
      }
    }
  }])

  tags = var.tags
}

# Product Service Bad
resource "aws_ecs_service" "product_service_bad" {
  name            = "product-service-bad"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.product_service_bad.arn
  desired_count   = var.product_bad_service_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.services.id]
    assign_public_ip = true
  }

  depends_on = [aws_lb_listener.main]

  tags = var.tags
}

# CCA Task Definition
resource "aws_ecs_task_definition" "cca" {
  family                   = "cca-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cca_cpu
  memory                   = var.cca_memory
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([{
    name      = "credit-card-authorizer"
    image     = "${aws_ecr_repository.credit_card_authorizer.repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]

    environment = [{
      name  = "PORT"
      value = "8080"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.services.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "cca"
      }
    }
  }])

  tags = var.tags
}

# CCA Service
resource "aws_ecs_service" "cca" {
  name            = "credit-card-authorizer"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.cca.arn
  desired_count   = var.cca_service_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.services.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.cca.arn
    container_name   = "credit-card-authorizer"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.main]

  tags = var.tags
}

# Shopping Cart Task Definition
resource "aws_ecs_task_definition" "shopping_cart" {
  family                   = "shopping-cart-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.shopping_cart_cpu
  memory                   = var.shopping_cart_memory
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([{
    name      = "shopping-cart-service"
    image     = "${aws_ecr_repository.shopping_cart_service.repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]

    environment = [
      {
        name  = "PORT"
        value = "8080"
      },
      {
        name  = "RABBITMQ_URL"
        value = "amqp://${var.rabbitmq_user}:${var.rabbitmq_password}@${aws_ecs_service.rabbitmq.name}.${var.project_name}:5672"
      },
      {
        name  = "CCA_SERVICE_URL"
        value = "http://${aws_lb.main.dns_name}/authorize"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.services.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "shopping-cart"
      }
    }
  }])

  tags = var.tags
}

# Shopping Cart Service
resource "aws_ecs_service" "shopping_cart" {
  name            = "shopping-cart-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.shopping_cart.arn
  desired_count   = var.shopping_cart_service_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.services.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.shopping_cart.arn
    container_name   = "shopping-cart-service"
    container_port   = 8080
  }

  depends_on = [
    aws_lb_listener.main,
    aws_ecs_service.rabbitmq,
    aws_ecs_service.cca
  ]

  tags = var.tags
}

# Warehouse Service Task Definition
resource "aws_ecs_task_definition" "warehouse" {
  family                   = "warehouse-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.warehouse_cpu
  memory                   = var.warehouse_memory
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([{
    name      = "warehouse-service"
    image     = "${aws_ecr_repository.warehouse_service.repository_url}:latest"
    essential = true

    environment = [{
      name  = "RABBITMQ_URL"
      value = "amqp://${var.rabbitmq_user}:${var.rabbitmq_password}@${aws_ecs_service.rabbitmq.name}.${var.project_name}:5672"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.services.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "warehouse"
      }
    }
  }])

  tags = var.tags
}

# Warehouse Service
resource "aws_ecs_service" "warehouse" {
  name            = "warehouse-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.warehouse.arn
  desired_count   = var.warehouse_service_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.services.id]
    assign_public_ip = true
  }

  depends_on = [aws_ecs_service.rabbitmq]

  tags = var.tags
}