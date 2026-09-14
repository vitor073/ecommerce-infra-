# =============================================================================
# Compute - Instância EC2 + IAM Role + User Data (APIs Flask)
# =============================================================================

# -----------------------------------------------------------------------------
# IAM Role da EC2 (permite enviar mensagens para a SQS)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_sqs" {
  name = "${var.project_name}-${var.environment}-ec2-sqs-policy"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.pedidos.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# -----------------------------------------------------------------------------
# AMI mais recente do Amazon Linux 2023
# -----------------------------------------------------------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -----------------------------------------------------------------------------
# Instância EC2
# -----------------------------------------------------------------------------
resource "aws_instance" "api" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  key_name               = var.key_name != "" ? var.key_name : null

  # User Data: instala e sobe as duas APIs Flask automaticamente
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    sqs_queue_url = aws_sqs_queue.pedidos.url
    aws_region    = var.aws_region
  }))

  tags = {
    Name = "${var.project_name}-${var.environment}-api-server"
  }

  # Evita recriação desnecessária quando a AMI mais recente muda
  lifecycle {
    ignore_changes = [ami]
  }
}
