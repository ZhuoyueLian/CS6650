output "sns_topic_arn" {
  description = "ARN of the SNS topic"
  value       = aws_sns_topic.order_events.arn
}

output "sqs_queue_url" {
  description = "URL of the SQS queue"
  value       = aws_sqs_queue.order_queue.url
}

output "sqs_queue_arn" {
  description = "ARN of the SQS queue"
  value       = aws_sqs_queue.order_queue.arn
}