"""Testy integracyjne na działającym kontenerze: BASE_URL=http://localhost:8000"""
import os
import time

import requests

BASE_URL = os.getenv("BASE_URL", "http://localhost:8000")


def setup_module():
    deadline = time.time() + 60
    while time.time() < deadline:
        try:
            if requests.get(f"{BASE_URL}/health", timeout=3).status_code == 200:
                return
        except requests.RequestException:
            pass
        time.sleep(2)
    raise RuntimeError(f"Aplikacja pod {BASE_URL} nie odpowiada")


def test_health():
    body = requests.get(f"{BASE_URL}/health", timeout=5).json()
    assert body["status"] == "ok" and body["database"] == "ok"


def test_task_flow_persists_in_database():
    created = requests.post(f"{BASE_URL}/tasks", json={"title": "Test integracyjny"}, timeout=5)
    assert created.status_code == 201
    task_id = created.json()["id"]
    assert requests.patch(f"{BASE_URL}/tasks/{task_id}", json={"done": True}, timeout=5).json()["done"]
    titles = [t["title"] for t in requests.get(f"{BASE_URL}/tasks", timeout=5).json()]
    assert "Test integracyjny" in titles
