output "sns_topic_arn" {
  description = "ARN of the SNS topic"
  value       = aws_sns_topic.order_notifications.arn
}

output "sqs_queue_url" {
  description = "URL of the main orders queue"
  value       = aws_sqs_queue.order_queue.url
}

output "sqs_queue_arn" {
  description = "ARN of the orders queue"
  value       = aws_sqs_queue.order_queue.arn
}

output "dlq_url" {
  description = "URL of the DLQ"
  value       = aws_sqs_queue.order_dlq.url
}

output "dlq_arn" {
  description = "ARN of the DLQ"
  value       = aws_sqs_queue.order_dlq.arn
}

output "notification_queue_url" {
  description = "URL of the notification queue"
  value       = aws_sqs_queue.notification_queue.url
}