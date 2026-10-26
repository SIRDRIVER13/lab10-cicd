import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import create_app  # noqa: E402


def client():
    return create_app().test_client()


def test_health():
    assert client().get("/health").get_json()["status"] == "ok"


def test_products_list():
    body = client().get("/products").get_json()
    assert body["service"] == "catalog"
    assert len(body["items"]) == 3


def test_single_product_and_404():
    assert client().get("/products/2").get_json()["name"] == "Kontener 40'"
    assert client().get("/products/99").status_code == 404


def test_broken_version(monkeypatch):
    monkeypatch.setenv("APP_BROKEN", "1")
    assert client().get("/health").status_code == 503
