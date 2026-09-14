#!/bin/bash
set -e

# =============================================================================
# User Data - Instala e sobe as APIs de Produtos e Pedidos (Python Flask)
# =============================================================================

exec > /var/log/user-data.log 2>&1
echo "=== Iniciando configuração da EC2 ==="

# Atualiza o sistema e instala dependências
dnf update -y
dnf install -y python3 python3-pip git

# Cria diretório da aplicação
mkdir -p /opt/apis
cd /opt/apis

# -----------------------------------------------------------------------------
# Instala Flask e boto3
# -----------------------------------------------------------------------------
pip3 install flask boto3

# -----------------------------------------------------------------------------
# API de Produtos + API de Pedidos (um único app Flask)
# -----------------------------------------------------------------------------
cat > /opt/apis/app.py << 'APPEOF'
from flask import Flask, jsonify, request
import boto3
import json
import uuid
from datetime import datetime
import os

app = Flask(__name__)

# Configuração da fila SQS (injetada pelo Terraform)
SQS_QUEUE_URL = "${sqs_queue_url}"
AWS_REGION = "${aws_region}"

sqs = boto3.client("sqs", region_name=AWS_REGION)

# Lista estática de produtos (simulação de banco de dados)
PRODUTOS = [
    {"id": 1, "nome": "Notebook Gamer", "preco": 4599.90, "estoque": 15},
    {"id": 2, "nome": "Mouse Sem Fio", "preco": 89.90, "estoque": 120},
    {"id": 3, "nome": "Teclado Mecânico", "preco": 349.00, "estoque": 45},
    {"id": 4, "nome": "Monitor 27\" 144Hz", "preco": 1299.00, "estoque": 30},
    {"id": 5, "nome": "Headset Gamer", "preco": 299.90, "estoque": 80},
]

# -----------------------------------------------------------------------------
# API de Produtos
# -----------------------------------------------------------------------------
@app.route("/produtos", methods=["GET"])
def listar_produtos():
    """Retorna a lista completa de produtos."""
    return jsonify({
        "status": "ok",
        "total": len(PRODUTOS),
        "produtos": PRODUTOS
    }), 200


@app.route("/produtos/<int:produto_id>", methods=["GET"])
def obter_produto(produto_id):
    """Retorna um produto específico pelo ID."""
    produto = next((p for p in PRODUTOS if p["id"] == produto_id), None)
    if not produto:
        return jsonify({"status": "erro", "mensagem": "Produto não encontrado"}), 404
    return jsonify({"status": "ok", "produto": produto}), 200


# -----------------------------------------------------------------------------
# API de Pedidos
# -----------------------------------------------------------------------------
@app.route("/pedidos", methods=["POST"])
def criar_pedido():
    """
    Cria um novo pedido e envia a mensagem para a fila SQS.
    Body esperado (JSON):
    {
      "cliente": "João Silva",
      "itens": [
        {"produto_id": 1, "quantidade": 1},
        {"produto_id": 2, "quantidade": 2}
      ]
    }
    """
    dados = request.get_json(silent=True)

    if not dados or "cliente" not in dados or "itens" not in dados:
        return jsonify({
            "status": "erro",
            "mensagem": "Body inválido. Envie 'cliente' e 'itens'."
        }), 400

    # Monta o pedido
    pedido = {
        "pedido_id": str(uuid.uuid4()),
        "cliente": dados["cliente"],
        "itens": dados["itens"],
        "status": "criado",
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }

    # Envia mensagem para a fila SQS
    try:
        response = sqs.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(pedido, ensure_ascii=False)
        )
        pedido["sqs_message_id"] = response["MessageId"]
    except Exception as e:
        return jsonify({
            "status": "erro",
            "mensagem": f"Falha ao enviar para SQS: {str(e)}"
        }), 500

    return jsonify({
        "status": "ok",
        "mensagem": "Pedido criado e enviado para processamento",
        "pedido": pedido
    }), 201


@app.route("/health", methods=["GET"])
def health():
    """Health check simples."""
    return jsonify({"status": "ok", "service": "apis-produtos-pedidos"}), 200


@app.route("/", methods=["GET"])
def home():
    return jsonify({
        "mensagem": "APIs de Produtos e Pedidos",
        "endpoints": {
            "GET /produtos": "Lista todos os produtos",
            "GET /produtos/<id>": "Detalhe de um produto",
            "POST /pedidos": "Cria um pedido e envia para SQS",
            "GET /health": "Health check"
        }
    }), 200


if __name__ == "__main__":
    # Escuta em todas as interfaces na porta 5000
    app.run(host="0.0.0.0", port=5000, debug=False)
APPEOF

# -----------------------------------------------------------------------------
# Cria serviço systemd para manter a API sempre rodando
# -----------------------------------------------------------------------------
cat > /etc/systemd/system/apis.service << 'SERVICEEOF'
[Unit]
Description=APIs de Produtos e Pedidos (Flask)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/apis
ExecStart=/usr/bin/python3 /opt/apis/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Habilita e inicia o serviço
systemctl daemon-reload
systemctl enable apis.service
systemctl start apis.service

echo "=== Configuração concluída com sucesso ==="
echo "APIs rodando em http://0.0.0.0:5000"
echo "Fila SQS: ${sqs_queue_url}"
