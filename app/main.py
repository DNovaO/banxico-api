"""API que expone datos económicos de Banxico (SIE).

Endpoints:
  GET /healthz                         -> liveness, NO consume la API de Banxico
  GET /series/{ids}                    -> último dato (oportuno) de una o varias series
  GET /series/{ids}/rango?inicio&fin   -> datos de un rango de fechas
  GET /tipo-cambio                     -> atajo del USD/MXN FIX (serie SF43718)

`ids` admite varias series separadas por coma, p. ej. SF43718,SF61745
"""
from __future__ import annotations

import logging
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import JSONResponse

from .banxico import BanxicoClient, BanxicoError
from .cache import TTLCache
from .config import get_settings
from .schemas import HealthResponse, SeriesResponse

logging.basicConfig(level=get_settings().log_level)
logger = logging.getLogger("banxico-api")

# Serie del tipo de cambio USD/MXN FIX.
USD_FIX = "SF43718"


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    timeout = httpx.Timeout(settings.request_timeout_seconds)
    async with httpx.AsyncClient(timeout=timeout) as http_client:
        app.state.banxico = BanxicoClient(
            client=http_client,
            token=settings.banxico_token,
            base_url=settings.banxico_base_url,
        )
        app.state.cache = TTLCache(settings.cache_ttl_seconds)
        logger.info("Aplicación iniciada")
        yield
    logger.info("Aplicación detenida")


app = FastAPI(title="Banxico SIE API", version="1.0.0", lifespan=lifespan)


@app.exception_handler(BanxicoError)
async def banxico_error_handler(_, exc: BanxicoError) -> JSONResponse:
    # Log interno con detalle; respuesta al cliente sin filtrar internals.
    logger.warning("Error hablando con Banxico: %s", exc)
    return JSONResponse(status_code=exc.status_code, content={"detail": str(exc)})


@app.get("/healthz", response_model=HealthResponse)
async def healthz() -> HealthResponse:
    # Liveness simple: no llama a Banxico para no gastar cuota ni acoplar la
    # salud del contenedor a un servicio externo.
    return HealthResponse(status="ok")


def _split_ids(ids: str) -> list[str]:
    series = [s.strip() for s in ids.split(",") if s.strip()]
    if not series:
        raise HTTPException(status_code=400, detail="Debes indicar al menos una serie")
    if len(series) > 20:
        raise HTTPException(status_code=400, detail="Máximo 20 series por consulta")
    return series


@app.get("/series/{ids}", response_model=SeriesResponse)
async def series_oportuno(ids: str) -> SeriesResponse:
    series_ids = _split_ids(ids)
    cache: TTLCache = app.state.cache
    key = f"oportuno:{','.join(sorted(series_ids))}"

    cached = await cache.get(key)
    if cached is not None:
        return cached

    series = await app.state.banxico.get_oportuno(series_ids)
    result = SeriesResponse(series=series)
    await cache.set(key, result)
    return result


@app.get("/series/{ids}/rango", response_model=SeriesResponse)
async def series_rango(
    ids: str,
    inicio: str = Query(..., description="Fecha inicial yyyy-MM-dd"),
    fin: str = Query(..., description="Fecha final yyyy-MM-dd"),
) -> SeriesResponse:
    series_ids = _split_ids(ids)
    series = await app.state.banxico.get_rango(series_ids, inicio, fin)
    return SeriesResponse(series=series)


@app.get("/tipo-cambio", response_model=SeriesResponse)
async def tipo_cambio() -> SeriesResponse:
    cache: TTLCache = app.state.cache
    key = f"oportuno:{USD_FIX}"
    cached = await cache.get(key)
    if cached is not None:
        return cached

    series = await app.state.banxico.get_oportuno([USD_FIX])
    result = SeriesResponse(series=series)
    await cache.set(key, result)
    return result
