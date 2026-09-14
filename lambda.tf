# =============================================================================
# Serverless - Função Lambda + Trigger SQS + CloudWatch Logs
# =============================================================================

# -----------------------------------------------------------------------------
# IAM Role da Lambda
# -----------------------------------------------------------------------------
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Permissões: ler/deletar mensagens da SQS + escrever logs no CloudWatch
resource "aws_iam_role_policy" "lambda" {
  name = "${var.project_name}-${var.environment}-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.pedidos.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group (retenção de 14 dias)
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-processar-pedidos"
  retention_in_days = 14

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-logs"
  }
}

# -----------------------------------------------------------------------------
# Código da Lambda (Python) empacotado em ZIP
# -----------------------------------------------------------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"

  source {
    content  = <<-EOF
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Processa mensagens recebidas da fila SQS 'pedidos-a-processar'.
    Cada mensagem representa um pedido criado pela API de Pedidos.
    """
    logger.info("=== Início do processamento de pedidos ===")
    logger.info(f"Quantidade de mensagens recebidas: {len(event.get('Records', []))}")

    for record in event.get("Records", []):
        message_id = record.get("messageId", "N/A")
        body = record.get("body", "{}")

        try:
            pedido = json.loads(body)
        except json.JSONDecodeError:
            pedido = {"raw": body}

        logger.info(f"MessageId : {message_id}")
        logger.info(f"Pedido    : {json.dumps(pedido, ensure_ascii=False)}")

        # ---------------------------------------------------------------
        # Aqui ficaria a lógica real de negócio:
        # - Validar estoque
        # - Atualizar status do pedido
        # - Enviar e-mail de confirmação, etc.
        # ---------------------------------------------------------------

    logger.info("=== Processamento concluído com sucesso ===")
    return {
        "statusCode": 200,
        "body": json.dumps({"message": "Pedidos processados com sucesso"})
    }
EOF
    filename = "index.py"
  }
}

# -----------------------------------------------------------------------------
# Função Lambda
# -----------------------------------------------------------------------------
resource "aws_lambda_function" "processar_pedidos" {
  function_name = "${var.project_name}-${var.environment}-processar-pedidos"
  role          = aws_iam_role.lambda.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 128

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  depends_on = [
    aws_iam_role_policy.lambda,
    aws_cloudwatch_log_group.lambda
  ]

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.pedidos.url
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-processar-pedidos"
  }
}

# -----------------------------------------------------------------------------
# Trigger: SQS → Lambda (Event Source Mapping)
# -----------------------------------------------------------------------------
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.pedidos.arn
  function_name    = aws_lambda_function.processar_pedidos.arn
  batch_size       = 10
  enabled          = true
}
