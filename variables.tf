# =============================================================================
# Variáveis do projeto
# =============================================================================

variable "project_name" {
  description = "Nome do projeto (usado como prefixo nos recursos)"
  type        = string
  default     = "ecommerce"
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block da Subnet pública"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability Zone da subnet pública"
  type        = string
  default     = "us-east-1a"
}

variable "instance_type" {
  description = "Tipo da instância EC2"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Nome do Key Pair existente na AWS (deixe vazio se não usar SSH)"
  type        = string
  default     = ""
}

variable "allowed_ssh_cidr" {
  description = "CIDR permitido para acesso SSH (recomendado: seu IP/32)"
  type        = string
  default     = "0.0.0.0/0"
}
