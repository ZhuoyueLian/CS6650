# DynamoDB table for shopping cart

resource "aws_dynamodb_table" "shopping_carts" {
  name         = "${var.service_name}-carts"
  billing_mode = "PAY_PER_REQUEST" # On-demand pricing for variable workload
  hash_key     = "cart_id"

  attribute {
    name = "cart_id"
    type = "S" # String type
  }

  # Enable point-in-time recovery (optional for production)
  point_in_time_recovery {
    enabled = false # Disabled for assignment to reduce costs
  }

  # Enable server-side encryption
  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "${var.service_name}-carts"
    Environment = "learning"
  }
}
