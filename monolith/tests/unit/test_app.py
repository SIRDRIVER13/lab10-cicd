import pytest

from taskapp.app import create_app


@pytest.fixture()
def client(tmp_path):
    return create_app(str(tmp_path / "test.db")).test_client()


def test_index_returns_app_info(client):
    body = client.get("/").get_json()
    assert body["app"] == "Task API (monolit)"
    assert "version" in body


def test_health_ok(client):
    assert client.get("/health").get_json()["status"] == "ok"


def test_health_reports_broken_version(client, monkeypatch):
    monkeypatch.setenv("APP_BROKEN", "1")
    assert client.get("/health").status_code == 503


def test_create_and_complete_task(client):
    created = client.post("/tasks", json={"title": "Napisać sprawozdanie"})
    assert created.status_code == 201
    task_id = created.get_json()["id"]
    assert client.patch(f"/tasks/{task_id}", json={"done": True}).get_json()["done"] is True
    assert client.get("/tasks").get_json()[0]["done"] is True


def test_validation(client):
    assert client.post("/tasks", json={}).status_code == 400
    assert client.post("/tasks", json={"title": "x" * 201}).status_code == 400
    assert client.patch("/tasks/999", json={"done": True}).status_code == 404
