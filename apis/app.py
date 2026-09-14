"""
APIs de Produtos e Pedidos - E-commerce
Tecnologia: Python + Flask
"""

from flask import Flask, jsonify, request
import boto3
import json
import uuid
from datetime import datetime
import os

app = Flask(__name__)

SQS_QUEUE_URL = os.environ.get("SQS_QUEUE_URL", "https://sqs.us-east-1.amazonaws.com/123456789012/pedidos-a-processar")
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")

sqs = boto3.client("sqs", region_name=AWS_REGION)

PRODUTOS = [
    {"id": 1, "nome": "Notebook Gamer", "preco": 4599.90, "estoque": 15},
    {"id": 2, "nome": "Mouse Sem Fio", "preco": 89.90, "estoque": 120},
    {"id": 3, "nome": "Teclado Mecânico", "preco": 349.00, "estoque": 45},
    {"id": 4, "nome": "Monitor 27\" 144Hz", "preco": 1299.00, "estoque": 30},
    {"id": 5, "nome": "Headset Gamer", "preco": 299.90, "estoque": 80},
]

@app.route("/produtos", methods=["GET"])
def listar_produtos():
    return jsonify({
        "status": "ok",
        "total": len(PRODUTOS),
        "produtos": PRODUTOS
    }), 200

@app.route("/produtos/<int:produto_id>", methods=["GET"])
def obter_produto(produto_id):
    produto = next((p for p in PRODUTOS if p["id"] == produto_id), None)
    if not produto:
        return jsonify({"status": "erro", "mensagem": "Produto não encontrado"}), 404
    return jsonify({"status": "ok", "produto": produto}), 200

@app.route("/pedidos", methods=["POST"])
def criar_pedido():
    dados = request.get_json(silent=True)

    if not dados or "cliente" not in dados or "itens" not in dados:
        return jsonify({
            "status": "erro",
            "mensagem": "Body inválido. Envie 'cliente' e 'itens'."
        }), 400

    pedido = {
        "pedido_id": str(uuid.uuid4()),
        "cliente": dados["cliente"],
        "itens": dados["itens"],
        "status": "criado",
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }

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
    app.run(host="0.0.0.0", port=5000, debug=False)
