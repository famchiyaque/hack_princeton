#!/usr/bin/env bash
# ── One-time project setup ──
# Run this after cloning: ./scripts/setup.sh

set -e

echo "=== Project Setup ==="

# 1. Create .env from example
if [ ! -f .env ]; then
  cp .env.example .env
  echo "[ok] Created .env from .env.example — edit it with your keys"
else
  echo "[skip] .env already exists"
fi

# 2. Frontend dependencies
if [ -f frontend/package.json ]; then
  echo "[installing] Frontend dependencies..."
  cd frontend && npm install && cd ..
  echo "[ok] Frontend ready"
elif [ -f frontend/requirements.txt ]; then
  echo "[installing] Frontend dependencies (Python)..."
  cd frontend && pip install -r requirements.txt && cd ..
  echo "[ok] Frontend ready"
else
  echo "[skip] No frontend dependencies found yet"
fi

# 3. Backend dependencies
if [ -f backend/package.json ]; then
  echo "[installing] Backend dependencies..."
  cd backend && npm install && cd ..
  echo "[ok] Backend ready"
elif [ -f backend/requirements.txt ]; then
  echo "[installing] Backend dependencies..."
  cd backend && pip install -r requirements.txt && cd ..
  echo "[ok] Backend ready"
elif [ -f backend/go.mod ]; then
  echo "[installing] Backend dependencies..."
  cd backend && go mod download && cd ..
  echo "[ok] Backend ready"
else
  echo "[skip] No backend dependencies found yet"
fi

echo ""
echo "=== Done! ==="
echo "Next steps:"
echo "  1. Edit .env with your API keys"
echo "  2. Update scripts/dev.sh with your start commands"
echo "  3. Run: ./scripts/dev.sh"
