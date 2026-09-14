# E-commerce - Infraestrutura como Código (Terraform)

Solução completa de **e-commerce** na AWS utilizando **Infraestrutura como Código (Terraform)**.

O projeto provisiona toda a infraestrutura necessária e sobe automaticamente duas APIs simples (Produtos e Pedidos) em uma instância EC2, com comunicação assíncrona via SQS + Lambda.

---

## 1. Arquitetura

```
Usuário
   │
   ▼
EC2 (APIs Flask - porta 5000)
   │  POST /pedidos
   ▼
SQS  (fila: pedidos-a-processar)
   │
   ▼
Lambda  (processar-pedidos)
   │
   ▼
CloudWatch Logs
```

### Componentes provisionados pelo Terraform

| Camada          | Recurso AWS                          | Arquivo        |
|-----------------|--------------------------------------|----------------|
| Rede            | VPC + Subnet pública + IGW + RT      | `vpc.tf`       |
| Segurança       | Security Group (SSH + HTTP + 5000)   | `security.tf`  |
| Compute         | EC2 (Amazon Linux 2023) + IAM Role   | `ec2.tf`       |
| Mensageria      | SQS `pedidos-a-processar` + DLQ      | `sqs.tf`       |
| Serverless      | Lambda + Event Source Mapping        | `lambda.tf`    |
| Observabilidade | CloudWatch Log Group                 | `lambda.tf`    |

### APIs disponíveis na EC2

| Método | Endpoint           | Descrição                                      |
|--------|--------------------|------------------------------------------------|
| GET    | `/`                | Documentação rápida dos endpoints              |
| GET    | `/health`          | Health check                                   |
| GET    | `/produtos`        | Lista todos os produtos                        |
| GET    | `/produtos/<id>`   | Detalhe de um produto                          |
| POST   | `/pedidos`         | Cria pedido e envia mensagem para a fila SQS   |

---

## 2. Estrutura do Repositório

```
ecommerce-infra/
├── providers.tf          # Provider AWS + versões
├── variables.tf          # Declaração de variáveis
├── terraform.tfvars      # Valores das variáveis
├── vpc.tf                # Rede (VPC, Subnet, IGW, Route Table)
├── security.tf           # Security Group
├── sqs.tf                # Fila SQS + Dead Letter Queue
├── lambda.tf             # Função Lambda + Trigger + Logs
├── ec2.tf                # Instância EC2 + IAM + User Data
├── user_data.sh          # Script de inicialização da EC2
├── outputs.tf            # Outputs úteis
├── apis/
│   ├── app.py            # Código das APIs (Flask)
│   └── requirements.txt  # Dependências Python
├── .gitignore
└── README.md
```

---

## 3. Pré-requisitos

- Conta AWS com permissões adequadas
- AWS CLI configurado (`aws configure`)
- Terraform >= 1.5
- (Opcional) Key Pair já criado na região escolhida

---

## 4. Como executar o Terraform

```bash
# 1. Clone o repositório
git clone <url-do-seu-repositorio>
cd ecommerce-infra

# 2. Ajuste as variáveis (opcional)
# Edite terraform.tfvars:
#   - key_name          → nome do seu Key Pair
#   - allowed_ssh_cidr  → seu IP público (recomendado: x.x.x.x/32)

# 3. Inicializa o Terraform
terraform init

# 4. Visualiza o plano de execução
terraform plan

# 5. Aplica a infraestrutura
terraform apply
```

Confirme com `yes` quando solicitado.

Ao final do `apply`, anote os outputs importantes:

```text
api_base_url          = "http://X.X.X.X:5000"
ec2_public_ip         = "X.X.X.X"
sqs_queue_url         = "https://sqs.us-east-1.amazonaws.com/..."
lambda_function_name  = "ecommerce-dev-processar-pedidos"
lambda_log_group      = "/aws/lambda/ecommerce-dev-processar-pedidos"
```

---

## 5. Como acessar a aplicação na EC2

Após o `terraform apply` terminar (aguarde ~2-3 minutos para o User Data finalizar a instalação):

```bash
# Health check
curl http://<EC2_PUBLIC_IP>:5000/health

# Listar produtos
curl http://<EC2_PUBLIC_IP>:5000/produtos

# Detalhe de um produto
curl http://<EC2_PUBLIC_IP>:5000/produtos/1
```

Substitua `<EC2_PUBLIC_IP>` pelo valor do output `ec2_public_ip`.

---

## 6. Como testar o fluxo de pedidos

### 6.1 Criar um pedido (API → SQS)

```bash
curl -X POST http://<EC2_PUBLIC_IP>:5000/pedidos \
  -H "Content-Type: application/json" \
  -d '{
    "cliente": "Maria Souza",
    "itens": [
      {"produto_id": 1, "quantidade": 1},
      {"produto_id": 3, "quantidade": 2}
    ]
  }'
```

Resposta esperada (exemplo):

```json
{
  "status": "ok",
  "mensagem": "Pedido criado e enviado para processamento",
  "pedido": {
    "pedido_id": "a1b2c3d4-...",
    "cliente": "Maria Souza",
    "itens": [...],
    "status": "criado",
    "timestamp": "2026-09-13T...",
    "sqs_message_id": "abc-123-..."
  }
}
```

### 6.2 Verificar a mensagem na fila SQS

- Acesse o **Console AWS** → **SQS**
- Selecione a fila `pedidos-a-processar`
- Clique em **Send and receive messages** → **Poll for messages**

> A mensagem normalmente é consumida rapidamente pela Lambda.  
> Se quiser ver a mensagem na fila, pause temporariamente o Event Source Mapping.

### 6.3 Verificar o log da Lambda no CloudWatch

- Acesse o **Console AWS** → **CloudWatch** → **Log groups**
- Abra o log group: `/aws/lambda/ecommerce-dev-processar-pedidos`
- Abra o stream mais recente

Você deverá ver logs semelhantes a:

```text
=== Início do processamento de pedidos ===
Quantidade de mensagens recebidas: 1
MessageId : abc-123-...
Pedido    : {"pedido_id": "...", "cliente": "Maria Souza", ...}
=== Processamento concluído com sucesso ===
```

---

## 7. Evidências

> **Instruções**: após executar o projeto, substitua as seções abaixo pelos prints reais.

### 7.1 EC2 com a aplicação rodando

```text
[Inserir print do terminal ou do navegador acessando]
curl http://<IP>:5000/health
curl http://<IP>:5000/produtos
```

### 7.2 Mensagem chegando no SQS

```text
[Inserir print do console SQS mostrando a mensagem ou o histórico]
```

### 7.3 Log da Lambda no CloudWatch

```text
[Inserir print do Log Group /aws/lambda/ecommerce-dev-processar-pedidos]
```

### 7.4 Saída do `terraform apply`

```text
[Inserir print ou trecho da saída do terraform apply com os outputs]
```

Exemplo de outputs:

```
Apply complete! Resources: XX added, 0 changed, 0 destroyed.

Outputs:

api_base_url = "http://54.XX.XX.XX:5000"
ec2_public_ip = "54.XX.XX.XX"
lambda_function_name = "ecommerce-dev-processar-pedidos"
lambda_log_group = "/aws/lambda/ecommerce-dev-processar-pedidos"
sqs_queue_url = "https://sqs.us-east-1.amazonaws.com/123456789012/pedidos-a-processar"
vpc_id = "vpc-0abc123..."
```

---

## 8. Fluxo Final Confirmado

```
Usuário → EC2 (API) → SQS → Lambda → CloudWatch Logs
```

1. Usuário chama `POST /pedidos`
2. API grava o pedido e envia mensagem para a fila `pedidos-a-processar`
3. Lambda é acionada automaticamente (Event Source Mapping)
4. Lambda processa a mensagem e grava logs no CloudWatch

---

## 9. Encerramento do Projeto

Ao finalizar os testes e coletar as evidências, **destrua toda a infraestrutura** para evitar custos:

```bash
terraform destroy
```

Confirme com `yes`.

Todos os recursos criados (VPC, EC2, SQS, Lambda, IAM Roles, etc.) serão removidos.

---

## 10. Variáveis principais (`terraform.tfvars`)

| Variável            | Descrição                              | Padrão        |
|---------------------|----------------------------------------|---------------|
| `project_name`      | Prefixo dos recursos                   | `ecommerce`   |
| `environment`       | Ambiente                               | `dev`         |
| `aws_region`        | Região AWS                             | `us-east-1`   |
| `vpc_cidr`          | CIDR da VPC                            | `10.0.0.0/16` |
| `subnet_cidr`       | CIDR da Subnet pública                 | `10.0.1.0/24` |
| `instance_type`     | Tipo da instância EC2                  | `t3.micro`    |
| `key_name`          | Nome do Key Pair                       | `""`          |
| `allowed_ssh_cidr`  | CIDR liberado para SSH                 | `0.0.0.0/0`   |

> **Recomendação de segurança**: altere `allowed_ssh_cidr` para o seu IP público (`x.x.x.x/32`).

---

**Projeto desenvolvido com foco em Infraestrutura como Código (Terraform), APIs simples e comunicação assíncrona.**
