"""Modelos de respuesta normalizados que expone nuestra API."""
from pydantic import BaseModel


class Observacion(BaseModel):
    fecha: str
    dato: float | None  # None cuando Banxico devuelve "N/E" (no disponible)


class Serie(BaseModel):
    id_serie: str
    titulo: str
    observaciones: list[Observacion]


class SeriesResponse(BaseModel):
    series: list[Serie]


class HealthResponse(BaseModel):
    status: str
