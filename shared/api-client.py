"""
Universal API client for Python backends that need to call other services,
or for scripts/notebooks that hit your own API.

Usage:
    from shared.api_client import api
    items = api.get('/items', params={'search': 'foo'})
    new_item = api.post('/items', json={'name': 'bar'})
"""

import os
import requests

BASE_URL = os.getenv("API_URL", "http://localhost:8000/api")


class ApiClient:
    def __init__(self, base_url=BASE_URL):
        self.base_url = base_url.rstrip("/")
        self.session = requests.Session()
        self.session.headers.update({"Content-Type": "application/json"})

    def request(self, method, path, **kwargs):
        url = f"{self.base_url}{path}"
        resp = self.session.request(method, url, **kwargs)
        resp.raise_for_status()
        if resp.status_code == 204:
            return None
        return resp.json()

    def get(self, path, params=None):
        return self.request("GET", path, params=params)

    def post(self, path, json=None):
        return self.request("POST", path, json=json)

    def put(self, path, json=None):
        return self.request("PUT", path, json=json)

    def patch(self, path, json=None):
        return self.request("PATCH", path, json=json)

    def delete(self, path):
        return self.request("DELETE", path)

    def set_token(self, token):
        self.session.headers["Authorization"] = f"Bearer {token}"


api = ApiClient()
