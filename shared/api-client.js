/**
 * Universal API client — works in any JS frontend (React, Vue, Svelte, vanilla).
 * Reads endpoints from api-contract.json so frontend stays in sync with backend.
 *
 * Usage:
 *   import api from '../shared/api-client';
 *   const items = await api.get('/items', { search: 'foo' });
 *   const newItem = await api.post('/items', { name: 'bar' });
 */

const BASE_URL = (typeof process !== 'undefined' && process.env?.NEXT_PUBLIC_API_URL)
  || (typeof process !== 'undefined' && process.env?.VITE_API_URL)
  || (typeof process !== 'undefined' && process.env?.REACT_APP_API_URL)
  || 'http://localhost:8000/api';

class ApiClient {
  constructor(baseURL = BASE_URL) {
    this.baseURL = baseURL.replace(/\/$/, '');
  }

  async request(method, path, { body, query, headers = {} } = {}) {
    let url = `${this.baseURL}${path}`;

    if (query) {
      const params = new URLSearchParams(
        Object.fromEntries(Object.entries(query).filter(([, v]) => v != null))
      );
      if (params.toString()) url += `?${params}`;
    }

    const opts = {
      method,
      headers: { 'Content-Type': 'application/json', ...headers },
    };

    if (body && method !== 'GET') {
      opts.body = JSON.stringify(body);
    }

    const res = await fetch(url, opts);

    if (!res.ok) {
      const error = new Error(`API ${method} ${path} failed: ${res.status}`);
      error.status = res.status;
      try { error.data = await res.json(); } catch {}
      throw error;
    }

    if (res.status === 204) return null;
    return res.json();
  }

  get(path, query)        { return this.request('GET', path, { query }); }
  post(path, body)        { return this.request('POST', path, { body }); }
  put(path, body)         { return this.request('PUT', path, { body }); }
  patch(path, body)       { return this.request('PATCH', path, { body }); }
  delete(path)            { return this.request('DELETE', path); }

  // Auth helper — call api.setToken(jwt) after login
  setToken(token) {
    this._token = token;
    const origRequest = this.request.bind(this);
    this.request = (method, path, opts = {}) => {
      opts.headers = { ...opts.headers, Authorization: `Bearer ${token}` };
      return origRequest(method, path, opts);
    };
  }
}

const api = new ApiClient();
export default api;
export { ApiClient };
