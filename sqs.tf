# =============================================================================
# Mensageria - Fila SQS "pedidos-a-processar" + Dead Letter Queue
# =============================================================================

# Dead Letter Queue (mensagens que falharam após 3 tentativas)
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-${var.environment}-pedidos-dlq"
  message_retention_seconds = 1209600 # 14 dias

  tags = {
    Name = "${var.project_name}-${var.environment}-pedidos-dlq"
  }
}

# Fila principal de pedidos
resource "aws_sqs_queue" "pedidos" {
  name                       = "pedidos-a-processar"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600 # 4 dias
  receive_wait_time_seconds  = 10     # Long polling (mais eficiente)

  # Redireciona para DLQ após 3 tentativas de processamento
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-pedidos-a-processar"
  }
}
