"""Pruebas de la API con el upstream de Banxico simulado (sin token real)."""
import httpx
import pytest
import respx
from fastapi.testclient import TestClient

from app.config import get_settings

BASE = "https://www.banxico.org.mx/SieAPIRest/service/v1"

FAKE_OPORTUNO = {
    "bmx": {
        "series": [
            {
                "idSerie": "SF43718",
                "titulo": "Tipo de cambio Pesos por dólar E.U.A. FIX",
                "datos": [{"fecha": "01/09/2026", "dato": "18.5432"}],
            }
        ]
    }
}


@pytest.fixture
def client(monkeypatch):
    # Token ficticio de 64 caracteres para satisfacer la validación de config.
    monkeypatch.setenv("BANXICO_TOKEN", "a" * 64)
    get_settings.cache_clear()
    from app.main import app

    with TestClient(app) as c:
        yield c
    get_settings.cache_clear()


def test_healthz_no_llama_banxico(client):
    resp = client.get("/healthz")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


@respx.mock
def test_tipo_cambio_ok(client):
    respx.get(f"{BASE}/series/SF43718/datos/oportuno").mock(
        return_value=httpx.Response(200, json=FAKE_OPORTUNO)
    )
    resp = client.get("/tipo-cambio")
    assert resp.status_code == 200
    serie = resp.json()["series"][0]
    assert serie["id_serie"] == "SF43718"
    assert serie["observaciones"][0]["dato"] == 18.5432


@respx.mock
def test_serie_no_encontrada_devuelve_404(client):
    respx.get(f"{BASE}/series/XXX/datos/oportuno").mock(
        return_value=httpx.Response(404, text="not found")
    )
    resp = client.get("/series/XXX")
    assert resp.status_code == 404


@respx.mock
def test_error_de_banxico_no_filtra_token(client):
    respx.get(f"{BASE}/series/SF43718/datos/oportuno").mock(
        return_value=httpx.Response(403, text="forbidden")
    )
    resp = client.get("/series/SF43718")
    assert resp.status_code == 502
    # El token jamás debe aparecer en la respuesta.
    assert "a" * 64 not in resp.text


def test_sin_series_devuelve_400(client):
    resp = client.get("/series/ ")
    assert resp.status_code == 400
