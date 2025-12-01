output "orders_queue_url" {
  description = "URL of the orders queue"
  value       = aws_sqs_queue.orders_queue.url
}

output "orders_dlq_url" {
  description = "URL of the orders DLQ"
  value       = aws_sqs_queue.orders_dlq.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic"
  value       = aws_sns_topic.order_notifications.arn
}

output "notification_queue_url" {
  description = "URL of the notification queue"
  value       = aws_sqs_queue.notification_queue.url
}

output "summary" {
  value = <<-EOT
  
  LocalStack Infrastructure Created!
  
  Export these environment variables to run your services:
  
  export AWS_REGION=us-west-2
  export AWS_ENDPOINT_URL=http://localhost:4566
  export SQS_QUEUE_URL=${aws_sqs_queue.orders_queue.url}
  export SNS_TOPIC_ARN=${aws_sns_topic.order_notifications.arn}
  export NOTIFICATION_QUEUE_URL=${aws_sqs_queue.notification_queue.url}
  
  To check DLQ:
  aws --endpoint-url=http://localhost:4566 sqs receive-message --queue-url ${aws_sqs_queue.orders_dlq.url}
  
  EOT
}