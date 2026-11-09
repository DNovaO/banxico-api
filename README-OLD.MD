# Banxico SIE API

API en Python (FastAPI) que consume la API SIE del Banco de México y expone
datos económicos (tipo de cambio, tasas, etc.) mediante endpoints propios.

## Requisitos previos

Necesitas un **token de consulta de Banxico** (64 caracteres alfanuméricos).
Regístrate y genéralo aquí: https://www.banxico.org.mx/SieAPIRest/service/v1/token

El token es un secreto: **nunca** se escribe en el código ni se sube al repo.

## Puesta en marcha local

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

cp .env.example .env        # y pega tu token en BANXICO_TOKEN
uvicorn app.main:app --reload
```

Prueba rápida:

```bash
curl localhost:8000/healthz
curl localhost:8000/tipo-cambio
curl localhost:8000/series/SF43718,SF61745
curl "localhost:8000/series/SF43718/rango?inicio=2026-01-01&fin=2026-01-31"
```

## Endpoints

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/healthz` | Liveness. No llama a Banxico. |
| GET | `/series/{ids}` | Último dato de una o varias series (coma-separadas). |
| GET | `/series/{ids}/rango?inicio&fin` | Datos por rango de fechas (`yyyy-MM-dd`). |
| GET | `/tipo-cambio` | Atajo del USD/MXN FIX (serie `SF43718`). |

Series útiles: `SF43718` USD FIX · `SF61745` tasa objetivo · `SF60648` TIIE 28d ·
`SP68257` UDIS. Catálogo completo en la documentación del SIE.

## Tests

```bash
pip install -r requirements-dev.txt
pytest
```

Las pruebas simulan a Banxico (no requieren token real) y cubren, entre otras
cosas, que **el token nunca aparezca en las respuestas de error**.

## Notas de seguridad (decisiones tomadas)

- **Gestión del secreto**: el token se lee de la variable de entorno
  `BANXICO_TOKEN` vía `pydantic-settings`. No hay valor por defecto: si falta,
  la app **no arranca** y falla con un error claro. `.env` está en `.gitignore`.
- **No fuga de secretos**: el token viaja solo en el header `Bmx-Token`. Los
  errores de Banxico se traducen a mensajes genéricos; nunca se devuelve ni se
  loguea el token ni el cuerpo crudo del upstream.
- **Timeouts** en todas las llamadas salientes para no colgar conexiones.
- **Cache TTL**: Banxico recomienda cachear para no agotar/bloquear el token;
  hay un cache en memoria con TTL configurable.
- **Health check desacoplado**: `/healthz` no llama a Banxico, así la salud del
  contenedor no depende de un tercero (relevante para health checks de ALB).

## Trade-offs / qué haría distinto en producción

- El cache es en memoria y por proceso. Con varias réplicas usaría
  ElastiCache/Redis para compartirlo y respetar mejor los límites de Banxico.
- El token debe inyectarse desde **AWS Secrets Manager** o **SSM Parameter
  Store**, no desde un `.env` en el servidor.
- Añadiría rate limiting propio, métricas/trazas y reintentos con backoff.



##  Mi solución con implementaciones
## Cómo ejecutar la build de Docker (PowerShell)

En local uso solo tokens ficticios.

### Imagen base por digest

```powershell
docker pull python:3.12-slim
docker inspect --format='{{index .RepoDigests 0}}' python:3.12-slim
```

El digest se aplica en los dos `FROM` del `Dockerfile`.

**¿Por qué fijo la imagen base por digest?** Porque me permite un build reproducible y
sin cambios inesperados en la base.

**Riesgo:** no recibo parches automáticos y tengo que acordarme de actualizar el digest
de forma manual.

**Qué lo compensa:** el escaneo de Trivy en el pipeline y, en un entorno
real, una herramienta que proponga el cambio y se pueda dejar programada.

### Construir y comprobar

```powershell
docker build -t banxico-api .
docker run --rm banxico-api id
```

Se espera `uid=10001(app)`. Si dice `uid=0`, hay que revisar el `Dockerfile`.

```powershell
$tok = 'a' * 64
docker run -d --rm --name banxico-test -p 8000:8000 -e "BANXICO_TOKEN=$tok" banxico-api
curl.exe localhost:8000/healthz
docker stop banxico-test
```

`/healthz` no llama a Banxico, así que no necesita un token real. La aplicación tarda
unos segundos en responder y Docker marca `(healthy).

### Prueba del token inválido

Si al cargar el secreto en Secrets Manager llega con un espacio o un salto de línea, el
token válido tendría longitud incorrecta, fallaría la validación y quedaría escrito en
CloudWatch. Lo probé con un valor ficticio:

```powershell
docker run --rm -e BANXICO_TOKEN=tokenfalso123 banxico-api
```

Antes, el error incluía el valor: `[type=string_too_short, input_value='tokenfalso123', ...]`.
Lo corregí con `hide_input_in_errors=True` en `config.py`, y tras reconstruir la imagen
queda `[type=string_too_short]`, sin el valor.

Para hacer más robusta la implementación se podría recortar los espacios del token y
usar `SecretStr`, pero lo dejo a nivel de análisis para mantener el código fuente.

### Historial de capas

```powershell
docker history banxico-api --no-trunc
```

No aparece ningún token ni `.env` en las capas.


```
