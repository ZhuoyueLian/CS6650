output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}

output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "DNS name of the Application Load Balancer"
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_instance_endpoint
}

output "rds_address" {
  description = "RDS instance address"
  value       = module.rds.db_instance_address
}

output "database_name" {
  description = "Database name"
  value       = module.rds.db_name
}

# DynamoDB Outputs
output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = module.dynamodb.table_name
}

output "alb_dns_name_dynamodb" {
  description = "DNS name of the DynamoDB service ALB"
  value       = module.alb_dynamodb.alb_dns_name
}

output "ecs_service_name_dynamodb" {
  description = "DynamoDB ECS service name"
  value       = module.ecs_dynamodb.service_name
}
