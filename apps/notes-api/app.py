"""Notes API: a tiny FastAPI backend for the notes-app Helm chart.

Everything it needs comes from environment variables, which the chart fills
from a ConfigMap (non-secret settings) and a Secret (database password).
"""

import os
import socket
import time
from contextlib import asynccontextmanager

import psycopg
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

APP_VERSION = os.getenv("APP_VERSION", "dev")
APP_MESSAGE = os.getenv("APP_MESSAGE", "Hello from the Notes API")
MAX_NOTES = int(os.getenv("MAX_NOTES", "100"))


def conninfo() -> str:
    return psycopg.conninfo.make_conninfo(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "notes"),
        user=os.getenv("DB_USER", "notes"),
        password=os.getenv("DB_PASSWORD", ""),
        connect_timeout=3,
    )


def init_db(retries: int = 30) -> None:
    """Create the table, retrying while the database is still starting up."""
    for attempt in range(1, retries + 1):
        try:
            with psycopg.connect(conninfo()) as conn:
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS notes (
                        id SERIAL PRIMARY KEY,
                        text TEXT NOT NULL,
                        author TEXT NOT NULL,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
                    )
                    """
                )
            return
        except psycopg.OperationalError as exc:
            print(f"Database not ready (attempt {attempt}/{retries}): {exc}", flush=True)
            time.sleep(2)
    raise RuntimeError("Could not connect to the database")


@asynccontextmanager
async def lifespan(_: FastAPI):
    init_db()
    yield


app = FastAPI(title="Notes API", version=APP_VERSION, lifespan=lifespan)


class NoteIn(BaseModel):
    text: str = Field(min_length=1, max_length=500)


@app.get("/healthz")
def healthz():
    """Liveness: the process is running."""
    return {"status": "ok"}


@app.get("/readyz")
def readyz():
    """Readiness: only receive traffic when the database answers."""
    try:
        with psycopg.connect(conninfo()) as conn:
            conn.execute("SELECT 1")
    except psycopg.Error as exc:
        raise HTTPException(status_code=503, detail=f"database unavailable: {exc}")
    return {"status": "ready"}


@app.get("/api/info")
def info():
    """Shows which pod answered: refresh to see the Service load-balance."""
    try:
        with psycopg.connect(conninfo()) as conn:
            count = conn.execute("SELECT count(*) FROM notes").fetchone()[0]
        database = "connected"
    except psycopg.Error:
        count, database = None, "unavailable"
    return {
        "pod": socket.gethostname(),
        "version": APP_VERSION,
        "message": APP_MESSAGE,
        "database": database,
        "notes": count,
        "maxNotes": MAX_NOTES,
    }


@app.get("/api/notes")
def list_notes():
    with psycopg.connect(conninfo()) as conn:
        rows = conn.execute(
            "SELECT id, text, author, created_at FROM notes ORDER BY id DESC"
        ).fetchall()
    return [
        {"id": r[0], "text": r[1], "author": r[2], "createdAt": r[3].isoformat()}
        for r in rows
    ]


@app.post("/api/notes", status_code=201)
def add_note(note: NoteIn):
    with psycopg.connect(conninfo()) as conn:
        count = conn.execute("SELECT count(*) FROM notes").fetchone()[0]
        if count >= MAX_NOTES:
            raise HTTPException(status_code=409, detail=f"maximum of {MAX_NOTES} notes reached")
        row = conn.execute(
            "INSERT INTO notes (text, author) VALUES (%s, %s) RETURNING id",
            (note.text, socket.gethostname()),
        ).fetchone()
    return {"id": row[0]}


@app.delete("/api/notes/{note_id}", status_code=204)
def delete_note(note_id: int):
    with psycopg.connect(conninfo()) as conn:
        conn.execute("DELETE FROM notes WHERE id = %s", (note_id,))
