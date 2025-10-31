# RDS MySQL instance for shopping cart database

resource "aws_db_subnet_group" "main" {
  name       = "${var.service_name}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.service_name}-db-subnet-group"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.service_name}-rds-sg"
  description = "Security group for RDS MySQL instance"
  vpc_id      = var.vpc_id

  # Allow MySQL traffic from ECS tasks
  ingress {
    description     = "MySQL from ECS"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = var.ecs_security_group_ids
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.service_name}-rds-sg"
  }
}

resource "aws_db_instance" "mysql" {
  identifier     = "${var.service_name}-mysql"
  engine         = "mysql"
  engine_version = "8.0.39"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = false

  db_name  = var.database_name
  username = var.master_username
  password = var.master_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # For learning/development - disable in production
  skip_final_snapshot             = true
  deletion_protection             = false
  backup_retention_period         = 0
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  # Performance and monitoring
  performance_insights_enabled = false
  monitoring_interval          = 0

  tags = {
    Name = "${var.service_name}-mysql"
  }
}
