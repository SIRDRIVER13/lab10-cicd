"""Mikroserwis catalog - katalog produktów (Python / Flask)."""
import os
import socket

from flask import Flask, jsonify

PRODUCTS = [
    {"id": 1, "name": "Kontener 20'", "price": 12500},
    {"id": 2, "name": "Kontener 40'", "price": 18900},
    {"id": 3, "name": "Kontener chłodniczy 40'", "price": 41200},
]


def create_app():
    app = Flask(__name__)
    app.json.ensure_ascii = False

    def version():
        return os.getenv("APP_VERSION", "dev")

    @app.get("/health")
    def health():
        if os.getenv("APP_BROKEN"):
            return jsonify(status="error", reason="APP_BROKEN", version=version()), 503
        return jsonify(status="ok", service="catalog", version=version())

    @app.get("/products")
    def products():
        return jsonify(service="catalog", version=version(), host=socket.gethostname(), items=PRODUCTS)

    @app.get("/products/<int:product_id>")
    def product(product_id):
        for item in PRODUCTS:
            if item["id"] == product_id:
                return jsonify(item)
        return jsonify(error="Nie znaleziono produktu"), 404

    return app
