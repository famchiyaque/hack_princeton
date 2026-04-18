# Hackathon Template

Stack-agnostic project template. All the wiring is done — just pick your tech and go.

## Structure

Layout is at the **repository root** (this repo is `hack_princeton`, not a subfolder named `template`):

```
.
├── frontend/          # Your frontend code goes here
├── backend/           # Your backend code goes here
│   ├── starter-express.js   # Node/Express starter (copy to index.js)
│   └── starter-fastapi.py   # Python/FastAPI starter (copy to main.py)
├── shared/
│   ├── api-contract.json    # Single source of truth for API shape
│   ├── api-client.js        # JS fetch wrapper (works with any framework)
│   └── api-client.py        # Python requests wrapper
├── scripts/
│   ├── setup.sh             # One-time setup (installs deps, creates .env)
│   └── dev.sh               # Runs frontend + backend concurrently
├── .env.example             # Environment template
└── .gitignore
```

If you ran `git clone … hacktemplate` inside this repo and only see `hacktemplate/.git`, that folder is not part of the app layout. Remove it with `rm -rf hacktemplate` and work from the paths above.

## Quick Start

```bash
# 1. Setup
chmod +x scripts/*.sh
./scripts/setup.sh

# 2. Pick your backend — copy a starter
cp backend/starter-fastapi.py backend/main.py
# OR
cp backend/starter-express.js backend/index.js

# 3. Edit scripts/dev.sh with your start commands

# 4. Run
./scripts/dev.sh
```

## How It Works

- **`shared/api-contract.json`** — Define your endpoints here. Both frontend and backend reference this so they stay in sync. Rename "items" to whatever your domain model is.
- **`shared/api-client.js`** — Drop-in fetch wrapper. Import from your frontend: `import api from '../shared/api-client'`
- **`.env`** — All config in one place. Both frontend and backend read from it.
- **Starters** — Pre-wired backend scaffolds with CORS, JSON parsing, health check, and CRUD. Delete the one you don't use.

## Common Stack Combos

| Frontend | Backend | Frontend CMD | Backend CMD |
|----------|---------|-------------|-------------|
| Next.js | FastAPI | `cd frontend && npm run dev` | `cd backend && uvicorn main:app --reload --port 8000` |
| Vite+React | Express | `cd frontend && npm run dev` | `cd backend && node index.js` |
| Svelte | Flask | `cd frontend && npm run dev` | `cd backend && flask run -p 8000` |

## API Client Usage

### JavaScript (any frontend)
```js
import api from '../shared/api-client';

const { items } = await api.get('/items');
const newItem = await api.post('/items', { name: 'test' });
```

### Python
```python
from shared.api_client import api

items = api.get('/items')
new_item = api.post('/items', json={'name': 'test'})
```
