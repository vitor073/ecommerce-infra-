# =============================================================================
# Valores das variáveis (ambiente de desenvolvimento)
# =============================================================================

project_name      = "ecommerce"
environment       = "dev"
aws_region        = "us-east-1"
vpc_cidr          = "10.0.0.0/16"
subnet_cidr       = "10.0.1.0/24"
availability_zone = "us-east-1a"
instance_type     = "t3.micro"
key_name          = ""          # Ex: "meu-keypair"
allowed_ssh_cidr  = "0.0.0.0/0" # IMPORTANTE: troque pelo seu IP/32 em produção
