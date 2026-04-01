"""Load test — cenarios de carga com Locust.

Uso:
    locust                          # abre UI em http://localhost:8089
    locust --headless -u 50 -r 10   # 50 users, ramp-up 10/s, no UI

Host alvo (prioridade):
    1. LOCUST_HOST env var   (compose/.env)
    2. --host na CLI         (locust --host http://...)
    3. Default abaixo        (http://localhost:8000)

Docs: https://docs.locust.io
"""

import os

from locust import HttpUser, between, task


class AppUser(HttpUser):
    """Simula um usuario acessando o servico."""

    wait_time = between(0.5, 2)
    host = os.environ.get("LOCUST_HOST", "http://localhost:8000")

    @task(3)
    def health(self) -> None:
        """GET /health — endpoint de saude (peso 3)."""
        self.client.get("/health")

    @task(1)
    def root(self) -> None:
        """GET / — endpoint raiz."""
        self.client.get("/")
