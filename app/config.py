"""Configuración de la aplicación.

Toda la configuración sensible (en particular el token de Banxico) se lee de
variables de entorno. El token NUNCA se define en el código ni se registra en logs.
En despliegue, inyéctalo desde AWS Secrets Manager o SSM Parameter Store.
"""
from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        hide_input_in_errors=True
    )

    # Secreto obligatorio. Si falta, la app falla al arrancar con un error claro.
    banxico_token: str = Field(min_length=64, max_length=64)

    banxico_base_url: str = "https://www.banxico.org.mx/SieAPIRest/service/v1"
    request_timeout_seconds: float = 10.0
    cache_ttl_seconds: int = 300
    log_level: str = "INFO"


@lru_cache
def get_settings() -> Settings:
    return Settings()
