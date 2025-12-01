# Dead Letter Queue for failed orders
resource "aws_sqs_queue" "order_dlq" {
  name = "${var.service_name}-dlq"
}

# Main SQS Queue for order processing with DLQ
resource "aws_sqs_queue" "order_queue" {
  name                       = "${var.service_name}-queue"
  visibility_timeout_seconds = 10  # Changed from 30 for faster testing
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20
  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.order_dlq.arn
    maxReceiveCount     = 3
  })
}

# SNS Topic for order notifications
resource "aws_sns_topic" "order_notifications" {
  name = "${var.service_name}-notifications"
}

# SQS Queue for notification service
resource "aws_sqs_queue" "notification_queue" {
  name                       = "${var.service_name}-notification-queue"
  visibility_timeout_seconds = 30
  receive_wait_time_seconds  = 20
}

# Subscribe notification queue to SNS topic
resource "aws_sns_topic_subscription" "notification_subscription" {
  topic_arn = aws_sns_topic.order_notifications.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.notification_queue.arn
}

# Allow SNS to send to notification queue
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