output "alb_dns_name" {
  description = "DNS name of the Load Balancer for Order Service"
  value       = module.alb.alb_dns_name
}

output "order_service_url" {
  description = "URL to send orders"
  value       = "http://${module.alb.alb_dns_name}/orders"
}

output "sqs_queue_url" {
  description = "Main orders queue URL"
  value       = module.messaging.sqs_queue_url
}

output "dlq_url" {
  description = "Dead Letter Queue URL"
  value       = module.messaging.dlq_url
}

output "sns_topic_arn" {
  description = "SNS topic ARN for notifications"
  value       = module.messaging.sns_topic_arn
}

output "notification_queue_url" {
  description = "Notification queue URL"
  value       = module.messaging.notification_queue_url
}

output "check_dlq_command" {
  description = "Command to check DLQ messages"
  value       = "aws sqs receive-message --queue-url ${module.messaging.dlq_url} --region ${var.aws_region}"
}

output "summary" {
  value = <<-EOT
  
  ========================================
  AWS Infrastructure Deployed!
  ========================================
  
  Order Service: http://${module.alb.alb_dns_name}/orders
  
  Test with:
  curl -X POST http://${module.alb.alb_dns_name}/orders \
    -H "Content-Type: application/json" \
    -d '{"customer_id": 123, "items": [{"product_id": 1, "quantity": 2, "price": 10.0}]}'
  
  Check DLQ:
  aws sqs receive-message --queue-url ${module.messaging.dlq_url} --region ${var.aws_region}
  
  EOT
}