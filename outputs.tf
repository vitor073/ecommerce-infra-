# =============================================================================
# Outputs - Informações importantes após o apply
# =============================================================================

output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID da Subnet pública"
  value       = aws_subnet.public.id
}

output "ec2_public_ip" {
  description = "IP público da EC2 (use este IP para acessar as APIs)"
  value       = aws_instance.api.public_ip
}

output "ec2_public_dns" {
  description = "DNS público da EC2"
  value       = aws_instance.api.public_dns
}

output "api_base_url" {
  description = "URL base das APIs"
  value       = "http://${aws_instance.api.public_ip}:5000"
}

output "sqs_queue_url" {
  description = "URL da fila SQS pedidos-a-processar"
  value       = aws_sqs_queue.pedidos.url
}

output "sqs_queue_arn" {
  description = "ARN da fila SQS"
  value       = aws_sqs_queue.pedidos.arn
}

output "lambda_function_name" {
  description = "Nome da função Lambda"
  value       = aws_lambda_function.processar_pedidos.function_name
}

output "lambda_log_group" {
  description = "Log Group do CloudWatch da Lambda"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "security_group_id" {
  description = "ID do Security Group da EC2"
  value       = aws_security_group.ec2.id
}
