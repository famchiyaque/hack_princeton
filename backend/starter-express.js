/**
 * Express starter — copy this to `backend/index.js` if using Node.
 * Has CORS, JSON parsing, health check, and CRUD scaffold ready.
 *
 * npm init -y && npm i express cors dotenv
 */

const express = require('express');
const cors = require('cors');
require('dotenv').config({ path: '../.env' });

const app = express();
const PORT = process.env.BACKEND_PORT || 8000;

// Middleware
app.use(cors({ origin: process.env.CORS_ORIGINS || 'http://localhost:3000' }));
app.use(express.json());

// ── Health ──
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok' });
});

// ── CRUD scaffold (replace with your models) ──
let items = [];
let nextId = 1;

app.get('/api/items', (req, res) => {
  const { search, limit = 50, offset = 0 } = req.query;
  let result = items;
  if (search) result = result.filter(i => i.name.includes(search));
  res.json({
    items: result.slice(Number(offset), Number(offset) + Number(limit)),
    total: result.length,
  });
});

app.get('/api/items/:id', (req, res) => {
  const item = items.find(i => i.id === req.params.id);
  if (!item) return res.status(404).json({ error: 'Not found' });
  res.json(item);
});

app.post('/api/items', (req, res) => {
  const item = {
    id: String(nextId++),
    name: req.body.name,
    createdAt: new Date().toISOString(),
  };
  items.push(item);
  res.status(201).json(item);
});

app.put('/api/items/:id', (req, res) => {
  const item = items.find(i => i.id === req.params.id);
  if (!item) return res.status(404).json({ error: 'Not found' });
  item.name = req.body.name;
  item.updatedAt = new Date().toISOString();
  res.json(item);
});

app.delete('/api/items/:id', (req, res) => {
  items = items.filter(i => i.id !== req.params.id);
  res.json({ success: true });
});

app.listen(PORT, () => {
  console.log(`Backend running at http://localhost:${PORT}`);
});
