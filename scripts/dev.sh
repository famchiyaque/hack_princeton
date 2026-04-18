#!/usr/bin/env bash
# ── Run frontend + backend concurrently ──
# Adapt the commands below once you pick your stack.

set -e

# Load env
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

echo "=== Starting dev servers ==="
echo "Frontend: http://localhost:${FRONTEND_PORT:-3000}"
echo "Backend:  http://localhost:${BACKEND_PORT:-8000}"
echo ""

# ── CONFIGURE THESE once you pick your stack ──
# Examples for common stacks:

# --- React/Next.js + Python/FastAPI ---
# FRONTEND_CMD="cd frontend && npm run dev"
# BACKEND_CMD="cd backend && uvicorn main:app --reload --port ${BACKEND_PORT:-8000}"

# --- React/Vite + Node/Express ---
# FRONTEND_CMD="cd frontend && npm run dev"
# BACKEND_CMD="cd backend && npm run dev"

# --- Svelte + Go ---
# FRONTEND_CMD="cd frontend && npm run dev"
# BACKEND_CMD="cd backend && go run ."

# --- Default: placeholder ---
FRONTEND_CMD="${FRONTEND_CMD:-echo '[frontend] Set FRONTEND_CMD in dev.sh or .env'}"
BACKEND_CMD="${BACKEND_CMD:-echo '[backend] Set BACKEND_CMD in dev.sh or .env'}"

# Run both in parallel, prefix output
$BACKEND_CMD &
BACKEND_PID=$!

$FRONTEND_CMD &
FRONTEND_PID=$!

# Cleanup on exit
trap "kill $BACKEND_PID $FRONTEND_PID 2>/dev/null" EXIT

wait
