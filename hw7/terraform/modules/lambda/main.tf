# Lambda function
resource "aws_lambda_function" "order_processor" {
  filename         = var.lambda_zip_path
  function_name    = "${var.service_name}-processor"
  role            = var.lambda_role_arn
  handler         = "bootstrap"
  source_code_hash = filebase64sha256(var.lambda_zip_path)
  runtime         = "provided.al2"
  memory_size     = 512
  timeout         = 30

  environment {
    variables = {
      SERVICE_NAME = var.service_name
    }
  }
}

# Subscribe Lambda to SNS
resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = var.sns_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.order_processor.arn
}

# Allow SNS to invoke Lambda
resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.order_processor.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.sns_topic_arn
}