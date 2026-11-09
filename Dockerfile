# ---------- Etapa 1: build ----------
# Aquí se instalan las dependencias. Nada de esta etapa llega a la imagen final pero si el entorno virtual ya construido.

FROM python:3.12-slim@sha256:5e2bdb1b0d542d5039cffb8181c65930093949194a65c365dfb1b0fe13a4fa5b AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# requirements primero: la capa de dependencias se debe de poder reutilizar si el código cambia por eso siempre se copia.
COPY requirements.txt .
RUN pip install -r requirements.txt


# ---------- Etapa 2: runtime ----------
FROM python:3.12-slim@sha256:5e2bdb1b0d542d5039cffb8181c65930093949194a65c365dfb1b0fe13a4fa5b AS runtime
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# Usuario sin privilegios, con UID numérico fijo y sin shell de login
RUN groupadd --system --gid 10001 app \
 && useradd  --system --uid 10001 --gid app --no-create-home \
             --shell /usr/sbin/nologin app

COPY --from=builder /opt/venv /opt/venv

WORKDIR /srv
# Solo el código de la app: sin tests, sin .env, sin documentación
COPY --chown=app:app app ./app

USER 10001:10001
EXPOSE 8000

# Sin curl en la imagen slim: el health check usa la librería estándar de Python
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/healthz', timeout=2).status == 200 else 1)"]

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]