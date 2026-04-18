"""
FastAPI starter — copy this to `backend/main.py` if using Python.
Has CORS, health check, and CRUD scaffold ready.

pip install fastapi uvicorn python-dotenv
Run: uvicorn main:app --reload --port 8000
"""

from datetime import datetime, timezone
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
import os

load_dotenv("../.env")

app = FastAPI(title="Hackathon API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[os.getenv("CORS_ORIGINS", "http://localhost:3000")],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Health ──
@app.get("/api/health")
def health():
    return {"status": "ok"}


# ── CRUD scaffold (replace with your models) ──
class ItemCreate(BaseModel):
    name: str

class ItemResponse(BaseModel):
    id: str
    name: str
    createdAt: str
    updatedAt: str | None = None

items: dict[str, dict] = {}
next_id = 1


@app.get("/api/items")
def list_items(search: str = "", limit: int = 50, offset: int = 0):
    result = list(items.values())
    if search:
        result = [i for i in result if search.lower() in i["name"].lower()]
    return {"items": result[offset : offset + limit], "total": len(result)}


@app.get("/api/items/{item_id}")
def get_item(item_id: str):
    if item_id not in items:
        raise HTTPException(404, "Not found")
    return items[item_id]


@app.post("/api/items", status_code=201)
def create_item(body: ItemCreate):
    global next_id
    item = {
        "id": str(next_id),
        "name": body.name,
        "createdAt": datetime.now(timezone.utc).isoformat(),
    }
    items[str(next_id)] = item
    next_id += 1
    return item


@app.put("/api/items/{item_id}")
def update_item(item_id: str, body: ItemCreate):
    if item_id not in items:
        raise HTTPException(404, "Not found")
    items[item_id]["name"] = body.name
    items[item_id]["updatedAt"] = datetime.now(timezone.utc).isoformat()
    return items[item_id]


@app.delete("/api/items/{item_id}")
def delete_item(item_id: str):
    items.pop(item_id, None)
    return {"success": True}
