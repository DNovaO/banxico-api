"""Cache TTL en memoria.

Banxico recomienda explícitamente cachear resultados para evitar que el token
sea bloqueado por exceso de consultas. Esta implementación es suficiente para un
solo proceso; en producción con varias réplicas se usaría ElastiCache/Redis
(ver README, sección de trade-offs).
"""
from __future__ import annotations

import asyncio
import time
from typing import Any


class TTLCache:
    def __init__(self, ttl_seconds: int) -> None:
        self._ttl = ttl_seconds
        self._store: dict[str, tuple[float, Any]] = {}
        self._lock = asyncio.Lock()

    async def get(self, key: str) -> Any | None:
        async with self._lock:
            item = self._store.get(key)
            if item is None:
                return None
            expires_at, value = item
            if time.monotonic() > expires_at:
                self._store.pop(key, None)
                return None
            return value

    async def set(self, key: str, value: Any) -> None:
        async with self._lock:
            self._store[key] = (time.monotonic() + self._ttl, value)
