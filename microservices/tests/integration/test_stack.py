"""Testy integracyjne stosu gateway + catalog: BASE_URL=http://localhost:8080"""
import os
import time

import requests

BASE_URL = os.getenv("BASE_URL", "http://localhost:8080")


def setup_module():
    deadline = time.time() + 90
    while time.time() < deadline:
        try:
            if requests.get(f"{BASE_URL}/health", timeout=3).status_code == 200:
                return
        except requests.RequestException:
            pass
        time.sleep(2)
    raise RuntimeError(f"Gateway pod {BASE_URL} nie odpowiada")


def test_gateway_health_checks_catalog():
    body = requests.get(f"{BASE_URL}/health", timeout=5).json()
    assert body["status"] == "ok" and body["catalog"] == "ok"


def test_products_come_from_catalog_service():
    body = requests.get(f"{BASE_URL}/api/products", timeout=5).json()
    assert body["source"] == "catalog"
    assert len(body["items"]) == 3


def test_index_shows_both_versions():
    body = requests.get(f"{BASE_URL}/", timeout=5).json()
    assert body["gateway"] and body["catalog"] != "niedostępny"
