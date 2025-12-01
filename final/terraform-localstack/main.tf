# Dead Letter Queue
resource "aws_sqs_queue" "orders_dlq" {
  name = "orders-dlq"
}

# Main Orders Queue with DLQ configuration
resource "aws_sqs_queue" "orders_queue" {
  name                       = "orders-queue"
  visibility_timeout_seconds = 10
  message_retention_seconds  = 345600  # 4 days
  receive_wait_time_seconds  = 20      # Long polling
  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.orders_dlq.arn
    maxReceiveCount     = 3
  })
}

# SNS Topic for order notifications
resource "aws_sns_topic" "order_notifications" {
  name = "order-notifications"
}

# SQS Queue for notification service
resource "aws_sqs_queue" "notification_queue" {
  name                       = "notification-queue"
  visibility_timeout_seconds = 30
  receive_wait_time_seconds  = 20
}

# Subscribe notification queue to SNS topic
resource "aws_sns_topic_subscription" "notification_subscription" {
  topic_arn = aws_sns_topic.order_notifications.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.notification_queue.arn
}

# Allow SNS to send messages to notification queue
resource "aws_sqs_queue_policy" "notification_queue_policy" {
  queue_url = aws_sqs_queue.notification_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.notification_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.order_notifications.arn
          }
        }
      }
    ]
  })
}