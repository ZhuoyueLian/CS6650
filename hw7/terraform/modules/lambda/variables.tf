variable "service_name" {
  type        = string
  description = "Service name"
}

variable "sns_topic_arn" {
  type        = string
  description = "SNS topic ARN"
}

variable "lambda_role_arn" {
  type        = string
  description = "IAM role for Lambda"
}

variable "lambda_zip_path" {
  type        = string
  description = "Path to Lambda zip file"
}