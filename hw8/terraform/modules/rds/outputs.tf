output "db_instance_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.mysql.endpoint
}

output "db_instance_address" {
  description = "The address of the RDS instance"
  value       = aws_db_instance.mysql.address
}

output "db_instance_port" {
  description = "The port of the RDS instance"
  value       = aws_db_instance.mysql.port
}

output "db_name" {
  description = "The database name"
  value       = aws_db_instance.mysql.db_name
}

output "db_username" {
  description = "The master username"
  value       = aws_db_instance.mysql.username
  sensitive   = true
}
