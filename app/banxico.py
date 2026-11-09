"""Cliente para la API SIE de Banxico.

Notas de seguridad:
- El token viaja en el header `Bmx-Token` y nunca se incluye en logs ni en
  mensajes de error devueltos al cliente.
- Todas las peticiones tienen timeout para no dejar conexiones colgadas.
- Los errores de Banxico se traducen a errores propios sin filtrar internals.
"""
from __future__ import annotations

import httpx

from .schemas import Observacion, Serie


class BanxicoError(Exception):
    """Error controlado al hablar con Banxico. `status_code` es el que
    devolveremos nosotros al cliente final."""

    def __init__(self, message: str, status_code: int = 502) -> None:
        super().__init__(message)
        self.status_code = status_code


class BanxicoClient:
    def __init__(self, client: httpx.AsyncClient, token: str, base_url: str) -> None:
        self._client = client
        self._token = token
        self._base_url = base_url.rstrip("/")

    @property
    def _headers(self) -> dict[str, str]:
        return {"Bmx-Token": self._token, "Accept": "application/json"}

    async def get_oportuno(self, series_ids: list[str]) -> list[Serie]:
        """Último dato disponible de una o varias series."""
        path = f"/series/{','.join(series_ids)}/datos/oportuno"
        return self._parse(await self._get(path))

    async def get_rango(
        self, series_ids: list[str], inicio: str, fin: str
    ) -> list[Serie]:
        """Datos de un rango de fechas (formato yyyy-MM-dd)."""
        path = f"/series/{','.join(series_ids)}/datos/{inicio}/{fin}"
        return self._parse(await self._get(path))

    async def _get(self, path: str) -> dict:
        url = f"{self._base_url}{path}"
        try:
            resp = await self._client.get(url, headers=self._headers)
        except httpx.TimeoutException:
            raise BanxicoError("Tiempo de espera agotado consultando Banxico", 504)
        except httpx.RequestError:
            raise BanxicoError("Error de red consultando Banxico", 502)

        if resp.status_code in (401, 403):
            # Problema de autenticación: no revelamos el token en el error.
            raise BanxicoError("Banxico rechazó la autenticación", 502)
        if resp.status_code == 404:
            raise BanxicoError("Serie no encontrada", 404)
        if resp.status_code == 429:
            raise BanxicoError("Límite de consultas de Banxico excedido", 429)
        if resp.status_code >= 400:
            raise BanxicoError(f"Banxico respondió con estatus {resp.status_code}", 502)

        try:
            return resp.json()
        except ValueError:
            raise BanxicoError("Respuesta inválida de Banxico", 502)

    @staticmethod
    def _parse(payload: dict) -> list[Serie]:
        series_raw = (payload or {}).get("bmx", {}).get("series", [])
        series: list[Serie] = []
        for s in series_raw:
            observaciones = []
            for d in s.get("datos", []):
                valor = d.get("dato")
                # Banxico marca datos ausentes como "N/E".
                if valor in (None, "N/E", ""):
                    dato: float | None = None
                else:
                    try:
                        dato = float(str(valor).replace(",", ""))
                    except ValueError:
                        dato = None
                observaciones.append(Observacion(fecha=d.get("fecha", ""), dato=dato))
            series.append(
                Serie(
                    id_serie=s.get("idSerie", ""),
                    titulo=s.get("titulo", ""),
                    observaciones=observaciones,
                )
            )
        return series
