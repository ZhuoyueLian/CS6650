# SNS Topic for order events
resource "aws_sns_topic" "order_events" {
  name = "${var.service_name}-events"
}

# SQS Queue for order processing
resource "aws_sqs_queue" "order_queue" {
  name                       = "${var.service_name}-queue"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600  # 4 days
  receive_wait_time_seconds  = 20      # Long polling
}

# Subscribe SQS queue to SNS topic
resource "aws_sns_topic_subscription" "order_queue_subscription" {
  topic_arn = aws_sns_topic.order_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.order_queue.arn
}

# Allow SNS to send messages to SQS
resource "aws_sqs_queue_policy" "order_queue_policy" {
  queue_url = aws_sqs_queue.order_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.order_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.order_events.arn
          }
        }
      }
    ]
  })
}