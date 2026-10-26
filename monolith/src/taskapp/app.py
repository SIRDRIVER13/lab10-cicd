"""Task API - aplikacja monolityczna (Flask + SQLite)."""
import os
import socket
import sqlite3
from importlib.metadata import PackageNotFoundError, version

from flask import Flask, g, jsonify, request

try:
    PACKAGE_VERSION = version("taskapp")
except PackageNotFoundError:  # uruchomienie z kodu źródłowego
    PACKAGE_VERSION = "0.0.0-dev"


def create_app(db_path=None):
    app = Flask(__name__)
    app.json.ensure_ascii = False
    app.json.compact = False
    app.config["DB_PATH"] = db_path or os.getenv("DATABASE_PATH", "tasks.db")

    def db():
        if "db" not in g:
            g.db = sqlite3.connect(app.config["DB_PATH"])
            g.db.row_factory = sqlite3.Row
        return g.db

    @app.teardown_appcontext
    def close_db(_exc):
        conn = g.pop("db", None)
        if conn is not None:
            conn.close()

    with app.app_context():
        db().execute(
            "CREATE TABLE IF NOT EXISTS tasks ("
            "id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0)"
        )
        db().commit()

    @app.get("/")
    def index():
        return jsonify(
            app="Task API (monolit)",
            version=os.getenv("APP_VERSION", PACKAGE_VERSION),
            environment=os.getenv("APP_ENV", "local"),
            host=socket.gethostname(),
        )

    @app.get("/health")
    def health():
        db().execute("SELECT 1")
        current = os.getenv("APP_VERSION", PACKAGE_VERSION)
        if os.getenv("APP_BROKEN"):
            return jsonify(status="error", reason="APP_BROKEN", version=current), 503
        return jsonify(status="ok", database="ok", version=current)

    @app.get("/tasks")
    def list_tasks():
        rows = db().execute("SELECT id, title, done FROM tasks ORDER BY id").fetchall()
        return jsonify([{"id": r["id"], "title": r["title"], "done": bool(r["done"])} for r in rows])

    @app.post("/tasks")
    def create_task():
        data = request.get_json(silent=True) or {}
        title = str(data.get("title") or "").strip()
        if not title:
            return jsonify(error="Pole 'title' jest wymagane"), 400
        if len(title) > 200:
            return jsonify(error="Tytuł może mieć najwyżej 200 znaków"), 400
        cur = db().execute("INSERT INTO tasks (title) VALUES (?)", (title,))
        db().commit()
        return jsonify(id=cur.lastrowid, title=title, done=False), 201

    @app.patch("/tasks/<int:task_id>")
    def mark_done(task_id):
        data = request.get_json(silent=True) or {}
        done = bool(data.get("done", True))
        cur = db().execute("UPDATE tasks SET done = ? WHERE id = ?", (int(done), task_id))
        db().commit()
        if cur.rowcount == 0:
            return jsonify(error="Nie znaleziono zadania"), 404
        return jsonify(id=task_id, done=done)

    return app
