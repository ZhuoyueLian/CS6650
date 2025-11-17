# terraform/outputs.tf

output "load_balancer_dns" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_url" {
  description = "URL of the Application Load Balancer"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value = {
    product_service         = aws_ecr_repository.product_service.repository_url
    product_service_bad     = aws_ecr_repository.product_service_bad.repository_url
    shopping_cart_service   = aws_ecr_repository.shopping_cart_service.repository_url
    credit_card_authorizer  = aws_ecr_repository.credit_card_authorizer.repository_url
    warehouse_service       = aws_ecr_repository.warehouse_service.repository_url
    rabbitmq                = aws_ecr_repository.rabbitmq.repository_url
  }
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "security_group_id" {
  description = "Security group ID for services"
  value       = aws_security_group.services.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = data.aws_vpc.default.id
}

output "subnet_ids" {
  description = "Subnet IDs"
  value       = data.aws_subnets.default.ids
}

output "rabbitmq_service_name" {
  description = "RabbitMQ ECS service name"
  value       = aws_ecs_service.rabbitmq.name
}

output "target_group_arns" {
  description = "Target Group ARNs"
  value = {
    product_service        = aws_lb_target_group.product_service.arn
    product_service_bad    = aws_lb_target_group.product_service_bad.arn
    shopping_cart_service  = aws_lb_target_group.shopping_cart.arn
    credit_card_authorizer = aws_lb_target_group.cca.arn
  }
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.services.name
}

# Testing endpoints
output "test_commands" {
  description = "Commands to test the deployment"
  value = <<-EOT
    # Test Product Service
    curl http://${aws_lb.main.dns_name}/products/1

    # Test Shopping Cart Service
    curl -X POST http://${aws_lb.main.dns_name}/shopping-carts \
      -H "Content-Type: application/json" \
      -d '{"customer_id":"TEST-001"}'

    # Test Credit Card Authorizer
    curl -X POST http://${aws_lb.main.dns_name}/authorize \
      -H "Content-Type: application/json" \
      -d '{"credit_card_number":"1234-5678-9012-3456","amount":100.50}'

    # Full checkout flow
    CART_ID=$(curl -s -X POST http://${aws_lb.main.dns_name}/shopping-carts \
      -H "Content-Type: application/json" \
      -d '{"customer_id":"TEST-001"}' | jq -r '.cart_id')
    
    curl -X POST http://${aws_lb.main.dns_name}/shopping-carts/$CART_ID/items \
      -H "Content-Type: application/json" \
      -d '{"product_id":"PROD-001","quantity":2}'
    
    curl -X POST http://${aws_lb.main.dns_name}/shopping-carts/$CART_ID/checkout \
      -H "Content-Type: application/json" \
      -d '{"credit_card_number":"1234-5678-9012-3456"}'
  EOT
}

output "deployment_summary" {
  description = "Summary of deployment"
  value = <<-EOT
    ========================================
    Deployment Summary
    ========================================
    
    Load Balancer URL: http://${aws_lb.main.dns_name}
    ECS Cluster: ${aws_ecs_cluster.main.name}
    Region: ${var.aws_region}
    
    Service Counts:
    - Product Service: ${var.product_service_count} tasks
    - Product Service (Bad): ${var.product_bad_service_count} task
    - Shopping Cart Service: ${var.shopping_cart_service_count} tasks
    - Credit Card Authorizer: ${var.cca_service_count} tasks
    - Warehouse Service: ${var.warehouse_service_count} task
    - RabbitMQ: ${var.rabbitmq_service_count} task
    
    Next Steps:
    1. Wait 2-3 minutes for services to start
    2. Check service health in ECS Console
    3. Run test commands above
    4. Monitor CloudWatch Logs: ${aws_cloudwatch_log_group.services.name}
    
    ========================================
  EOT
}