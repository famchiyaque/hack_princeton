# Teammate Guide -- Hackathon Template

Welcome to the project! This guide will get you productive in under 5 minutes regardless of what part of the stack you're working on or what technologies we end up choosing. Read the section that applies to your role, but skim the rest so you understand how everything connects.

---

## Table of Contents

1. [First-Time Setup (Everyone)](#1-first-time-setup-everyone)
2. [Project Structure at a Glance](#2-project-structure-at-a-glance)
3. [How the Pieces Connect](#3-how-the-pieces-connect)
4. [For Frontend Developers](#4-for-frontend-developers)
5. [For Backend Developers](#5-for-backend-developers)
6. [For Full-Stack / Flex Developers](#6-for-full-stack--flex-developers)
7. [The API Contract (Everyone Should Read)](#7-the-api-contract-everyone-should-read)
8. [Environment Variables](#8-environment-variables)
9. [Running the Project](#9-running-the-project)
10. [Adding a New Feature End-to-End](#10-adding-a-new-feature-end-to-end)
11. [Common Recipes](#11-common-recipes)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. First-Time Setup (Everyone)

```bash
# Clone the repo and enter it (folder name matches your clone, e.g. hack_princeton)
cd hack_princeton

# Make scripts executable (one time only)
chmod +x scripts/*.sh

# Run setup -- this creates your .env and installs dependencies
./scripts/setup.sh
```

That's it. The setup script auto-detects whether the frontend/backend use Node, Python, or Go and installs the right dependencies. If nothing is initialized yet, it'll tell you -- that's fine.

After setup, open `.env` and fill in any API keys the team is using (OpenAI, Anthropic, etc). Never commit this file -- it's already in `.gitignore`.

---

## 2. Project Structure at a Glance

```
hack_princeton/                # repository root (your clone directory name may differ)
├── frontend/                  # All frontend code lives here
├── backend/                   # All backend code lives here
│   ├── starter-express.js     # Ready-to-go Node/Express server
│   └── starter-fastapi.py     # Ready-to-go Python/FastAPI server
├── shared/                    # Code & contracts shared across both sides
│   ├── api-contract.json      # THE source of truth for all API endpoints
│   ├── api-client.js          # Pre-built JS client for calling the API
│   └── api-client.py          # Pre-built Python client for calling the API
├── scripts/
│   ├── setup.sh               # One-time setup
│   └── dev.sh                 # Starts frontend + backend together
├── .env.example               # Template for environment variables
├── .gitignore
└── README.md
```

**Key principle:** Frontend and backend are completely separated into their own folders. The `shared/` folder is the bridge between them -- it holds the API contract that both sides agree on, plus ready-made client libraries so you never have to write raw `fetch()` or `requests` calls.

---

## 3. How the Pieces Connect

```
┌─────────────┐       HTTP        ┌─────────────┐
│  Frontend   │ ──────────────>   │   Backend   │
│  (any JS    │   uses shared/    │  (any lang) │
│   framework)│   api-client.js   │             │
└─────────────┘                   └──────┬──────┘
       │                                  │
       │         shared/                  │
       └──── api-contract.json ───────────┘
              (both sides reference
               the same endpoint
               definitions)
```

- The **frontend** imports `shared/api-client.js` to make API calls. It doesn't need to know the backend's language or framework.
- The **backend** implements the endpoints defined in `shared/api-contract.json`. It doesn't need to know what frontend framework is being used.
- The **API contract** is the handshake. If you change an endpoint, update the contract first, then both sides update to match.

---

## 4. For Frontend Developers

### Getting started

1. Initialize your framework inside the `frontend/` folder:

   ```bash
   # Pick ONE of these (or whatever framework the team decides on):
   cd frontend

   # Next.js
   npx create-next-app@latest .

   # Vite + React
   npm create vite@latest . -- --template react

   # Vite + Vue
   npm create vite@latest . -- --template vue

   # Svelte
   npm create svelte@latest .
   ```

2. That's it -- start building pages and components.

### Calling the backend API

You never need to write raw `fetch()`. Import the pre-built client:

```js
import api from "../shared/api-client";

// GET request
const { items } = await api.get("/items");

// GET with query params
const results = await api.get("/items", { search: "foo", limit: 10 });

// POST request
const newItem = await api.post("/items", { name: "My Thing" });

// PUT request
const updated = await api.put("/items/123", { name: "New Name" });

// DELETE request
await api.delete("/items/123");
```

### Authentication

If the app has login, call `api.setToken(jwt)` after the user logs in. Every subsequent request will automatically include the `Authorization: Bearer <token>` header:

```js
// After login
const { token } = await api.post("/auth/login", { email, password });
api.setToken(token);

// All future calls now authenticated
const profile = await api.get("/users/me");
```

### How it finds the backend URL

The API client automatically reads the correct env variable based on your framework:

| Framework | Env variable          | Example                     |
| --------- | --------------------- | --------------------------- |
| Next.js   | `NEXT_PUBLIC_API_URL` | `http://localhost:8000/api` |
| Vite      | `VITE_API_URL`        | `http://localhost:8000/api` |
| CRA       | `REACT_APP_API_URL`   | `http://localhost:8000/api` |
| (default) | --                    | `http://localhost:8000/api` |

You usually don't need to set these -- the default (`localhost:8000/api`) works for local dev.

### What to reference

Open `shared/api-contract.json` to see every available endpoint, what parameters they accept, and what shape the response will be. This is your source of truth -- if an endpoint isn't in the contract, don't call it. If you need a new one, add it to the contract and tell the backend dev.

---

## 5. For Backend Developers

### Getting started

We have two starter servers ready to go. Pick the one that matches our stack:

**Python (FastAPI):**

```bash
cp backend/starter-fastapi.py backend/main.py
cd backend
pip install fastapi uvicorn python-dotenv
uvicorn main:app --reload --port 8000
```

**Node (Express):**

```bash
cp backend/starter-express.js backend/index.js
cd backend
npm init -y && npm install express cors dotenv
node index.js
```

Both starters come pre-configured with:

- CORS (so the frontend can call your API from a different port)
- JSON body parsing
- Health check endpoint (`GET /api/health`)
- Full CRUD scaffold for a generic "items" resource
- Environment variable loading from the root `.env`

### What you get out of the box

The starter gives you these endpoints already working:

| Method   | Path             | What it does                                            |
| -------- | ---------------- | ------------------------------------------------------- |
| `GET`    | `/api/health`    | Returns `{ status: "ok" }`                              |
| `GET`    | `/api/items`     | List items (supports `?search=`, `?limit=`, `?offset=`) |
| `GET`    | `/api/items/:id` | Get one item by ID                                      |
| `POST`   | `/api/items`     | Create an item (`{ name }`)                             |
| `PUT`    | `/api/items/:id` | Update an item                                          |
| `DELETE` | `/api/items/:id` | Delete an item                                          |

### Adapting to your actual project

1. Rename "items" to whatever your domain model is (e.g., "posts", "tasks", "matches")
2. Update the fields beyond just `name` to match your data model
3. Swap the in-memory storage for a real database when ready
4. Update `shared/api-contract.json` whenever you add or change an endpoint

### Adding a database

The `.env` file has placeholders for common databases:

```
DATABASE_URL=sqlite:///./app.db                          # simplest
DATABASE_URL=postgresql://user:pass@localhost:5432/hackathon  # postgres
MONGODB_URI=mongodb://localhost:27017/hackathon               # mongo
```

Pick one, uncomment it in `.env`, and wire it into your backend. The starters use in-memory storage by default so you can get moving immediately and add persistence later.

### CORS is already handled

Both starters read `CORS_ORIGINS` from `.env` (defaults to `http://localhost:3000`). If the frontend runs on a different port, update this value. You should never see CORS errors during local dev.

---

## 6. For Full-Stack / Flex Developers

You'll be working across both folders. Here's the workflow:

1. **Start both servers** with one command: `./scripts/dev.sh`
2. **Define new endpoints** in `shared/api-contract.json` first
3. **Implement the backend** route in `backend/`
4. **Call it from the frontend** using `shared/api-client.js`

You have the best view of how things connect, so you're the go-to person for keeping the API contract in sync.

---

## 7. The API Contract (Everyone Should Read)

`shared/api-contract.json` is the single source of truth for how frontend and backend communicate. It looks like this:

```json
{
  "endpoints": {
    "getItems": {
      "method": "GET",
      "path": "/items",
      "query": ["limit", "offset", "search"],
      "response": {
        "items": [],
        "total": 0
      }
    },
    "createItem": {
      "method": "POST",
      "path": "/items",
      "body": {
        "name": ""
      },
      "response": {
        "id": "",
        "name": "",
        "createdAt": ""
      }
    }
  }
}
```

### Rules for the contract

- **Before building a new endpoint:** Add it to the contract first. This way the frontend dev can start building the UI in parallel using the expected response shape, even before the backend is done.
- **Changing an endpoint?** Update the contract, then update both sides. Don't surprise the other side with a shape change.
- **The `response` field** shows the shape of what the API returns. Frontend devs: use this to know what fields to expect. Backend devs: make sure your responses match this shape.
- **The `body` field** shows what the request body looks like for POST/PUT. Frontend devs: send exactly these fields. Backend devs: validate for these fields.

---

## 8. Environment Variables

All configuration lives in `.env` at the project root. Both frontend and backend read from here.

```bash
# Ports
FRONTEND_PORT=3000       # What port the frontend dev server runs on
BACKEND_PORT=8000        # What port the backend runs on

# Database (uncomment whichever one you're using)
# DATABASE_URL=sqlite:///./app.db
# DATABASE_URL=postgresql://user:pass@localhost:5432/hackathon
# MONGODB_URI=mongodb://localhost:27017/hackathon

# API keys (fill in what you need)
SECRET_KEY=change-me
# OPENAI_API_KEY=
# ANTHROPIC_API_KEY=
# GOOGLE_API_KEY=
```

**Important:**

- `.env` is gitignored and never committed
- `.env.example` is committed and shows what variables exist
- If you add a new env variable, add it to `.env.example` too so teammates know about it

---

## 9. Running the Project

### Option A: One command (recommended)

```bash
./scripts/dev.sh
```

This starts both frontend and backend in the same terminal. Before using it, open `scripts/dev.sh` and uncomment the right start commands for your stack. For example:

```bash
# For Next.js + FastAPI:
FRONTEND_CMD="cd frontend && npm run dev"
BACKEND_CMD="cd backend && uvicorn main:app --reload --port ${BACKEND_PORT:-8000}"
```

Hit `Ctrl+C` to stop both servers.

### Option B: Two terminals

```bash
# Terminal 1 -- backend
cd backend
uvicorn main:app --reload --port 8000   # or: node index.js

# Terminal 2 -- frontend
cd frontend
npm run dev
```

### Verifying everything works

Once both servers are running:

```bash
# Backend health check
curl http://localhost:8000/api/health
# Should return: {"status":"ok"}

# Create a test item
curl -X POST http://localhost:8000/api/items \
  -H "Content-Type: application/json" \
  -d '{"name":"test"}'

# List items
curl http://localhost:8000/api/items
```

---

## 10. Adding a New Feature End-to-End

Here's the workflow for adding, say, a "comments" feature:

### Step 1: Update the API contract

Add to `shared/api-contract.json`:

```json
"getComments": {
  "method": "GET",
  "path": "/items/:id/comments",
  "response": {
    "comments": [],
    "total": 0
  }
},
"addComment": {
  "method": "POST",
  "path": "/items/:id/comments",
  "body": { "text": "" },
  "response": { "id": "", "text": "", "createdAt": "" }
}
```

### Step 2: Backend implements the endpoints

Add routes in your backend that match those paths and return that response shape.

### Step 3: Frontend calls the endpoints

```js
import api from "../shared/api-client";

// Fetch comments
const { comments } = await api.get(`/items/${itemId}/comments`);

// Add a comment
const comment = await api.post(`/items/${itemId}/comments`, { text: "Great!" });
```

Both sides can work in parallel after Step 1. The frontend dev can build the UI using the expected response shape, and the backend dev can build the route. They'll just work when connected.

---

## 11. Common Recipes

### Adding auth (JWT)

**Backend** -- add login/register endpoints that return a token:

```
POST /api/auth/register  { email, password } -> { token, user }
POST /api/auth/login     { email, password } -> { token, user }
GET  /api/users/me       (requires token)   -> { user }
```

**Frontend** -- store the token and set it on the API client:

```js
const { token } = await api.post("/auth/login", { email, password });
localStorage.setItem("token", token);
api.setToken(token);
```

### Connecting a database

1. Pick a DB and uncomment the right line in `.env`
2. Install the driver:
   - Python + SQLite: built-in, nothing to install
   - Python + Postgres: `pip install psycopg2-binary sqlalchemy`
   - Python + MongoDB: `pip install pymongo`
   - Node + Postgres: `npm install pg` or `npm install prisma`
   - Node + MongoDB: `npm install mongoose`
3. Replace the in-memory arrays in your starter with real DB queries

### Adding a new env variable

1. Add it to `.env.example` with a comment explaining what it's for
2. Add it to your own `.env` with the real value
3. Tell your teammates to pull and re-run `./scripts/setup.sh` (it won't overwrite their existing `.env`)

---

## 12. Troubleshooting

### "CORS error" in the browser console

Your backend isn't allowing requests from your frontend's port. Check that `CORS_ORIGINS` in `.env` matches your frontend URL (default: `http://localhost:3000`).

### "Connection refused" when frontend calls API

The backend isn't running. Start it first, then check it's on the right port (`BACKEND_PORT` in `.env`, default 8000).

### Frontend can't find `shared/api-client.js`

Depending on your framework's import rules, you may need to adjust the relative path. Common fix:

```js
// If your component is in frontend/src/components/
import api from "../../../shared/api-client";
// Or set up a path alias in your framework config
```

### `setup.sh` says "No frontend/backend dependencies found"

That's normal if you haven't initialized a framework yet. Run it again after you've set up your frontend/backend with `npm init`, `pip install`, etc.

### Backend changes aren't showing up

Make sure you're running with hot-reload:

- FastAPI: `uvicorn main:app --reload`
- Express: use `nodemon index.js` instead of `node index.js` (`npm install -g nodemon`)

### Two people changed the API contract

Merge conflicts in `api-contract.json` are a sign of good communication breakdown. Sync up, decide on the endpoint shape together, and resolve the conflict. The contract is small enough that this should be quick.

## Stuff to polish

### Frontend

- [What's your weight, height, age, and sex] very transparent, needs work
- Modify moving icons on onboarding to non-moving icosn
- Add google icon for google oauth
